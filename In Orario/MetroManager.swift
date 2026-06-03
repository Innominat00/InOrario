import Foundation
import Combine

@MainActor class MetroCache: ObservableObject {
    @Published var allSchedules: [String: FullSchedule] = [:]
    @Published var isOfflineMode: [String: Bool] = [:]
    
    private let storageKey = "com.magenta.metro.cache"
    private let baseURL = "https://gestioneinorario.toreroclub.com"
    
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
