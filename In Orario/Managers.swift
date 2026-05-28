import SwiftUI
import Combine
import Foundation
import CoreLocation
import ActivityKit


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
        // Eliminato startUpdatingLocation per non consumare batteria inutilmente
    }
    
    func requestAuthorization() {
        print("Richiesta esplicita di autorizzazione GPS...")
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        print("Richiesta esplicita della posizione GPS in corso...")
        manager.requestLocation()
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        print("Stato autorizzazione GPS: \(status.rawValue)")
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            print("Permesso GPS accordato. Richiedo la posizione...")
            manager.requestLocation()
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            print("Posizione GPS aggiornata con successo: \(loc.coordinate.latitude), \(loc.coordinate.longitude)")
            Task { @MainActor in self.userLocation = loc }
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Errore localizzazione GPS (didFailWithError): \(error.localizedDescription)")
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
    @Published var activeLiveActivities: Set<String> = []
    
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
            self.myStations = []
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
        if let encoded = try? JSONEncoder().encode(favoriteTrains) { 
            UserDefaults.standard.set(encoded, forKey: favoritesKey) 
            if let groupDefaults = UserDefaults(suiteName: "group.carlo.InOrario") {
                groupDefaults.set(encoded, forKey: favoritesKey)
            }
        }
        if let encoded = try? JSONEncoder().encode(myStations) { 
            UserDefaults.standard.set(encoded, forKey: myStationsKey) 
            if let groupDefaults = UserDefaults(suiteName: "group.carlo.InOrario") {
                groupDefaults.set(encoded, forKey: myStationsKey)
            }
        }
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
    
    func syncLiveActivities() {
        let active = Activity<TrainLiveActivityAttributes>.activities.map { $0.attributes.trainNumber }
        self.activeLiveActivities = Set(active)
    }
    
    func backgroundLiveActivityUpdate() async {
        syncLiveActivities()
        guard !activeLiveActivities.isEmpty else { return }
        
        for trainNumber in activeLiveActivities {
            // Crea un treno temporaneo solo per lanciare la richiesta API. 
            // La fetchStops usa internamente Activity.update per notificare il widget se c'è.
            let dummy = Train(category: "REG", number: trainNumber, destination: "", time: "", delay: "", platform: "")
            await fetchStops(for: dummy, isRefresh: true)
        }
    }
    
    func createDummyTrain(from saved: SavedTrain) -> Train {
        var cat = "REG"
        if saved.number.hasPrefix("20") || saved.number.hasPrefix("21") { cat = "RV" }
        else if saved.number.hasPrefix("24") || saved.number.hasPrefix("10") { cat = "S" }
        else if saved.number.hasPrefix("9") { cat = "FR" }
        return Train(category: cat, number: saved.number, destination: saved.description.capitalized, time: "--:--", delay: "In orario", platform: "--")
    }
}

