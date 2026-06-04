
import WidgetKit
import SwiftUI

@main
struct TrainWidgetBundle: WidgetBundle {
    var body: some Widget {
        TrainWidget()
        TrainWidgetControl()
        TrainWidgetLiveActivity()
    }
}
