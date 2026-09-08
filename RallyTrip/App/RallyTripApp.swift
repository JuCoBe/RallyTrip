import SwiftUI

@main
struct RallyTripApp: App {
    @StateObject private var session = RallySession()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            launchView
                .environmentObject(session)
                .tint(session.data.settings.theme == "Nacht" ? .orange :
                      session.data.settings.theme == "Hell" ? Color(red: 0.27, green: 0.38, blue: 0.03) : RallyStyle.lime)
                .preferredColorScheme(session.data.settings.theme == "Hell" ? .light : .dark)
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

    @ViewBuilder
    private var launchView: some View {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["RALLYTRIP_SCREENSHOT"] {
        case "tripmaster": NavigationStack { TripmasterView() }
        case "regularity": NavigationStack { RegularityView() }
        case "calibration": NavigationStack { CalibrationView() }
        case "settings": NavigationStack { SettingsView() }
        default: HomeView()
        }
        #else
        HomeView()
        #endif
    }
}
