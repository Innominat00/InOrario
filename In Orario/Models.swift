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
    case myStations = "Le Mie Stazioni"
    case favoriteTrains = "I miei Treni"
    case passante = "Passante Ferroviario"
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
