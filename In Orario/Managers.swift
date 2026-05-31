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
    @Published var userLocation: CLLocation? {
        didSet {
            updateNearbyStation()
        }
    }
    @Published var nearbyStation: Station?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestAuthorization() {
        print("Richiesta esplicita di autorizzazione GPS...")
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        print("Richiesta esplicita della posizione GPS in corso...")
        manager.requestLocation()
    }
    
    private func updateNearbyStation() {
        guard let userLoc = userLocation else {
            self.nearbyStation = nil
            return
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
        
        let mainStations = [
            Station(name: "Magenta", rfiID: "1618", vtID: "S01021", lat: 45.4641, lon: 8.8845),
            Station(name: "Rho Fiera", rfiID: "3098", vtID: "S01026", lat: 45.5215, lon: 9.0883),
            Station(name: "Porta Garibaldi", rfiID: "1715", vtID: "S01058", lat: 45.4844, lon: 9.1887),
            Station(name: "Milano Centrale", rfiID: "1728", vtID: "S01700", lat: 45.4849, lon: 9.2033),
            Station(name: "Vittuone-Arluno", rfiID: "3119", vtID: "S01023", lat: 45.4921, lon: 8.9568),
            Station(name: "Pregnana Milanese", rfiID: "381", vtID: "S01024", lat: 45.5036, lon: 9.0069),
            Station(name: "Novara", rfiID: "1917", vtID: "S01017", lat: 45.4524, lon: 8.6253),
            Station(name: "Trecate", rfiID: "2909", vtID: "S01019", lat: 45.4374, lon: 8.7428),
            Station(name: "Rho", rfiID: "2345", vtID: "S01025", lat: 45.5262, lon: 9.0402)
        ]
        
        let allReferenceStations = mainStations + passanteStations
        
        let sortedCandidates = allReferenceStations.compactMap { s -> (Station, Double)? in
            guard let c = s.coordinate else { return nil }
            let dist = userLoc.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
            return (s, dist)
        }.sorted(by: { $0.1 < $1.1 })
        
        if let closest = sortedCandidates.first, closest.1 < 15000 { // 15 km
            self.nearbyStation = closest.0
        } else {
            self.nearbyStation = nil
        }
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

struct StopsResult: Sendable {
    let stops: [Stop]
    let status: TrainStatus
    let errorMessage: String?
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
    @Published var searchTrenitaliaLocations: [TrenitaliaLocation] = []
    @Published var rfiStationDictionary: [String: String] = [:]
    @Published var rfiStationNormalizedDict: [String: String] = [:]
    @Published var searchRFIStationResults: [RFIStation] = []
    @Published var allRFIStations: [RFIStation] = []
    @Published var sectionOrder: [AppSection] = AppSection.allCases
    @Published var isSearching: Bool = false
    @Published var isLoading = false
    @Published var isStopsLoading = false
    @Published var stopErrorMessage: String? = nil
    @Published var deepLinkTrain: Train? = nil
    
    @Published var stationAlerts: String? = nil
    @Published var activeLiveActivities: Set<String> = []
    
    @Published var travelSolutions: [TravelSolution] = []
    @Published var favoriteRoutes: [FavoriteRoute] = []
    @Published var savedTrips: [SavedTrip] = []
    @Published var isSearchingSolutions: Bool = false
    
    // --- Linee Suburbane ---
    @Published var selectedSuburbanLines: [String] = []
    @Published var hiddenSuburbanStations: [String: [String]] = [:] // idLinea -> [idStazione o Nome]
    
    private var refreshTimer: AnyCancellable?
    
    private let favoritesKey = "savedFavoriteTrains_v3"
    private let myStationsKey = "savedMyStations_v3"
    private let sectionOrderKey = "savedSectionOrder_v3"
    private let favoriteRoutesKey = "savedFavoriteRoutes_v1"
    private let savedTripsKey = "savedTrips_v1"
    private let selectedSuburbanLinesKey = "selectedSuburbanLines_v1"
    private let hiddenSuburbanStationsKey = "hiddenSuburbanStations_v1"
    
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
    
    init() { 
        loadFavorites()
        loadRFIStations()
    }
    
    private func loadRFIStations() {
        if let url = Bundle.main.url(forResource: "rfi_stations", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([RFIStation].self, from: data) {
            self.allRFIStations = decoded
            
            var dict: [String: String] = [:]
            var normDict: [String: String] = [:]
            for station in decoded {
                let lower = station.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                dict[lower] = station.id
                
                let norm = normalizeStationName(station.name)
                normDict[norm] = station.id
            }
            self.rfiStationDictionary = dict
            self.rfiStationNormalizedDict = normDict
        }
    }
    
    func normalizeStationName(_ name: String) -> String {
        return name.lowercased()
            .replacingOccurrences(of: "p.", with: "porta")
            .replacingOccurrences(of: "s.", with: "san")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "'", with: "")
            .folding(options: .diacriticInsensitive, locale: .current)
    }
    
    func getRfiID(for vtName: String) -> String? {
        let lower = vtName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = rfiStationDictionary[lower] {
            return exact
        }
        let norm = normalizeStationName(vtName)
        return rfiStationNormalizedDict[norm]
    }
    
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
        
        if let data = UserDefaults.standard.data(forKey: favoriteRoutesKey), let decoded = try? JSONDecoder().decode([FavoriteRoute].self, from: data) {
            self.favoriteRoutes = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: savedTripsKey), let decoded = try? JSONDecoder().decode([SavedTrip].self, from: data) {
            self.savedTrips = decoded
        }
        
        if let data = UserDefaults.standard.data(forKey: selectedSuburbanLinesKey), let decoded = try? JSONDecoder().decode([String].self, from: data) {
            self.selectedSuburbanLines = decoded
        } else {
            // Se non ci sono dati, ad esempio mettiamo S5 e S6 come default storico (Certosa-Forlanini)
            self.selectedSuburbanLines = ["S5", "S6"]
        }
        
        if let data = UserDefaults.standard.data(forKey: hiddenSuburbanStationsKey), let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            self.hiddenSuburbanStations = decoded
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
        if let encoded = try? JSONEncoder().encode(favoriteRoutes) {
            UserDefaults.standard.set(encoded, forKey: favoriteRoutesKey)
            if let groupDefaults = UserDefaults(suiteName: "group.carlo.InOrario") {
                groupDefaults.set(encoded, forKey: favoriteRoutesKey)
            }
        }
        if let encoded = try? JSONEncoder().encode(savedTrips) {
            UserDefaults.standard.set(encoded, forKey: savedTripsKey)
            if let groupDefaults = UserDefaults(suiteName: "group.carlo.InOrario") {
                groupDefaults.set(encoded, forKey: savedTripsKey)
            }
        }
        if let encoded = try? JSONEncoder().encode(selectedSuburbanLines) {
            UserDefaults.standard.set(encoded, forKey: selectedSuburbanLinesKey)
        }
        if let encoded = try? JSONEncoder().encode(hiddenSuburbanStations) {
            UserDefaults.standard.set(encoded, forKey: hiddenSuburbanStationsKey)
        }
    }
    
    func toggleSuburbanLine(_ id: String) {
        if selectedSuburbanLines.contains(id) {
            selectedSuburbanLines.removeAll { $0 == id }
        } else {
            selectedSuburbanLines.append(id)
        }
        saveFavorites()
    }
    
    func toggleHiddenStation(lineId: String, stationName: String) {
        var hiddenForLine = hiddenSuburbanStations[lineId] ?? []
        if hiddenForLine.contains(stationName) {
            hiddenForLine.removeAll { $0 == stationName }
        } else {
            hiddenForLine.append(stationName)
        }
        hiddenSuburbanStations[lineId] = hiddenForLine
        saveFavorites()
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
    
    func toggleFavoriteRoute(originName: String, originID: String, destName: String, destID: String) {
        if let index = favoriteRoutes.firstIndex(where: { $0.originID == originID && $0.destinationID == destID }) {
            favoriteRoutes.remove(at: index)
            Haptics.notify(.warning)
        } else {
            favoriteRoutes.append(FavoriteRoute(originName: originName, originID: originID, destinationName: destName, destinationID: destID))
            Haptics.notify(.success)
        }
        saveFavorites()
    }
    
    func isFavoriteRoute(originID: String, destID: String) -> Bool {
        return favoriteRoutes.contains { $0.originID == originID && $0.destinationID == destID }
    }
    
    func toggleSavedTrip(solution: TravelSolution) {
        let tripId = "\(solution.origin)-\(solution.destination)-\(solution.departureTime)"
        if let index = savedTrips.firstIndex(where: { $0.id == tripId }) {
            savedTrips.remove(at: index)
            Haptics.notify(.warning)
        } else {
            let segs = solution.segments.map { SavedTripSegment(origin: $0.origin, destination: $0.destination, departureTime: $0.departureTime, arrivalTime: $0.arrivalTime, trainNumber: $0.trainNumber, trainCategory: $0.trainCategory) }
            let saved = SavedTrip(id: tripId, origin: solution.origin, destination: solution.destination, departureTime: solution.departureTime, arrivalTime: solution.arrivalTime, duration: solution.duration, segments: segs)
            savedTrips.append(saved)
            Haptics.notify(.success)
        }
        saveFavorites()
    }
    
    func isTripSaved(solution: TravelSolution) -> Bool {
        let tripId = "\(solution.origin)-\(solution.destination)-\(solution.departureTime)"
        return savedTrips.contains { $0.id == tripId }
    }
    
    func addMyStation(name: String, vtID: String) {
        if !myStations.contains(where: { $0.vtID == vtID }) {
            let possibleRfiID = getRfiID(for: name)
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
    
    func searchTravelLocations(query: String) async {
        guard query.count >= 2 else { self.searchTrenitaliaLocations = []; return }
        self.isSearching = true
        let safeQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://www.lefrecce.it/Channels.Website.BFF.WEB/website/locations/search?name=\(safeQuery)"
        guard let url = URL(string: urlString) else { self.isSearching = false; return }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            self.searchTrenitaliaLocations = (try? JSONDecoder().decode([TrenitaliaLocation].self, from: data)) ?? []
            self.isSearching = false
        } catch { self.isSearching = false }
    }
    
    func searchTravelSolutions(originID: String, destID: String, date: Date) async {
        self.isSearchingSolutions = true
        self.travelSolutions = []
        
        guard let depId = Int(originID), let arrId = Int(destID) else {
            self.isSearchingSolutions = false
            return
        }
        
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Rome")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.000ZZZZZ"
        let dateStr = f.string(from: date)
        
        let urlString = "https://www.lefrecce.it/Channels.Website.BFF.WEB/website/ticket/solutions"
        guard let url = URL(string: urlString) else { self.isSearchingSolutions = false; return }
        
        let payload: [String: Any] = [
            "departureLocationId": depId,
            "arrivalLocationId": arrId,
            "departureTime": dateStr,
            "adults": 1,
            "children": 0,
            "criteria": [
                "frecceOnly": false,
                "regionalOnly": false,
                "noChanges": false,
                "order": "DEPARTURE_DATE",
                "offset": 0,
                "limit": 15
            ],
            "advancedSearchRequest": [
                "bestFare": false
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, _) = try await URLSession.shared.data(for: request)
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let solutions = json["solutions"] as? [[String: Any]] else {
                self.isSearchingSolutions = false
                return
            }
            
            var parsedSolutions: [TravelSolution] = []
            
            for item in solutions {
                guard let sol = item["solution"] as? [String: Any] else { continue }
                
                let origin = (sol["origin"] as? String) ?? ""
                let destination = (sol["destination"] as? String) ?? ""
                let duration = (sol["duration"] as? String) ?? ""
                
                var depTimeStr = "--:--"
                var arrTimeStr = "--:--"
                
                if let dt = sol["departureTime"] as? String, let d = f.date(from: dt) {
                    depTimeStr = SharedFormatters.time.string(from: d)
                }
                if let at = sol["arrivalTime"] as? String, let a = f.date(from: at) {
                    arrTimeStr = SharedFormatters.time.string(from: a)
                }
                
                var category = "Treno"
                var num = ""
                
                if let trains = sol["trains"] as? [[String: Any]], let firstTrain = trains.first {
                    category = (firstTrain["trainCategory"] as? String) ?? (firstTrain["acronym"] as? String) ?? "Treno"
                    num = (firstTrain["name"] as? String) ?? (firstTrain["description"] as? String) ?? ""
                    
                    // If there are multiple trains, denote changes
                    if trains.count > 1 {
                        num += " (+\(trains.count - 1) cambi)"
                    }
                }
                
                var segments: [TravelSegment] = []
                
                if let nodes = sol["nodes"] as? [[String: Any]] {
                    for node in nodes {
                        let nodeOrigin = (node["origin"] as? String) ?? ""
                        let nodeDest = (node["destination"] as? String) ?? ""
                        var nDepStr = "--:--"
                        var nArrStr = "--:--"
                        
                        if let dt = node["departureTime"] as? String, let d = f.date(from: dt) { nDepStr = SharedFormatters.time.string(from: d) }
                        if let at = node["arrivalTime"] as? String, let a = f.date(from: at) { nArrStr = SharedFormatters.time.string(from: a) }
                        
                        var nCat = "Treno"
                        var nNum = ""
                        if let train = node["train"] as? [String: Any] {
                            nCat = (train["trainCategory"] as? String) ?? (train["acronym"] as? String) ?? "Treno"
                            nNum = (train["name"] as? String) ?? (train["description"] as? String) ?? ""
                        }
                        
                        if nodeOrigin.lowercased().hasPrefix("milano") && nodeDest.lowercased().hasPrefix("milano") && nodeOrigin != nodeDest {
                            nCat = "Trasporto Urbano"
                            nNum = "(Metro / Mezzi)"
                        }
                        
                        segments.append(TravelSegment(
                            origin: nodeOrigin,
                            destination: nodeDest,
                            departureTime: nDepStr,
                            arrivalTime: nArrStr,
                            trainNumber: nNum,
                            trainCategory: nCat
                        ))
                    }
                }
                
                parsedSolutions.append(TravelSolution(
                    trainNumber: num,
                    category: category,
                    departureTime: depTimeStr,
                    arrivalTime: arrTimeStr,
                    origin: origin.capitalized,
                    destination: destination.capitalized,
                    duration: duration,
                    segments: segments
                ))
            }
            
            self.travelSolutions = parsedSolutions
            self.isSearchingSolutions = false
            
        } catch {
            self.isSearchingSolutions = false
        }
    }
    
    func searchRFIStationsLocally(query: String) {
        guard query.count >= 2 else { self.searchRFIStationResults = []; return }
        let lowerQuery = query.lowercased()
        self.searchRFIStationResults = self.allRFIStations.filter { $0.name.lowercased().contains(lowerQuery) }
    }
    
    // --- OFF-MAIN-THREAD OPTIMIZATIONS ---
    
    nonisolated private func performVTFetch(for vtID: String, isDepartures: Bool, dateStr: String) async -> [Train] {
        let endpoint = isDepartures ? "partenze" : "arrivi"
        let urlString = "https://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/\(endpoint)/\(vtID)/\(dateStr)"
        guard let url = URL(string: urlString) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
            
            return jsonArray.compactMap { item in
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
        } catch {
            return []
        }
    }
    
    func fetchVTTrains(for vtID: String, isDepartures: Bool) async {
        self.isLoading = true
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Rome")
        f.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'ZZZ"
        let dateStr = f.string(from: Date()).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        
        let fetchedTrains = await performVTFetch(for: vtID, isDepartures: isDepartures, dateStr: dateStr)
        
        self.trains = fetchedTrains
        self.isLoading = false
    }
    
    nonisolated private func stripHTML(_ str: String) -> String {
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
    
    nonisolated private func performRfiScraping(for rfiID: String, isDepartures: Bool) async -> (trains: [Train], alerts: String?) {
        let urlString = "https://iechub.rfi.it/ArriviPartenze/ArrivalsDepartures/Monitor?placeId=\(rfiID)&arrivals=\(!(isDepartures))"
        guard let url = URL(string: urlString) else { return ([], nil) }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else { return ([], nil) }
            
            var stationAlerts: String? = nil
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
                        stationAlerts = cleanAlert
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
            return (scrapedTrains, stationAlerts)
        } catch {
            return ([], nil)
        }
    }
    
    func fetchTrains(for rfiID: String, isDepartures: Bool) async {
        self.isLoading = true
        self.stationAlerts = nil
        
        let scraped = await performRfiScraping(for: rfiID, isDepartures: isDepartures)
        
        self.trains = scraped.trains
        self.stationAlerts = scraped.alerts
        self.isLoading = false
    }
    
    
    nonisolated func fetchLiveStops(for trainNumber: String) async -> StopsResult {
        let cleanNumber = trainNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchUrl = "https://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/cercaNumeroTrenoTrenoAutocomplete/\(cleanNumber)"
        
        guard let sUrl = URL(string: searchUrl) else {
            return await StopsResult(stops: [], status: TrainStatus(), errorMessage: "URL non valido.")
        }
        
        do {
            let (sData, _) = try await URLSession.shared.data(from: sUrl)
            let result = String(data: sData, encoding: .utf8) ?? ""
            
            if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return await StopsResult(stops: [], status: TrainStatus(), errorMessage: "Treno non tracciato o non ancora nel sistema.")
            }
            
            let lines = result.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard let targetLine = lines.first(where: { $0.contains("|\(cleanNumber)-") }) ?? lines.first else {
                return await StopsResult(stops: [], status: TrainStatus(), errorMessage: "Dettagli del treno non trovati.")
            }
            
            let pipes = targetLine.components(separatedBy: "|")
            guard pipes.count >= 2 else {
                return await StopsResult(stops: [], status: TrainStatus(), errorMessage: "Dati API ViaggiaTreno incompleti.")
            }
            
            let subParts = pipes[1].components(separatedBy: "-")
            guard subParts.count >= 2 else {
                return await StopsResult(stops: [], status: TrainStatus(), errorMessage: "ID Stazione di origine non trovato.")
            }
            
            let originID = subParts[1]
            let timestamp = subParts.count >= 3 ? subParts[2] : ""
            
            var stopsUrl = "https://www.viaggiatreno.it/infomobilita/resteasy/viaggiatreno/andamentoTreno/\(originID)/\(cleanNumber)"
            if !timestamp.isEmpty { stopsUrl += "/\(timestamp)" }
            
            guard let stUrl = URL(string: stopsUrl) else {
                return await StopsResult(stops: [], status: TrainStatus(), errorMessage: "URL fermate non valido.")
            }
            
            let request = URLRequest(url: stUrl)
            let (stData, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, !stData.isEmpty else {
                return await StopsResult(stops: [], status: TrainStatus(), errorMessage: "Dati in aggiornamento o temporaneamente non disponibili.")
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: stData) as? [String: Any] else {
                return await StopsResult(stops: [], status: TrainStatus(), errorMessage: "Il server ha restituito dati illeggibili.")
            }
            
            var status = await TrainStatus()
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
                return StopsResult(stops: mappedStops, status: status, errorMessage: nil)
            }
            return StopsResult(stops: [], status: status, errorMessage: "Nessuna fermata trovata.")
        } catch is CancellationError {
            return await StopsResult(stops: [], status: TrainStatus(), errorMessage: nil)
        } catch {
            return await StopsResult(stops: [], status: TrainStatus(), errorMessage: "Errore di rete o blocco di sicurezza (controlla i permessi ATS nel file Info.plist).")
        }
    }
    
    func fetchStops(for train: Train, isRefresh: Bool = false) async {
        if !isRefresh {
            self.selectedTrainStops = []
            self.currentTrainStatus = TrainStatus()
            self.isStopsLoading = true
            self.stopErrorMessage = nil
        }
        
        let cleanNumber = train.number.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = await fetchLiveStops(for: cleanNumber)
        
        if !isRefresh || result.errorMessage == nil {
            self.selectedTrainStops = result.stops
            self.currentTrainStatus = result.status
            self.stopErrorMessage = result.errorMessage
        }
        
        if !isRefresh {
            self.isStopsLoading = false
        }
        
        // Update Live Activity if any
        if result.errorMessage == nil {
            let globalDelay = result.status.statusMessage.contains("Soppresso") ? 0 : (result.stops.last?.delay ?? 0)
            let delayStr = globalDelay > 0 ? "+\(globalDelay)'" : "In orario"
            let updatedState = TrainLiveActivityAttributes.ContentState(
                delay: delayStr,
                statusMessage: result.status.statusMessage,
                lastStation: result.status.lastStation
            )
            
            for activity in Activity<TrainLiveActivityAttributes>.activities {
                if activity.attributes.trainNumber == cleanNumber {
                    await activity.update(ActivityContent(state: updatedState, staleDate: nil))
                }
            }
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
