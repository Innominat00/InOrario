import Foundation
import ActivityKit

struct TrainLiveActivityAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        var delay: String
        var statusMessage: String
        var lastStation: String
    }

    var trainNumber: String
    var destination: String
    var category: String
}
