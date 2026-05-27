import SwiftUI
import Combine
import Foundation
import CoreLocation
import ActivityKit

// --- 0. IL MOTORE DEL BRIO (HAPTICS) ---
struct Haptics {
    static func play(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
}

// --- 1. MODELLI DATI E FORMATTERS ---
struct NewsItem: Codable, Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let isUrgent: Bool
    
    enum CodingKeys: String, CodingKey {
        case title, content, isUrgent
    }
}

struct SharedFormatters {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/Rome")
        return f
    }()
}

enum DayType: String, Codable {
    case feriali, sabato, festivo
    static var current: DayType {
        let day = Calendar.current.component(.weekday, from: Date())
        if day == 1 { return .festivo }
        if day == 7 { return .sabato }
        return .feriali
    }
}

struct MetroDeparture: Codable, Hashable {
    let min: Int
    let color: String
}

struct FormattedDeparture: Hashable {
    let timeString: String
    let destinationName: String?
}

enum MetroDisplayMode {
    case exact([FormattedDeparture])
    case frequency(String)
    case closed
}

struct FullSchedule: Codable {
    let feriali: [Int: [MetroDeparture]]
    let sabato: [Int: [MetroDeparture]]
    let festivo: [Int: [MetroDeparture]]
    let frequenze: [String: String]
    let lastSyncDate: Date?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicKey.self)
        func parseDict(key: String) -> [Int: [MetroDeparture]] {
            var result = [Int: [MetroDeparture]]()
            if let subContainer = try? container.nestedContainer(keyedBy: DynamicKey.self, forKey: DynamicKey(stringValue: key)!) {
                for k in subContainer.allKeys {
                    if let hour = Int(k.stringValue), let mins = try? subContainer.decode([MetroDeparture].self, forKey: k) {
                        result[hour] = mins
                    }
                }
            }
            return result
        }
        self.feriali = parseDict(key: "feriali")
        self.sabato = parseDict(key: "sabato")
        self.festivo = parseDict(key: "festivo")
        self.frequenze = (try? container.decode([String: String].self, forKey: DynamicKey(stringValue: "frequenze")!)) ?? [:]
        self.lastSyncDate = try? container.decode(Date.self, forKey: DynamicKey(stringValue: "lastSyncDate")!)
    }
    
    init(feriali: [Int: [MetroDeparture]], sabato: [Int: [MetroDeparture]], festivo: [Int: [MetroDeparture]], frequenze: [String: String], lastSyncDate: Date?) {
        self.feriali = feriali
        self.sabato = sabato
        self.festivo = festivo
        self.frequenze = frequenze
        self.lastSyncDate = lastSyncDate
    }
}

struct DynamicKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int?
    init?(intValue: Int) { return nil }
}

struct MetroLine: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let colorName: String
    var color: Color {
        switch colorName {
        case "red": return .red
        case "green": return .green
        case "purple": return .purple
        case "yellow": return .yellow
        case "blue": return .blue
        case "orange": return .orange
        default: return .gray
        }
    }
    let pdfID: String?
    var direction: Int = 0
    var customFrequencies: [DayType: String]? = nil
    var destinations: [String: String]? = nil
}

struct SavedTrain: Codable, Identifiable, Equatable {
    var id: String { number }
    let number: String
    let description: String
}

struct VTSearchStation: Codable, Identifiable {
    var id: String { vtID }
    let nomeLungo: String
    let nomeBreve: String
    let vtID: String
    
    enum CodingKeys: String, CodingKey {
        case nomeLungo
        case nomeBreve
        case vtID = "id"
    }
}

struct Train: Identifiable {
    let id = UUID()
    let category: String
    let number: String
    let destination: String
    let time: String
    let delay: String
    let platform: String
    
    var estimatedArrivalTime: String {
        guard let baseDate = SharedFormatters.time.date(from: time) else { return time }
        let delayMinutes = Int(delay.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "'", with: "")) ?? 0
        if let newDate = Calendar.current.date(byAdding: .minute, value: delayMinutes, to: baseDate) {
            return SharedFormatters.time.string(from: newDate)
        }
        return time
    }
}

struct TrainStatus {
    var lastStation: String = "--"
    var lastTime: String = "--"
    var statusMessage: String = "In attesa di dati..."
    var isDeparted: Bool = false
    var cancellationNote: String? = nil
}

struct Stop: Identifiable {
    let id = UUID()
    let stationName: String
    let time: String
    let actualTime: String?
    let delay: Int
    let estimatedTime: String?
}

struct Station: Identifiable, Codable, Hashable {
    var id = UUID()
    let name: String
    let rfiID: String?
    let vtID: String?
    let lat: Double?
    let lon: Double?
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = lat, let lon = lon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Station, rhs: Station) -> Bool { lhs.id == rhs.id }
    
    var metroLines: [MetroLine] {
        switch name {
        case "Rho Fiera":
            return [MetroLine(name: "M1 Sesto", colorName: "red", pdfID: "504", direction: 0, customFrequencies: [.feriali: "Ogni 4' - 9'", .sabato: "Ogni 7' - 9'"])]
        case "Porta Garibaldi", "P. Garibaldi Passante":
            return [
                MetroLine(name: "M2 Nord", colorName: "green", pdfID: "682", direction: 0, customFrequencies: [.feriali: "Gobba: 2'-4'   Gessate: 5'-12'   Cologno: 5'-12'", .sabato: "Gobba: 5'   Gessate: 10'-12'   Cologno: 10'"], destinations: ["orange": "Gessate", "blue": "Cologno N.", "black": "C. Gobba"]),
                MetroLine(name: "M2 Sud", colorName: "green", pdfID: "682", direction: 1, customFrequencies: [.feriali: "Famagosta: 2'-4'   Abbiategrasso: 5'-7'   Assago: 5'-12'", .sabato: "Famagosta: 4'-5'   Abbiategrasso: 9'-10'   Assago: 10'-11'"], destinations: ["orange": "Assago", "blue": "Abbiategrasso", "black": "Famagosta"]),
                MetroLine(name: "M5 Bignami", colorName: "purple", pdfID: "308", direction: 0),
                MetroLine(name: "M5 San Siro", colorName: "purple", pdfID: "308", direction: 1)
            ]
        case "Milano Centrale":
            return [
                MetroLine(name: "M2 Nord", colorName: "green", pdfID: "680", direction: 0, customFrequencies: [.feriali: "Gobba: 2'-4'   Gessate: 5'-12'   Cologno: 5'-12'", .sabato: "Gobba: 5'   Gessate: 10'-12'   Cologno: 10'"], destinations: ["orange": "Gessate", "blue": "Cologno N.", "black": "C. Gobba"]),
                MetroLine(name: "M2 Sud", colorName: "green", pdfID: "680", direction: 1, customFrequencies: [.feriali: "Famagosta: 2'-4'   Abbiategrasso: 5'-7'   Assago: 5'-12'", .sabato: "Famagosta: 4'-5'   Abbiategrasso: 9'-10'   Assago: 10'-11'"], destinations: ["orange": "Assago", "blue": "Abbiategrasso", "black": "Famagosta"]),
                MetroLine(name: "M3 S. Donato", colorName: "yellow", pdfID: "731", direction: 0),
                MetroLine(name: "M3 Comasina", colorName: "yellow", pdfID: "731", direction: 1)
            ]
        case "Repubblica":
            return [
                MetroLine(name: "M3 S. Donato", colorName: "yellow", pdfID: "732", direction: 0),
                MetroLine(name: "M3 Comasina", colorName: "yellow", pdfID: "732", direction: 1)
            ]
        case "Porta Venezia":
            return [
                MetroLine(name: "M1 Rho/Bisc.", colorName: "red", pdfID: "536", direction: 1, customFrequencies: [.feriali: "Pagano: 2'-4'   Rho: 4'-11'   Bisceglie: 4'-8'", .sabato: "Pagano: 3'-5'   Rho: 7'-9'   Bisceglie: 7'-11'"], destinations: ["orange": "Rho Fiera", "blue": "Bisceglie", "black": "Pagano"]),
                MetroLine(name: "M1 Sesto", colorName: "red", pdfID: "536", direction: 0, customFrequencies: [.feriali: "Ogni 2' - 3'", .sabato: "Ogni 3' - 4'", .festivo: "Ogni 5' - 8'"])
            ]
        case "Dateo":
            return [
                MetroLine(name: "M4 S. Cristoforo", colorName: "blue", pdfID: "336", direction: 0),
                MetroLine(name: "M4 Linate", colorName: "blue", pdfID: "336", direction: 1)
            ]
        case "Forlanini":
            return [
                MetroLine(name: "M4 S. Cristoforo", colorName: "blue", pdfID: "339", direction: 0),
                MetroLine(name: "M4 Linate", colorName: "blue", pdfID: "339", direction: 1)
            ]
        default:
            return []
        }
    }
}

enum AppSection: String, Codable, CaseIterable {
    case nearby = "Stazione Vicina"
    case favoriteTrains = "Treni Preferiti"
    case myStations = "Le Mie Stazioni"
    case passante = "Passante Ferroviario"
}

// --- 2. GESTORI DATI E POSIZIONE ---
@MainActor class MetroCache: ObservableObject {
    @Published var allSchedules: [String: FullSchedule] = [:]
    @Published var isOfflineMode: [String: Bool] = [:]
    
    private let storageKey = "com.magenta.metro.cache"
    private let baseURL = "https://inorario.toreroclub.com"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: FullSchedule].self, from: data) {
            self.allSchedules = decoded
        }
    }
    
    func sync(line: String, pdfID: String, direction: Int) async {
        let cacheKey = "\(pdfID)_\(direction)"
        if isOfflineMode[cacheKey] == true { return }
        
        var components = URLComponents(string: "\(baseURL)/metro/pdf/\(line)/\(pdfID)")!
        components.queryItems = [URLQueryItem(name: "direction", value: String(direction))]
        guard let url = components.url else { return }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 3.5))
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                self.isOfflineMode[cacheKey] = true
                return
            }
            let baseDecoded = try JSONDecoder().decode(FullSchedule.self, from: data)
            let updatedSync = FullSchedule(feriali: baseDecoded.feriali, sabato: baseDecoded.sabato, festivo: baseDecoded.festivo, frequenze: baseDecoded.frequenze, lastSyncDate: Date())
            self.allSchedules[cacheKey] = updatedSync
            self.isOfflineMode[cacheKey] = false
            self.saveCache()
        } catch {
            self.isOfflineMode[cacheKey] = true
        }
    }
    
    private func saveCache() {
        if let encoded = try? JSONEncoder().encode(allSchedules) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    func getNextDepartures(metro: MetroLine, now: Date) -> MetroDisplayMode {
        let hour = Calendar.current.component(.hour, from: now)
        if hour >= 2 && hour <= 4 { return .closed }
        let cacheKey = "\(metro.pdfID ?? "")_\(metro.direction)"
        guard let schedule = allSchedules[cacheKey] else { return .frequency("Sincronizza per i dati...") }
        
        let todayData: [Int: [MetroDeparture]]
        let currentFreq = schedule.frequenze[DayType.current.rawValue] ?? ""
        switch DayType.current {
        case .feriali: todayData = schedule.feriali
        case .sabato: todayData = schedule.sabato
        case .festivo: todayData = schedule.festivo
        }
        
        let min = Calendar.current.component(.minute, from: now)
        let found = (todayData[hour] ?? []).filter { $0.min > min }
        
        if found.isEmpty {
            if let custom = metro.customFrequencies, let manualText = custom[DayType.current] { return .frequency(manualText) }
            if !currentFreq.isEmpty { return .frequency(currentFreq) }
            return .frequency("Servizio frequente")
        }
        let deps = found.prefix(3).map { dep in
            let timeStr = String(format: "%02d:%02d", hour, dep.min)
            var destName: String? = nil
            if let destMap = metro.destinations, let mapped = destMap[dep.color] { destName = mapped }
            return FormattedDeparture(timeString: timeStr, destinationName: destName)
        }
        return .exact(deps)
    }
}

@MainActor class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.userLocation = locations.last }
    }
}

// --- 3. MOTORE DI RICERCA IBRIDO ---
@MainActor class TrainManager: ObservableObject {
    @Published var trains: [Train] = []
    @Published var selectedTrainStops: [Stop] = []
    @Published var currentTrainStatus: TrainStatus = TrainStatus()
    @Published var favoriteTrains: [SavedTrain] = []
    @Published var myStations: [Station] = []
    @Published var searchResults: [SavedTrain] = []
    @Published var searchStationResults: [VTSearchStation] = []
    @Published var sectionOrder: [AppSection] = AppSection.allCases
    @Published var isSearching: Bool = false
    @Published var isLoading = false
    @Published var isStopsLoading = false
    @Published var stopErrorMessage: String? = nil
    @Published var deepLinkTrain: Train? = nil
    
    @Published var stationAlerts: String? = nil
    
    private var refreshTimer: AnyCancellable?
    
    private let favoritesKey = "savedFavoriteTrains_v3"
    private let myStationsKey = "savedMyStations_v3"
    private let sectionOrderKey = "savedSectionOrder_v3"
    
    let rfiStationMap: [String: String] = [
        "novara": "1917",
        "trecate": "2909",
        "corbetta-s.stefano ticino": "1174",
        "corbetta": "1174",
        "vittuone arluno": "3119",
        "vittuone": "3119",
        "pregnana milanese": "381",
        "pregnana": "381",
        "rho": "2345",
        "magenta": "1618",
        "rho fiera": "3098",
        "milano porta garibaldi": "1715",
        "milano centrale": "1728"
    ]
    
    var lineHealth: (message: String, color: Color) {
        let trainsWithDelay = trains.filter { !$0.delay.contains("In orario") }
        let totalTrains = trains.count
        
        if totalTrains == 0 { return ("Dati non disponibili", .gray) }
        
        let delayRatio = Double(trainsWithDelay.count) / Double(totalTrains)
        
        if delayRatio < 0.2 {
            return ("Circolazione Regolare", .green)
        } else if delayRatio < 0.5 {
            return ("Circolazione Rallentata", .orange)
        } else {
            return ("Criticità sulla linea", .red)
        }
    }
    
    init() { loadFavorites() }
    
    func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey), let decoded = try? JSONDecoder().decode([SavedTrain].self, from: data) { self.favoriteTrains = decoded }
        
        if let data = UserDefaults.standard.data(forKey: myStationsKey), let decoded = try? JSONDecoder().decode([Station].self, from: data) {
            self.myStations = decoded
        } else {
            self.myStations = [
                Station(name: "Magenta", rfiID: "1618", vtID: "S01021", lat: 45.4641, lon: 8.8845),
                Station(name: "Rho Fiera", rfiID: "3098", vtID: "S01026", lat: 45.5215, lon: 9.0883),
                Station(name: "Porta Garibaldi", rfiID: "1715", vtID: "S01058", lat: 45.4844, lon: 9.1887),
                Station(name: "Milano Centrale", rfiID: "1728", vtID: "S01700", lat: 45.4849, lon: 9.2033)
            ]
            saveFavorites()
        }
        
        if let data = UserDefaults.standard.data(forKey: sectionOrderKey), let decoded = try? JSONDecoder().decode([AppSection].self, from: data) {
            var loaded = decoded
            for section in AppSection.allCases {
                if !loaded.contains(section) { loaded.append(section) }
            }
            self.sectionOrder = loaded
        }
    }
    
    func saveFavorites() {
        if let encoded = try? JSONEncoder().encode(favoriteTrains) { UserDefaults.standard.set(encoded, forKey: favoritesKey) }
        if let encoded = try? JSONEncoder().encode(myStations) { UserDefaults.standard.set(encoded, forKey: myStationsKey) }
    }
    
    func saveSectionOrder() {
        if let encoded = try? JSONEncoder().encode(sectionOrder) { UserDefaults.standard.set(encoded, forKey: sectionOrderKey) }
    }
    
    func toggleFavorite(trainNumber: String, description: String) {
        if let index = favoriteTrains.firstIndex(where: { $0.number == trainNumber }) {
            favoriteTrains.remove(at: index)
            Haptics.notify(.warning)
        } else {
            let cleanDescription = description.replacingOccurrences(of: "\(trainNumber) - ", with: "")
            favoriteTrains.append(SavedTrain(number: trainNumber, description: cleanDescription))
            Haptics.notify(.success)
        }
        saveFavorites()
    }
    
    func isFavorite(trainNumber: String) -> Bool { favoriteTrains.contains { $0.number == trainNumber } }
    
    func addMyStation(name: String, vtID: String) {
        if !myStations.contains(where: { $0.vtID == vtID }) {
            let possibleRfiID = rfiStationMap[name.lowercased()]
            let newStation = Station(name: name.capitalized, rfiID: possibleRfiID, vtID: vtID, lat: nil, lon: nil)
            myStations.append(newStation)
            saveFavorites()
            Haptics.notify(.success)
        }
    }
    
    func removeMyStation(vtID: String) {
        myStations.removeAll { $0.vtID == vtID }
        saveFavorites()
        Haptics.notify(.warning)
    }
    
    func isMyStation(vtID: String) -> Bool {
        return myStations.contains { $0.vtID == vtID }
    }
    
    func searchTrains(query: String) async {
        guard query.count >= 2 else { self.searchResults = []; return }
        self.isSearching = true
        let urlString = "https://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/cercaNumeroTrenoTrenoAutocomplete/\(query)"
        guard let url = URL(string: urlString) else { self.isSearching = false; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = String(data: data, encoding: .utf8) ?? ""
            let lines = result.components(separatedBy: .newlines).filter { !$0.isEmpty }
            self.searchResults = lines.compactMap { line in
                let parts = line.components(separatedBy: "|")
                guard parts.count > 0 else { return nil }
                let desc = parts[0].components(separatedBy: " - ")
                return SavedTrain(number: desc[0].trimmingCharacters(in: .whitespaces), description: desc.count > 1 ? desc[1].trimmingCharacters(in: .whitespaces) : desc[0])
            }
            self.isSearching = false
        } catch { self.isSearching = false }
    }
    
    func searchStations(query: String) async {
        guard query.count >= 2 else { self.searchStationResults = []; return }
        self.isSearching = true
        let safeQuery = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        let urlString = "https://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/cercaStazione/\(safeQuery)"
        guard let url = URL(string: urlString) else { self.isSearching = false; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            self.searchStationResults = (try? JSONDecoder().decode([VTSearchStation].self, from: data)) ?? []
            self.isSearching = false
        } catch { self.isSearching = false }
    }
    
    func fetchVTTrains(for vtID: String, isDepartures: Bool) async {
        self.isLoading = true
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Rome")
        f.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'ZZZ"
        let dateStr = f.string(from: Date()).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        let endpoint = isDepartures ? "partenze" : "arrivi"
        let urlString = "https://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/\(endpoint)/\(vtID)/\(dateStr)"
        guard let url = URL(string: urlString) else { self.isLoading = false; return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                self.trains = jsonArray.compactMap { item in
                    let num = String(item["numeroTreno"] as? Int ?? 0)
                    var cat = (item["categoriaDescrizione"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
                    let dest = ((isDepartures ? item["destinazione"] : item["origine"]) as? String)?.capitalized ?? ""
                    let timeVal = (isDepartures ? item["orarioPartenza"] : item["orarioArrivo"]) as? Int ?? 0
                    let ritardo = item["ritardo"] as? Int ?? 0
                    
                    let binEff = (isDepartures ? item["binarioEffettivoPartenzaDescrizione"] : item["binarioEffettivoArrivoDescrizione"]) as? String
                    let binProg = (isDepartures ? item["binarioProgrammatoPartenzaDescrizione"] : item["binarioProgrammatoArrivoDescrizione"]) as? String
                    let platform = binEff ?? binProg ?? "--"
                    
                    let catUpper = cat.uppercased()
                    if catUpper.contains("ALTA VELOCIT") { cat = "AV" }
                    else if catUpper.contains("INTERCITY") { cat = "IC" }
                    else if catUpper.contains("EUROCITY") { cat = "EC" }
                    else if catUpper == "REGIONALE VELOCE" { cat = "RV" }
                    else if catUpper == "REGIONALE" { cat = "REG" }
                    
                    if timeVal > 0 {
                        let date = Date(timeIntervalSince1970: TimeInterval(timeVal/1000))
                        return Train(category: cat, number: num, destination: dest, time: SharedFormatters.time.string(from: date), delay: ritardo > 0 ? "+\(ritardo)'" : "In orario", platform: platform)
                    }
                    return nil
                }
            }
            self.isLoading = false
        } catch { self.isLoading = false }
    }
    
    private func stripHTML(_ str: String) -> String {
        var text = "<td" + str
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression, range: nil)
        text = text.replacingOccurrences(of: "<td", with: " ", options: .caseInsensitive)
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&#39", with: "'")
        text = text.replacingOccurrences(of: "&apos;", with: "'")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func fetchTrains(for rfiID: String, isDepartures: Bool) async {
        self.isLoading = true
        self.stationAlerts = nil
        
        let urlString = "https://iechub.rfi.it/ArriviPartenze/ArrivalsDepartures/Monitor?placeId=\(rfiID)&arrivals=\(!(isDepartures))"
        guard let url = URL(string: urlString) else { self.isLoading = false; return }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { self.isLoading = false; return }
            
            if let range = html.range(of: "Avvisi") {
                let subHtml = String(html[range.lowerBound...])
                if let endRange = subHtml.range(of: "</div>") {
                    let alertRaw = String(subHtml[..<endRange.lowerBound])
                    var cleanAlert = self.stripHTML(alertRaw)
                        .replacingOccurrences(of: "Avvisi", with: "")
                        .replacingOccurrences(of: "<", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if cleanAlert.uppercased().contains("VIETATO APRIRE LE PORTE") {
                        cleanAlert = ""
                    }
                    
                    if !cleanAlert.isEmpty {
                        self.stationAlerts = cleanAlert
                    }
                }
            }
            
            var cleanHtml = html.replacingOccurrences(of: "<TR", with: "<tr", options: .caseInsensitive)
            cleanHtml = cleanHtml.replacingOccurrences(of: "<TD", with: "<td", options: .caseInsensitive)
            let rows = cleanHtml.components(separatedBy: "<tr")
            var scrapedTrains: [Train] = []
            for row in rows.dropFirst() {
                let cols = row.components(separatedBy: "<td")
                if cols.count >= 8 {
                    var cat = self.stripHTML(cols[2]).replacingOccurrences(of: "Categoria", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
                    if cat.isEmpty {
                        if let altRange = cols[2].range(of: "alt=\"([^\"]+)\"", options: .regularExpression) {
                            let match = String(cols[2][altRange])
                            let rawAlt = match.replacingOccurrences(of: "alt=\"", with: "")
                                              .replacingOccurrences(of: "\"", with: "")
                                              .replacingOccurrences(of: "Categoria", with: "", options: .caseInsensitive)
                            cat = self.stripHTML(rawAlt)
                        }
                    }
                    let num = self.stripHTML(cols[3])
                    let dest = self.stripHTML(cols[4])
                    let time = self.stripHTML(cols[5])
                    let delayRaw = self.stripHTML(cols[6])
                    let plat = self.stripHTML(cols[7])
                    
                    let catUpper = cat.uppercased()
                    if catUpper.contains("ALTA VELOCIT") { cat = "AV" }
                    else if catUpper.contains("INTERCITY") { cat = "IC" }
                    else if catUpper.contains("EUROCITY") { cat = "EC" }
                    else if catUpper == "REGIONALE VELOCE" { cat = "RV" }
                    else if catUpper == "REGIONALE" { cat = "REG" }
                    
                    if cat.isEmpty {
                        if num.hasPrefix("20") || num.hasPrefix("21") { cat = "RV" }
                        else if num.hasPrefix("24") || num.hasPrefix("10") { cat = "S" }
                        else { cat = "REG" }
                    }
                    if !num.isEmpty && time.contains(":") {
                        scrapedTrains.append(Train(category: cat, number: num, destination: dest.capitalized, time: time, delay: delayRaw.isEmpty ? "In orario" : "+\(delayRaw)'", platform: plat.isEmpty ? "--" : plat))
                    }
                }
            }
            self.trains = scrapedTrains
            self.isLoading = false
        } catch { self.isLoading = false }
    }
    
    func fetchStops(for train: Train, isRefresh: Bool = false) async {
        if !isRefresh {
            self.selectedTrainStops = []
            self.currentTrainStatus = TrainStatus()
            self.isStopsLoading = true
            self.stopErrorMessage = nil
        }
        
        let cleanNumber = train.number.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchUrl = "https://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/cercaNumeroTrenoTrenoAutocomplete/\(cleanNumber)"
        
        guard let sUrl = URL(string: searchUrl) else {
            if !isRefresh { self.isStopsLoading = false }
            return
        }
        
        do {
            let (sData, _) = try await URLSession.shared.data(from: sUrl)
            let result = String(data: sData, encoding: .utf8) ?? ""
            
            if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !isRefresh { self.stopErrorMessage = "Treno non tracciato o non ancora nel sistema."; self.isStopsLoading = false }
                return
            }
            
            let lines = result.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let targetLine = lines.first(where: { $0.contains("|\(cleanNumber)-") }) ?? lines.first else {
                if !isRefresh { self.stopErrorMessage = "Dettagli del treno non trovati."; self.isStopsLoading = false }
                return
            }
            
            let pipes = targetLine.components(separatedBy: "|")
            guard pipes.count >= 2 else {
                if !isRefresh { self.stopErrorMessage = "Dati API ViaggiaTreno incompleti."; self.isStopsLoading = false }
                return
            }
            
            let subParts = pipes[1].components(separatedBy: "-")
            guard subParts.count >= 2 else {
                if !isRefresh { self.stopErrorMessage = "ID Stazione di origine non trovato."; self.isStopsLoading = false }
                return
            }
            
            let originID = subParts[1]
            let timestamp = subParts.count >= 3 ? subParts[2] : ""
            
            var stopsUrl = "https://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/andamentoTreno/\(originID)/\(cleanNumber)"
            if !timestamp.isEmpty { stopsUrl += "/\(timestamp)" }
            
            guard let stUrl = URL(string: stopsUrl) else {
                if !isRefresh { self.isStopsLoading = false }
                return
            }
            
            let request = URLRequest(url: stUrl)
            let (stData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, !stData.isEmpty else {
                if !isRefresh { self.stopErrorMessage = "Dati in aggiornamento o temporaneamente non disponibili."; self.isStopsLoading = false }
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: stData) as? [String: Any] else {
                if !isRefresh { self.stopErrorMessage = "Il server ha restituito dati illeggibili."; self.isStopsLoading = false }
                return
            }
            
            var status = TrainStatus()
            status.isDeparted = !(json["nonPartito"] as? Bool ?? true)
            status.lastStation = (json["stazioneUltimoRilevamento"] as? String) ?? "--"
            status.lastTime = (json["compOraUltimoRilevamento"] as? String) ?? (json["oraUltimoRilevamento"] as? String) ?? "--:--"
            
            if let ritardi = json["compRitardo"] as? [String], !ritardi.isEmpty { status.statusMessage = ritardi[0] }
            else { status.statusMessage = status.isDeparted ? "In viaggio" : "In attesa di partenza" }
            if let provv = json["provvedimento"] as? Int, provv != 0 { status.cancellationNote = "TRENO CANCELLATO O DEVIATO"; status.statusMessage = "Soppresso" }
            
            let globalDelay = (json["ritardo"] as? Int) ?? 0
            
            if let fermate = json["fermate"] as? [[String: Any]] {
                let mappedStops = fermate.map { f -> Stop in
                    let name = (f["stazione"] as? String) ?? "Sconosciuta"
                    let tProg = (f["programmata"] as? Int) ?? 0
                    let tEff = (f["effettiva"] as? Int) ?? 0
                    
                    let stopSpecificDelay = (f["ritardo"] as? Int) ?? 0
                    let effectiveDelay = stopSpecificDelay > 0 ? stopSpecificDelay : globalDelay
                    
                    let d = Date(timeIntervalSince1970: TimeInterval(tProg/1000))
                    let actT = tEff > 0 ? SharedFormatters.time.string(from: Date(timeIntervalSince1970: TimeInterval(tEff/1000))) : nil
                    
                    var estT: String? = nil
                    if actT == nil && effectiveDelay >= 4 {
                        if let futureDate = Calendar.current.date(byAdding: .minute, value: effectiveDelay, to: d) {
                            estT = SharedFormatters.time.string(from: futureDate)
                        }
                    }
                    
                    return Stop(stationName: name.capitalized,
                                time: SharedFormatters.time.string(from: d),
                                actualTime: actT,
                                delay: effectiveDelay,
                                estimatedTime: estT)
                }
                self.selectedTrainStops = mappedStops
                self.currentTrainStatus = status
                self.isStopsLoading = false
                self.stopErrorMessage = nil
                
                let delayStr = globalDelay > 0 ? "+\(globalDelay)'" : "In orario"
                let updatedState = TrainLiveActivityAttributes.ContentState(
                    delay: delayStr,
                    statusMessage: status.statusMessage,
                    lastStation: status.lastStation
                )
                
                Task {
                    for activity in Activity<TrainLiveActivityAttributes>.activities {
                        if activity.attributes.trainNumber == cleanNumber {
                            await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                        }
                    }
                }
                
            }
        } catch is CancellationError {
            if !isRefresh { self.isStopsLoading = false }
        } catch {
            if !isRefresh { self.stopErrorMessage = "Errore di rete o blocco di sicurezza (controlla i permessi ATS nel file Info.plist)."; self.isStopsLoading = false }
        }
    }
    
    func startAutoRefresh(for rfiID: String, isDepartures: Bool) {
        refreshTimer?.cancel()
        refreshTimer = Timer.publish(every: 45, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            Task { await self?.fetchTrains(for: rfiID, isDepartures: isDepartures) }
        }
    }
    
    func stopAutoRefresh() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }
    
    func createDummyTrain(from saved: SavedTrain) -> Train {
        var cat = "REG"
        if saved.number.hasPrefix("20") || saved.number.hasPrefix("21") { cat = "RV" }
        else if saved.number.hasPrefix("24") || saved.number.hasPrefix("10") { cat = "S" }
        else if saved.number.hasPrefix("9") { cat = "FR" }
        return Train(category: cat, number: saved.number, destination: saved.description.capitalized, time: "--:--", delay: "In orario", platform: "--")
    }
}

// --- 4. INTERFACCIA ---
struct NewsBannerView: View {
    let news: [NewsItem]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(news) { item in
                HStack {
                    Image(systemName: item.isUrgent ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .foregroundColor(item.isUrgent ? .white : .orange)
                        .font(.title3)
                    
                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.content)
                            .font(.subheadline)
                    }
                    .foregroundColor(item.isUrgent ? .white : .primary)
                    Spacer()
                }
                .padding()
                .background(item.isUrgent ? Color.red : Color.orange.opacity(0.2))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            }
        }
        .padding(.bottom, 8)
    }
}

struct ContentView: View {
    @StateObject var locationManager = LocationManager()
    @StateObject var manager = TrainManager()
    @StateObject var metroCache = MetroCache()
    
    @State private var newsItems: [NewsItem] = []
    @State private var allNewsItems: [NewsItem] = []
    
    @State private var isPassanteExpanded = false
    @State private var isFavoritesExpanded = false
    @State private var isMyStationsExpanded = false
    @State private var showSearchSheet = false
    @State private var showReorderSheet = false
    @State private var showNewsCenter = false
    
    @State private var deepLinkTrain: Train? = nil
    
    var dynamicTitle: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Buongiorno! ☀️" }
        if hour < 18 { return "Buon pomeriggio ☕️" }
        return "Buonasera! 🌙"
    }
    
    let passanteStations = [
        Station(name: "Certosa", rfiID: "1708", vtID: nil, lat: 45.5085, lon: 9.1272),
        Station(name: "Villapizzone", rfiID: "3099", vtID: nil, lat: 45.4998, lon: 9.1465),
        Station(name: "Lancetti", rfiID: "1713", vtID: nil, lat: 45.4925, lon: 9.1751),
        Station(name: "P. Garibaldi Passante", rfiID: "1714", vtID: nil, lat: 45.4844, lon: 9.1887),
        Station(name: "Repubblica", rfiID: "1719", vtID: nil, lat: 45.4795, lon: 9.1963),
        Station(name: "Porta Venezia", rfiID: "1723", vtID: nil, lat: 45.4746, lon: 9.2052),
        Station(name: "Dateo", rfiID: "3468", vtID: nil, lat: 45.4682, lon: 9.2158),
        Station(name: "Porta Vittoria", rfiID: "1718", vtID: nil, lat: 45.4613, lon: 9.2227),
        Station(name: "Forlanini", rfiID: "3169", vtID: nil, lat: 45.4625, lon: 9.2368)
    ]
    
    var nearbyStation: Station? {
        guard let userLoc = locationManager.userLocation else { return nil }
        let allCandidates = manager.myStations + passanteStations
        return allCandidates.first { s in
            guard let c = s.coordinate else { return false }
            return userLoc.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude)) < 1500
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                if !newsItems.isEmpty {
                    NewsBannerView(news: newsItems)
                        .padding(.top, 8)
                        .padding(.horizontal)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                
                List {
                    ForEach(manager.sectionOrder, id: \.self) { section in
                        switch section {
                        case .nearby:
                            if let nearby = nearbyStation {
                                Section(header: Text("📍 Stazione Vicina").font(.subheadline.bold())) {
                                    NavigationLink(destination: SmartBoardView(station: nearby, manager: manager)) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Sei qui").font(.caption2).fontWeight(.heavy).foregroundColor(.orange).textCase(.uppercase)
                                                Text(nearby.name).font(.title3).bold().foregroundColor(.primary)
                                            }
                                            Spacer()
                                            Image(systemName: "location.circle.fill").font(.title).foregroundColor(.orange)
                                        }
                                        .padding(.vertical, 8)
                                        .contentShape(Rectangle())
                                    }
                                }
                            }
                            
                        case .favoriteTrains:
                            if !manager.favoriteTrains.isEmpty {
                                DisclosureGroup(isExpanded: $isFavoritesExpanded) {
                                    ForEach(manager.favoriteTrains) { fav in
                                        let dummy = manager.createDummyTrain(from: fav)
                                        NavigationLink(destination: TrainStopsView(train: dummy, manager: manager)) {
                                            HStack {
                                                Image(systemName: "train.side.front.car").foregroundColor(.blue)
                                                VStack(alignment: .leading) {
                                                    Text("Treno \(fav.number)").font(.headline)
                                                    Text(fav.description).font(.caption).foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                            .contentShape(Rectangle())
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                manager.toggleFavorite(trainNumber: fav.number, description: fav.description)
                                            } label: {
                                                Label("Rimuovi", systemImage: "trash.fill")
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Treni Preferiti", systemImage: "star.fill").font(.headline).foregroundColor(.yellow).padding(.vertical, 4)
                                }
                                .onChange(of: isFavoritesExpanded) { oldValue, newValue in
                                    Haptics.play(.light)
                                }
                            }
                            
                        case .myStations:
                            if !manager.myStations.isEmpty {
                                DisclosureGroup(isExpanded: $isMyStationsExpanded) {
                                    ForEach(manager.myStations) { s in
                                        NavigationLink(destination: SmartBoardView(station: s, manager: manager)) {
                                            Label(s.name, systemImage: "building.2.crop.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.headline)
                                                .padding(.vertical, 4)
                                                .contentShape(Rectangle())
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                if let vtID = s.vtID {
                                                    manager.removeMyStation(vtID: vtID)
                                                }
                                            } label: {
                                                Label("Rimuovi", systemImage: "trash.fill")
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Le Mie Stazioni", systemImage: "building.2.crop.circle.fill")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 4)
                                }
                                .onChange(of: isMyStationsExpanded) { oldValue, newValue in
                                    Haptics.play(.light)
                                }
                            }
                            
                        case .passante:
                            DisclosureGroup(isExpanded: $isPassanteExpanded) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 0) {
                                        ForEach(Array(passanteStations.enumerated()), id: \.element.id) { index, station in
                                            let isNearby = nearbyStation?.rfiID == station.rfiID
                                            NavigationLink(destination: SmartBoardView(station: station, manager: manager)) {
                                                PassanteNodeView(station: station, isFirst: index == 0, isLast: index == passanteStations.count - 1, isNearby: isNearby)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 25)
                                    .padding(.horizontal, 15)
                                }
                                .listRowInsets(EdgeInsets())
                            } label: {
                                Label("Passante Ferroviario", systemImage: "tram.fill")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                    .padding(.vertical, 4)
                            }
                            .onChange(of: isPassanteExpanded) { oldValue, newValue in
                                Haptics.play(.light)
                            }
                        }
                    }
                    
                    Section {
                        Button {
                            Haptics.play(.medium)
                            showReorderSheet = true
                        } label: {
                            HStack { Spacer(); Label("Personalizza Dashboard", systemImage: "slider.horizontal.3").foregroundColor(.blue).font(.subheadline.bold()); Spacer() }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                .refreshable {
                    Haptics.play(.medium)
                    await loadNews()
                    manager.loadFavorites()
                }
            }
            .navigationTitle(dynamicTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 20) {
                        Button {
                            Haptics.play(.medium)
                            showNewsCenter = true
                        } label: {
                            Image(systemName: "newspaper.fill")
                                .overlay(
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 10, y: -10)
                                        .opacity(newsItems.isEmpty ? 0 : 1)
                                )
                        }
                        
                        Button {
                            Haptics.play(.medium)
                            showSearchSheet = true
                        } label: { Image(systemName: "magnifyingglass").fontWeight(.bold) }
                    }
                }
            }
            .sheet(isPresented: $showSearchSheet, onDismiss: { manager.loadFavorites() }) { SearchView() }
            .sheet(isPresented: $showReorderSheet) { ReorderSectionsView(manager: manager) }
            .sheet(isPresented: $showNewsCenter) { NewsCenterView(news: allNewsItems, refreshAction: { await loadNews() }) }
            .onAppear {
                manager.loadFavorites()
                withAnimation(.spring()) { }
            }
            .task { await loadNews() }
            
        }
        .environmentObject(metroCache)
        
        .sheet(item: $deepLinkTrain) { t in
            TrainStopsView(train: t, manager: manager)
        }
        .onOpenURL { url in
            guard url.scheme == "inorario" else { return }
            
            let number = url.path.replacingOccurrences(of: "/", with: "")
            let finalNumber = number.isEmpty ? (url.host ?? "") : number
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let dummy = Train(category: "Treno", number: finalNumber, destination: "Caricamento...", time: "--:--", delay: "In orario", platform: "--")
                self.deepLinkTrain = dummy
            }
        }
        
    }
    
    func loadNews() async {
        guard let url = URL(string: "https://inorario.toreroclub.com/news") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedNews = try JSONDecoder().decode([NewsItem].self, from: data)
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    self.allNewsItems = decodedNews
                    self.newsItems = decodedNews.filter { $0.title != "Info" || $0.isUrgent }
                }
            }
        } catch {
            print("Errore fetch news: \(error)")
        }
    }
}

// VISTA CENTRO NEWS
struct NewsCenterView: View {
    let news: [NewsItem]
    let refreshAction: () async -> Void
    @Environment(\.dismiss) var dismiss
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            List {
                if news.isEmpty {
                    VStack(spacing: 15) {
                        Spacer()
                        Image(systemName: "tray.full").font(.system(size: 50)).foregroundColor(.secondary)
                        Text("Nessuna notizia disponibile").font(.headline).foregroundColor(.secondary)
                        Spacer()
                    }.frame(maxWidth: .infinity).listRowBackground(Color.clear)
                } else {
                    ForEach(news) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(item.title).font(.headline)
                                Spacer()
                                if item.isUrgent {
                                    Text("URGENTE").font(.system(size: 10, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(.red).foregroundColor(.white).cornerRadius(4)
                                }
                            }
                            Text(item.content).font(.subheadline).foregroundColor(.secondary)
                        }.padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Centro News")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Chiudi") { dismiss() }.fontWeight(.bold) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.play(.medium)
                        isRefreshing = true
                        Task { await refreshAction(); isRefreshing = false }
                    } label: {
                        if isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                }
            }
        }
    }
}

// IL RILEVATORE DI MOTORE
struct SmartBoardView: View {
    let station: Station
    @ObservedObject var manager: TrainManager
    
    var body: some View {
        if let rfi = station.rfiID, !rfi.isEmpty {
            StationBoardView(station: station)
        } else if let vt = station.vtID, !vt.isEmpty {
            VTStationBoardView(stationName: station.name, vtID: vt)
        } else {
            Text("Errore: Nessun ID stazione valido.")
        }
    }
}

// VISTA DI RICERCA
struct SearchView: View {
    @StateObject var manager = TrainManager()
    @State private var query = ""
    @State private var searchType = 0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Tipo Ricerca", selection: $searchType) {
                    Text("Treni").tag(0)
                    Text("Stazioni").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: searchType) { oldValue, newValue in Haptics.play(.light) }
                
                List {
                    if manager.isSearching {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if searchType == 0 {
                        if manager.searchResults.isEmpty && !query.isEmpty {
                            Text("Nessun treno trovato.").foregroundColor(.secondary)
                        } else {
                            ForEach(manager.searchResults) { result in
                                let dummy = manager.createDummyTrain(from: result)
                                NavigationLink(destination: TrainStopsView(train: dummy, manager: manager)) {
                                    HStack {
                                        Image(systemName: "train.side.front.car").foregroundColor(.blue)
                                        VStack(alignment: .leading) {
                                            Text("Treno \(result.number)").font(.headline)
                                            Text(result.description).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        if manager.searchStationResults.isEmpty && !query.isEmpty {
                            Text("Nessuna stazione trovata.").foregroundColor(.secondary)
                        } else {
                            ForEach(manager.searchStationResults) { result in
                                HStack {
                                    Image(systemName: "building.2.crop.circle.fill").foregroundColor(.orange)
                                    
                                    let possibleRFI = manager.rfiStationMap[result.nomeLungo.lowercased()]
                                    let tempStation = Station(name: result.nomeLungo, rfiID: possibleRFI, vtID: result.vtID, lat: nil, lon: nil)
                                    
                                    NavigationLink(destination: SmartBoardView(station: tempStation, manager: manager)) {
                                        Text(result.nomeLungo).font(.headline)
                                    }
                                    Spacer()
                                    
                                    Button {
                                        if manager.isMyStation(vtID: result.vtID) {
                                            manager.removeMyStation(vtID: result.vtID)
                                        } else {
                                            manager.addMyStation(name: result.nomeLungo, vtID: result.vtID)
                                        }
                                    } label: {
                                        Image(systemName: manager.isMyStation(vtID: result.vtID) ? "checkmark.circle.fill" : "plus.circle")
                                            .foregroundColor(.blue)
                                            .font(.title2)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle(searchType == 0 ? "Cerca Treno" : "Cerca Stazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Chiudi") { dismiss() }.fontWeight(.bold)
                }
            }
            .searchable(text: $query, prompt: searchType == 0 ? "Es. 2010" : "Es. Bologna Centrale")
            .onChange(of: query) { oldValue, newValue in
                Task {
                    if searchType == 0 { await manager.searchTrains(query: newValue) }
                    else { await manager.searchStations(query: newValue) }
                }
            }
        }
    }
}

// VISTA RIORDINA SEZIONI
struct ReorderSectionsView: View {
    @ObservedObject var manager: TrainManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.sectionOrder, id: \.self) { section in
                    Text(section.rawValue).font(.headline)
                }
                .onMove { from, to in
                    Haptics.play(.medium)
                    manager.sectionOrder.move(fromOffsets: from, toOffset: to)
                    manager.saveSectionOrder()
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Ordina Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fine") { dismiss() }.fontWeight(.bold)
                }
            }
        }
    }
}

// VISTA NODO PASSANTE
struct PassanteNodeView: View {
    let station: Station
    let isFirst: Bool
    let isLast: Bool
    let isNearby: Bool
    
    @State private var animationScale: CGFloat = 1.0
    @State private var animationOpacity: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            Text(station.name.replacingOccurrences(of: "Milano ", with: "").replacingOccurrences(of: " Passante", with: ""))
                .font(.system(size: 13, weight: isNearby ? .bold : .medium))
                .foregroundColor(isNearby ? .orange : .primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(width: 65, height: 70, alignment: .bottomLeading)
                .rotationEffect(.degrees(-45), anchor: .bottomLeading)
                .offset(x: 20, y: -5)
            
            HStack(spacing: 2) {
                ForEach(Array(Set(station.metroLines.map { $0.color })), id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                }
            }.frame(height: 10).padding(.bottom, 2)
            
            ZStack {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(isFirst ? Color.clear : Color.orange.opacity(0.6))
                        .frame(height: 5)
                    Rectangle()
                        .fill(isLast ? Color.clear : Color.orange.opacity(0.6))
                        .frame(height: 5)
                }
                
                Circle()
                    .strokeBorder(isNearby ? Color.orange : Color.gray.opacity(0.5), lineWidth: isNearby ? 4 : 2)
                    .background(Circle().fill(isNearby ? Color.orange : Color(.systemBackground)))
                    .frame(width: 16, height: 16)
                    .scaleEffect(isNearby ? animationScale : 1.0)
                    .shadow(color: isNearby ? .orange.opacity(0.8) : .clear, radius: isNearby ? (animationScale * 5) : 0)
            }
            .frame(width: 65)
        }
        .contentShape(Rectangle())
        .onAppear {
            if isNearby {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    animationScale = 1.25
                }
            }
        }
    }
}

// STABILE, CORRETTA E INTEGRATA CON LE TUE PILOTINE (P / A)
struct StationBoardView: View {
    let station: Station
    @State private var showingDepartures = true
    @State private var onlyMagenta = false
    @StateObject private var localManager = TrainManager()
    @State private var selectedTrain: Train?
    
    @State private var isMetroExpanded = false
    @State private var isAlertExpanded = false
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    var filteredTrains: [Train] {
        var result = localManager.trains
        // Siccome abbiamo rimosso il toggle globale, teniamo la logica di fallback spenta o automatica
        if onlyMagenta && station.name != "Magenta" {
            result = result.filter { t in
                let c = t.category.uppercased()
                let d = t.destination.lowercased()
                if c.contains("FR") || c.contains("FA") || c.contains("FB") || c.contains("IC") || c.contains("EC") || c.contains("ITA") || c.contains("NTV") || c.contains("AV") { return false }
                return d.contains("torino") || d.contains("novara") || d.contains("magenta") || d.contains("trecate")
            }
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // 👇 NUOVA INTESTAZIONE COMPATTA CON LE PILOTINE (P / A) SULLO STESSO LIVELLO DEL TITOLO
            HStack(alignment: .center) {
                Text(station.name)
                    .font(.title)
                    .bold()
                
                Spacer()
                
                // Le Pilotine per Partenze (P) e Arrivi (A)
                HStack(spacing: 8) {
                    Button {
                        if !showingDepartures {
                            showingDepartures = true
                            Haptics.play(.medium)
                        }
                    } label: {
                        Text("P")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(width: 36, height: 36)
                            .background(showingDepartures ? Color.orange : Color(.systemGray5))
                            .foregroundColor(showingDepartures ? .white : .primary)
                            .clipShape(Circle())
                    }
                    
                    Button {
                        if showingDepartures {
                            showingDepartures = false
                            Haptics.play(.medium)
                        }
                    } label: {
                        Text("A")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(width: 36, height: 36)
                            .background(!showingDepartures ? Color.orange : Color(.systemGray5))
                            .foregroundColor(!showingDepartures ? .white : .primary)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            // BLOCCO INFO STAZIONE: Salute della linea e Avvisi stazione
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Circle()
                        .fill(localManager.lineHealth.color)
                        .frame(width: 10, height: 10)
                    Text(localManager.lineHealth.message)
                        .font(.subheadline.bold())
                        .foregroundColor(localManager.lineHealth.color)
                    Spacer()
                    
                    if localManager.isLoading {
                        ProgressView()
                    } else if localManager.stationAlerts != nil && !isAlertExpanded {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .transition(.scale)
                    }
                }
                
                if let alerts = localManager.stationAlerts {
                    Divider()
                    DisclosureGroup(isExpanded: $isAlertExpanded) {
                        Text(alerts)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.subheadline)
                            Text("Avvisi della Stazione")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                        }
                    }
                    .tint(.orange)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.top, 10)

            // CARD FISSA DELLA METROPOLITANA: Subito sotto gli avvisi
            if !station.metroLines.isEmpty {
                VStack(spacing: 0) {
                    DisclosureGroup(isExpanded: $isMetroExpanded) {
                        VStack(spacing: 8) {
                            ForEach(station.metroLines) { metro in
                                MetroRowView(metro: metro, currentTime: currentTime)
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        Label("Metropolitana", systemImage: "tram.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .onChange(of: isMetroExpanded) { oldValue, newValue in Haptics.play(.light) }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top, 10)
            }
            
            // Spacerino millimetrico per dare respiro prima dell'inizio della lista
            Spacer().frame(height: 10)

            // LA LISTA DEI TRENI RFI (Ora pulitissima, senza buchi grafici sopra)
            List {
                Section(header: Text("Treni RFI")) {
                    ForEach(filteredTrains) { train in
                        TrainRowView(train: train, manager: localManager)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Haptics.play(.light)
                                selectedTrain = train
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button { localManager.toggleFavorite(trainNumber: train.number, description: train.destination) } label: {
                                    let isFav = localManager.isFavorite(trainNumber: train.number)
                                    Label(isFav ? "Rimuovi" : "Preferito", systemImage: isFav ? "star.slash.fill" : "star.fill")
                                }
                                .tint(localManager.isFavorite(trainNumber: train.number) ? .red : .yellow)
                            }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                Haptics.play(.light)
                await localManager.fetchTrains(for: station.rfiID ?? "", isDepartures: showingDepartures)
            }
            
            Text("Dati in tempo reale da tabelloni RFI")
                .font(.caption2).foregroundColor(.secondary).padding(.bottom, 8)
        }
        .navigationTitle("") // Svuotiamo il titolo di navigazione standard per usare il nostro HStack personalizzato
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedTrain) { t in TrainStopsView(train: t, manager: localManager) }
        .onAppear { localManager.startAutoRefresh(for: station.rfiID ?? "", isDepartures: showingDepartures) }
        .onDisappear { localManager.stopAutoRefresh() }
        .onReceive(timer) { input in self.currentTime = input }
        .task(id: showingDepartures) { await localManager.fetchTrains(for: station.rfiID ?? "", isDepartures: showingDepartures) }
    }
}

struct MetroRowView: View {
    let metro: MetroLine
    let currentTime: Date
    @EnvironmentObject var cache: MetroCache
    
    var body: some View {
        let cacheKey = "\(metro.pdfID ?? "")_\(metro.direction)"
        let isOffline = cache.isOfflineMode[cacheKey] ?? false
        
        HStack(spacing: 12) {
            Circle().fill(metro.color).frame(width: 28, height: 28).overlay(Text(String(metro.name.prefix(2))).font(.system(size: 12, weight: .black)).foregroundColor(.white))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(metro.name).font(.caption).foregroundColor(.secondary).bold()
                    if isOffline {
                        Text("OFFLINE").font(.system(size: 8, weight: .heavy)).padding(.horizontal, 4).background(Color.orange.opacity(0.2)).foregroundColor(.orange).cornerRadius(4)
                    }
                }
                
                let mode = cache.getNextDepartures(metro: metro, now: currentTime)
                switch mode {
                case .closed: Text("Servizio terminato").italic()
                case .frequency(let text):
                    Text(text).font(.system(.caption, design: .rounded)).bold().foregroundColor(.primary)
                case .exact(let deps):
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(deps, id: \.self) { d in
                            HStack {
                                Text(d.timeString).bold()
                                if let dest = d.destinationName { Text(dest).font(.caption2).foregroundColor(.secondary).textCase(.uppercase) }
                            }
                        }
                    }
                }
            }
            Spacer()
            Circle().fill(cache.allSchedules[cacheKey] != nil ? .green : .red).frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
        .task {
            if let pid = metro.pdfID {
                await cache.sync(line: String(metro.name.prefix(2)), pdfID: pid, direction: metro.direction)
            }
        }
    }
}

struct VTStationBoardView: View {
    let stationName: String
    let vtID: String
    @State private var showingDepartures = true
    @StateObject private var localManager = TrainManager()
    @State private var selectedTrain: Train?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(stationName.capitalized)
                    .font(.title)
                    .bold()
                Spacer()
                HStack(spacing: 8) {
                    Button {
                        if !showingDepartures { showingDepartures = true; Haptics.play(.medium) }
                    } label: {
                        Text("P").font(.system(size: 15, weight: .bold)).frame(width: 36, height: 36)
                            .background(showingDepartures ? Color.orange : Color(.systemGray5))
                            .foregroundColor(showingDepartures ? .white : .primary).clipShape(Circle())
                    }
                    Button {
                        if showingDepartures { showingDepartures = false; Haptics.play(.medium) }
                    } label: {
                        Text("A").font(.system(size: 15, weight: .bold)).frame(width: 36, height: 36)
                            .background(!showingDepartures ? Color.orange : Color(.systemGray5))
                            .foregroundColor(!showingDepartures ? .white : .primary).clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            if localManager.isLoading { ProgressView().padding() }
            
            if localManager.trains.isEmpty && !localManager.isLoading {
                VStack { Spacer(); Text("Nessun treno trovato in questa stazione.").foregroundColor(.secondary); Spacer() }
            } else {
                List(localManager.trains) { train in
                    TrainRowView(train: train, manager: localManager)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.play(.light)
                            selectedTrain = train
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button { localManager.toggleFavorite(trainNumber: train.number, description: train.destination) } label: {
                                let isFav = localManager.isFavorite(trainNumber: train.number)
                                Label(isFav ? "Rimuovi" : "Preferito", systemImage: isFav ? "star.slash.fill" : "star.fill")
                            }
                            .tint(localManager.isFavorite(trainNumber: train.number) ? .red : .yellow)
                        }
                }
                .listStyle(.plain)
                .refreshable {
                    Haptics.play(.light)
                    await localManager.fetchVTTrains(for: vtID, isDepartures: showingDepartures)
                }
            }
            Text("Dati in tempo reale da ViaggiaTreno").font(.caption2).foregroundColor(.secondary).padding(.bottom, 8)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if localManager.isMyStation(vtID: vtID) {
                        localManager.removeMyStation(vtID: vtID)
                    } else {
                        localManager.addMyStation(name: stationName, vtID: vtID)
                    }
                } label: {
                    Image(systemName: localManager.isMyStation(vtID: vtID) ? "star.fill" : "star").foregroundColor(.yellow)
                }
            }
        }
        .sheet(item: $selectedTrain) { t in TrainStopsView(train: t, manager: localManager) }
        .onAppear { localManager.loadFavorites() }
        .task(id: showingDepartures) { await localManager.fetchVTTrains(for: vtID, isDepartures: showingDepartures) }
    }
}

struct TrainStopsView: View {
    let train: Train
    @ObservedObject var manager: TrainManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if manager.isStopsLoading { ProgressView().padding() }
                else if let error = manager.stopErrorMessage {
                    VStack { Image(systemName: "clock.badge.exclamationmark").font(.largeTitle).padding(); Text(error).multilineTextAlignment(.center).padding() }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Circle().fill(manager.currentTrainStatus.statusMessage.contains("In orario") ? .green : (manager.currentTrainStatus.isDeparted ? .red : .gray)).frame(width: 12, height: 12)
                            Text(manager.currentTrainStatus.statusMessage).font(.headline).foregroundColor(.primary)
                            Spacer()
                        }
                        if let note = manager.currentTrainStatus.cancellationNote { Text(note).font(.caption).bold().padding(6).background(Color.red.opacity(0.2)).foregroundColor(.red).cornerRadius(4) }
                        if manager.currentTrainStatus.isDeparted {
                            HStack { Image(systemName: "location.fill").foregroundColor(.secondary); Text("Ultimo rilevamento: ").foregroundColor(.secondary); Text(manager.currentTrainStatus.lastStation).bold(); Text("alle \(manager.currentTrainStatus.lastTime)").foregroundColor(.secondary) }.font(.caption)
                        } else { Text("Il treno non ha ancora lasciato la stazione di partenza.").font(.caption).foregroundColor(.secondary) }
                    }
                    .padding().background(Color(.secondarySystemBackground)).cornerRadius(12).padding()
                    
                    List(manager.selectedTrainStops) { stop in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(stop.stationName).font(.headline)
                                
                                if let act = stop.actualTime {
                                    Text("Effettivo: \(act)")
                                        .font(.caption)
                                        .foregroundColor(stop.delay <= 2 ? .green : (stop.delay <= 6 ? .orange : .red))
                                }
                                else if let est = stop.estimatedTime {
                                    Text("Previsto: \(est)")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .bold()
                                }
                            }
                            Spacer()
                            
                            if stop.actualTime == nil && stop.estimatedTime != nil {
                                Text(stop.time)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .strikethrough()
                            } else {
                                Text(stop.time).font(.subheadline).foregroundColor(.secondary)
                            }
                        }
                        .listRowBackground(stop.stationName.lowercased().contains("magenta") ? Color.orange.opacity(0.1) : Color.clear)
                    }
                }
            }
            .navigationTitle("Treno \(train.number)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Chiudi") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            startLiveActivity(train: train)
                        } label: {
                            Image(systemName: "livephoto.play").foregroundColor(.green)
                        }
                        
                        let delayMinutes = train.delay.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "'", with: "")
                        let isDelayed = !train.delay.contains("In orario")
                        let shareText = isDelayed
                            ? "Il treno \(train.number) è in ritardo di \(delayMinutes) minuti, ci vediamo dopo! 🐌"
                            : "Il treno \(train.number) è in perfetto orario, a tra poco! 🚄"
                        
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up").foregroundColor(.blue)
                        }
                        .simultaneousGesture(TapGesture().onEnded { Haptics.play(.light) })
                        
                        Button {
                            manager.toggleFavorite(trainNumber: train.number, description: train.destination)
                        } label: {
                            Image(systemName: manager.isFavorite(trainNumber: train.number) ? "star.fill" : "star").foregroundColor(.yellow)
                        }
                        
                        Button {
                            Haptics.play(.medium)
                            Task { await manager.fetchStops(for: train, isRefresh: true) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(manager.isStopsLoading)
                    }
                }
            }
            .task { await manager.fetchStops(for: train) }
        }
    }

    func startLiveActivity(train: Train) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let existingActivity = Activity<TrainLiveActivityAttributes>.activities.first { activity in
            activity.attributes.trainNumber == train.number
        }
        
        if let activityToStop = existingActivity {
            Task { await activityToStop.end(nil, dismissalPolicy: .immediate) }
            print("Dynamic Island spenta per il treno \(train.number)")
            Haptics.notify(.warning)
            return
        }
        
        let attributes = TrainLiveActivityAttributes(
            trainNumber: train.number,
            destination: train.destination,
            category: train.category
        )
        
        let contentState = TrainLiveActivityAttributes.ContentState(
            delay: train.delay,
            statusMessage: manager.currentTrainStatus.statusMessage,
            lastStation: manager.currentTrainStatus.lastStation
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
            Haptics.notify(.success)
            print("Dynamic Island attivata! ID: \(activity.id)")
        } catch {
            print("Errore Dynamic Island: \(error.localizedDescription)")
            Haptics.notify(.error)
        }
    }
}

struct TrainRowView: View {
    let train: Train
    @ObservedObject var manager: TrainManager
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(train.category)
                        .font(.system(size: 10, weight: .bold))
                        .padding(4)
                        .background(categoryColor(train.category))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    Text(fullCategoryName(train.category, dest: train.destination))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                    
                    Text(train.number)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(train.destination)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(train.time).font(.title3).bold()
                HStack {
                    Text(train.delay)
                        .foregroundColor(train.delay.contains("In orario") ? .green : .red)
                        .scaleEffect(train.delay.contains("In orario") ? pulseScale : 1.0)
                        .opacity(train.delay.contains("In orario") ? pulseOpacity : 1.0)
                        
                    Text("Bin. \(train.platform)")
                        .padding(.horizontal, 4)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.yellow)
                        .cornerRadius(4)
                }
                .font(.caption).bold()
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            if train.delay.contains("In orario") {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                    pulseOpacity = 0.7
                }
            }
        }
    }
    
    func fullCategoryName(_ c: String, dest: String) -> String {
        let cat = c.uppercased()
        if cat.contains("FR") { return "Frecciarossa" }
        if cat.contains("RV") { return "Regionale Veloce" }
        if cat.contains("AV") || cat.contains("ALTA VELOCIT") { return "Alta Velocità" }
        if cat.contains("IC") { return "Intercity" }
        if cat.contains("EC") { return "Eurocity" }
        if cat.contains("S6") || (cat == "S" && (dest.lowercased().contains("novara") || dest.lowercased().contains("treviglio"))) { return "Suburbano" }
        if cat.contains("NTV") || cat.contains("ITA") { return "Italo" }
        return "Treno"
    }
    
    func categoryColor(_ cat: String) -> Color {
        let c = cat.uppercased()
        if c.contains("FR") || c.contains("ITA") || c == "AV" { return .red }
        if c == "IC" || c == "EC" { return .gray }
        if c.contains("S") { return Color(red: 0.0, green: 0.6, blue: 0.2) }
        if c.contains("RV") || c.contains("RE") { return .blue }
        return .gray
    }
}

#Preview { ContentView() }
