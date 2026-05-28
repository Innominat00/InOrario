import ActivityKit
import WidgetKit
import SwiftUI

struct TrainWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TrainLiveActivityAttributes.self) { context in
            // VISTA 1: SCHERMATA DI BLOCCO (Lock Screen)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(context.attributes.category) \(context.attributes.trainNumber)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text(context.state.delay)
                        .font(.headline)
                        .foregroundColor(context.state.delay.contains("In orario") ? .green : .red)
                }
                Text("Dir. \(context.attributes.destination)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Divider().background(Color.gray.opacity(0.5))
                
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(context.state.lastStation)
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(context.state.statusMessage)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .widgetURL(URL(string: "inorario://train/\(context.attributes.trainNumber)"))
            
        } dynamicIsland: { context in
            // VISTA 2: DYNAMIC ISLAND
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.trainNumber)
                        .font(.headline)
                        .foregroundColor(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.delay)
                        .foregroundColor(context.state.delay.contains("In orario") ? .green : .red)
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(context.attributes.destination)
                            Spacer()
                            Text(context.state.statusMessage).font(.caption).foregroundColor(.gray)
                        }
                        HStack {
                            Image(systemName: "location.fill").foregroundColor(.orange).font(.caption2)
                            Text(context.state.lastStation)
                                .font(.caption2)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                }
            } compactLeading: {
                Image(systemName: "tram.fill").foregroundColor(.orange)
            } compactTrailing: {
                Text(context.state.delay)
                    .foregroundColor(context.state.delay.contains("In orario") ? .green : .red)
            } minimal: {
                Image(systemName: "tram.fill").foregroundColor(.orange)
            }
            .widgetURL(URL(string: "inorario://train/\(context.attributes.trainNumber)"))
        }
    }
}
