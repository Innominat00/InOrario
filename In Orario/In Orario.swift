
import SwiftUI
import BackgroundTasks

@main
struct InOrario: App {
    @StateObject private var manager = TrainManager()
    @StateObject private var metroCache = MetroCache()
    @StateObject private var locationManager = LocationManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(manager)
                .environmentObject(metroCache)
                .environmentObject(locationManager)
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                scheduleAppRefresh()
            }
        }
        .backgroundTask(.appRefresh("com.carlo.InOrario.refresh")) {
            await manager.backgroundLiveActivityUpdate()
        }
    }
    
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.carlo.InOrario.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 10 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Impossibile schedulare l'aggiornamento in background: \(error)")
        }
    }
}

