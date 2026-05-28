import AppIntents
import SwiftUI
import WidgetKit

struct TrainWidgetControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(
            kind: "carlo.InOrario.TrainWidgetControl"
        ) {
            ControlWidgetButton(action: OpenSearchIntent()) {
                Label("Cerca Treno", systemImage: "magnifyingglass")
            }
        }
        .displayName("Cerca Treno")
        .description("Apri rapidamente la ricerca treni.")
    }
}

struct OpenSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Cerca Treno"
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // This intent will just launch the app since openAppWhenRun is true.
        // You can handle deep linking in the app's `onOpenURL` to open the search directly.
        return .result()
    }
}
