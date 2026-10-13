import SwiftUI

@main
struct SnapSolveApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var coordinator = CaptureCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(coordinator)
        }
        .onChange(of: scenePhase) { _, phase in
            // iOS erlaubt keine Kameraaufnahmen im Hintergrund – Schleife sauber beenden.
            if phase == .background {
                coordinator.stop()
            }
        }
    }
}
