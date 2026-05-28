import WidgetKit
import SwiftUI

struct WidgetSavedTrain: Codable, Identifiable {
    var id: String { number }
    let number: String
    let description: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), trains: [
            WidgetSavedTrain(number: "2010", description: "Milano Centrale"),
            WidgetSavedTrain(number: "24555", description: "Treviglio")
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let trains = getFavorites()
        let entry = SimpleEntry(date: Date(), trains: trains.isEmpty ? placeholder(in: context).trains : trains)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let trains = getFavorites()
        let entry = SimpleEntry(date: Date(), trains: trains)
        
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
    
    private func getFavorites() -> [WidgetSavedTrain] {
        guard let defaults = UserDefaults(suiteName: "group.carlo.InOrario"),
              let data = defaults.data(forKey: "savedFavoriteTrains_v3"),
              let decoded = try? JSONDecoder().decode([WidgetSavedTrain].self, from: data) else {
            return []
        }
        return decoded
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let trains: [WidgetSavedTrain]
}

struct TrainWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Treni Preferiti")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.bottom, 4)

            if entry.trains.isEmpty {
                Text("Nessun treno preferito.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                let displayCount = family == .systemSmall ? 2 : 4
                ForEach(entry.trains.prefix(displayCount)) { train in
                    Link(destination: URL(string: "inorario://\(train.number)")!) {
                        HStack {
                            Image(systemName: "train.side.front.car")
                                .foregroundColor(.blue)
                                .font(.subheadline)
                            VStack(alignment: .leading) {
                                Text("Treno \(train.number)")
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundColor(.primary)
                                Text(train.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
            Spacer()
        }
    }
}

struct TrainWidget: Widget {
    let kind: String = "TrainWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                TrainWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TrainWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Treni Preferiti")
        .description("Accedi rapidamente ai tuoi treni preferiti.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
