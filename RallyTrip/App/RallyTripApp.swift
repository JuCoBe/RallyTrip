import SwiftUI

@main
struct RallyTripApp: App {
    @StateObject private var session = RallySession()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            launchView
                .environmentObject(session)
                .tint(session.data.settings.theme == "Nacht" ? .orange : RallyStyle.accent)
                .preferredColorScheme(colorScheme)
                .alert("Hinweis", isPresented: Binding(
                    get: { session.errorMessage != nil },
                    set: { if !$0 { session.errorMessage = nil } }
                )) { Button("OK") { session.errorMessage = nil } }
                message: { Text(session.errorMessage ?? "") }
                .onChange(of: phase) { _, phase in
                    if phase != .active { session.checkpoint() }
                    else { session.updateIdleTimer() }
                }
        }
    }

    private var colorScheme: ColorScheme? {
        switch session.data.settings.theme {
        case "Hell": .light
        case "Dunkel", "Nacht": .dark
        default: nil
        }
    }

    @ViewBuilder
    private var launchView: some View {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["RALLYTRIP_SCREENSHOT"] {
        case "tripmaster": HomeView(initialTab: "tripmaster")
        case "regularity": HomeView(initialTab: "regularity")
        case "route": HomeView(initialTab: "route")
        case "calibration": NavigationStack { CalibrationView() }
        case "settings": NavigationStack { SettingsView() }
        default: HomeView()
        }
        #else
        HomeView()
        #endif
    }
}
