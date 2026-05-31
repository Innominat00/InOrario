import SwiftUI
import Combine
import Foundation
import CoreLocation
import ActivityKit


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
    nonisolated static var time: DateFormatter {
        if let formatter = Thread.current.threadDictionary["timeFormatter"] as? DateFormatter {
            return formatter
        }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = TimeZone(identifier: "Europe/Rome")
        Thread.current.threadDictionary["timeFormatter"] = f
        return f
    }
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

struct TrenitaliaLocation: Codable, Identifiable {
    var id: Int
    let name: String
    let displayName: String
}

struct RFIStation: Codable, Identifiable, Hashable {
    let id: String
    let name: String
}

struct Train: Identifiable, Sendable {
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

struct TrainStatus: Sendable {
    var lastStation: String = "--"
    var lastTime: String = "--"
    var statusMessage: String = "In attesa di dati..."
    var isDeparted: Bool = false
    var cancellationNote: String? = nil
}

struct Stop: Identifiable, Sendable {
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
    case myStations = "Le Mie Stazioni"
    case favoriteTrains = "I miei Treni"
    case passante = "Linee Suburbane"
}

struct SuburbanLine: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let hexColor: String
    let stations: [Station]
    
    var color: Color {
        Color(hex: hexColor)
    }
}

struct SuburbanRoute: Codable, Identifiable, Equatable {
    var id: String { "\(originName)-\(destinationName)" }
    let originName: String
    let destinationName: String
}

// Estensione per leggere l'esadecimale
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct SuburbanData {
    static let shared = SuburbanData()
    
    let allLines: [SuburbanLine]
    
    private init() {
        // --- Stazioni ---
        let bovisa = Station(name: "Milano Bovisa", rfiID: nil, vtID: "S01201", lat: 45.5025, lon: 9.1592)
        let certosa = Station(name: "Certosa", rfiID: "1708", vtID: "S01027", lat: 45.5085, lon: 9.1272)
        let villapizzone = Station(name: "Villapizzone", rfiID: "3099", vtID: "S01057", lat: 45.4998, lon: 9.1465)
        let lancetti = Station(name: "Lancetti", rfiID: "1713", vtID: "S01059", lat: 45.4925, lon: 9.1751)
        let garibaldiPassante = Station(name: "P. Garibaldi Passante", rfiID: "1714", vtID: "S01058", lat: 45.4844, lon: 9.1887)
        let repubblica = Station(name: "Repubblica", rfiID: "1719", vtID: "S01060", lat: 45.4795, lon: 9.1963)
        let venezia = Station(name: "Porta Venezia", rfiID: "1723", vtID: "S01061", lat: 45.4746, lon: 9.2052)
        let dateo = Station(name: "Dateo", rfiID: "3468", vtID: "S01062", lat: 45.4682, lon: 9.2158)
        let vittoria = Station(name: "Porta Vittoria", rfiID: "1718", vtID: "S01063", lat: 45.4613, lon: 9.2227)
        let rogoredo = Station(name: "Milano Rogoredo", rfiID: "1726", vtID: "S01724", lat: 45.4333, lon: 9.2389)
        let forlanini = Station(name: "Forlanini", rfiID: "3169", vtID: "S01064", lat: 45.4625, lon: 9.2368)
        
        let domodossola = Station(name: "Milano Domodossola", rfiID: nil, vtID: "S01206", lat: 45.4811, lon: 9.1619)
        let cadorna = Station(name: "Milano Cadorna", rfiID: nil, vtID: "S01200", lat: 45.4686, lon: 9.1752)
        
        let saronno = Station(name: "Saronno", rfiID: nil, vtID: "S01150", lat: 45.6264, lon: 9.0336)
        let greco = Station(name: "Milano Greco Pirelli", rfiID: "1706", vtID: "S01712", lat: 45.5129, lon: 9.2141)
        let lambrate = Station(name: "Milano Lambrate", rfiID: "1704", vtID: "S01704", lat: 45.4849, lon: 9.2373)
        let romana = Station(name: "Milano P. Romana", rfiID: "1727", vtID: "S01721", lat: 45.4458, lon: 9.2131)
        let tibaldi = Station(name: "Milano Tibaldi", rfiID: "3540", vtID: "S01725", lat: 45.4436, lon: 9.1840)
        let romolo = Station(name: "Milano Romolo", rfiID: "1732", vtID: "S01722", lat: 45.4432, lon: 9.1678)
        let cristoforo = Station(name: "Milano S. Cristoforo", rfiID: "1731", vtID: "S01723", lat: 45.4425, lon: 9.1302)
        let albairate = Station(name: "Albairate", rfiID: "1734", vtID: "S01035", lat: 45.4044, lon: 8.9575)
        
        let garibaldiSup = Station(name: "Milano P. Garibaldi", rfiID: "1715", vtID: "S01058", lat: 45.4844, lon: 9.1887)
        let rhoFiera = Station(name: "Rho Fiera", rfiID: "3098", vtID: "S01026", lat: 45.5215, lon: 9.0883)
        
        // --- Flussi ---
        let tunnelOvestBovisa = [bovisa, lancetti, garibaldiPassante, repubblica, venezia, dateo, vittoria, rogoredo]
        let tunnelOvestCertosa = [rhoFiera, certosa, villapizzone, lancetti, garibaldiPassante, repubblica, venezia, dateo, vittoria, forlanini]
        let ramoCadorna = [bovisa, domodossola, cadorna]
        let cinturaS9 = [saronno, greco, lambrate, forlanini, romana, tibaldi, romolo, cristoforo, albairate]
        let superficieS11 = [greco, garibaldiSup, villapizzone, certosa, rhoFiera]
        
        // --- Linee ---
        self.allLines = [
            SuburbanLine(id: "S1", name: "S1 Saronno - Lodi", hexColor: "#e30613", stations: tunnelOvestBovisa),
            SuburbanLine(id: "S2", name: "S2 Mariano - Rogoredo", hexColor: "#009640", stations: tunnelOvestBovisa),
            SuburbanLine(id: "S3", name: "S3 Saronno - Cadorna", hexColor: "#a61a30", stations: ramoCadorna),
            SuburbanLine(id: "S4", name: "S4 Camnago - Cadorna", hexColor: "#8ec06c", stations: ramoCadorna),
            SuburbanLine(id: "S5", name: "S5 Varese - Treviglio", hexColor: "#f39200", stations: tunnelOvestCertosa),
            SuburbanLine(id: "S6", name: "S6 Novara - Pioltello", hexColor: "#ffd60a", stations: tunnelOvestCertosa),
            SuburbanLine(id: "S7", name: "S7 Lecco - P. Garibaldi", hexColor: "#ec008c", stations: [garibaldiSup]),
            SuburbanLine(id: "S8", name: "S8 Lecco - P. Garibaldi", hexColor: "#fbc5b0", stations: [garibaldiSup]),
            SuburbanLine(id: "S9", name: "S9 Saronno - Albairate", hexColor: "#7e1f7c", stations: cinturaS9),
            SuburbanLine(id: "S11", name: "S11 Chiasso - Rho", hexColor: "#8a8bbf", stations: superficieS11),
            SuburbanLine(id: "S12", name: "S12 Cormano - Melegnano", hexColor: "#005a2b", stations: tunnelOvestBovisa),
            SuburbanLine(id: "S13", name: "S13 Bovisa - Pavia", hexColor: "#a37a3e", stations: tunnelOvestBovisa),
            SuburbanLine(id: "S19", name: "S19", hexColor: "#5a0f2b", stations: [])
        ]
    }
}

struct TravelSegment: Identifiable, Sendable {
    let id = UUID()
    var origin: String
    var destination: String
    let departureTime: String
    let arrivalTime: String
    var trainNumber: String
    var trainCategory: String
}

struct TravelSolution: Identifiable, Sendable {
    let id = UUID()
    let trainNumber: String
    let category: String
    let departureTime: String
    let arrivalTime: String
    let origin: String
    let destination: String
    let duration: String
    var segments: [TravelSegment]
}

struct FavoriteRoute: Codable, Identifiable, Equatable {
    var id: String { "\(originID)-\(destinationID)" }
    let originName: String
    let originID: String
    let destinationName: String
    let destinationID: String
}

struct SavedTripSegment: Codable, Equatable {
    let origin: String
    let destination: String
    let departureTime: String
    let arrivalTime: String
    let trainNumber: String
    let trainCategory: String
}

struct SavedTrip: Codable, Identifiable, Equatable {
    let id: String // Can be a composite of origin, dest, departureTime
    let origin: String
    let destination: String
    let departureTime: String
    let arrivalTime: String
    let duration: String
    let segments: [SavedTripSegment]
    
    var asTravelSolution: TravelSolution {
        let mappedSegments = segments.map { TravelSegment(origin: $0.origin, destination: $0.destination, departureTime: $0.departureTime, arrivalTime: $0.arrivalTime, trainNumber: $0.trainNumber, trainCategory: $0.trainCategory) }
        return TravelSolution(trainNumber: "", category: "Viaggio", departureTime: departureTime, arrivalTime: arrivalTime, origin: origin, destination: destination, duration: duration, segments: mappedSegments)
    }
}
