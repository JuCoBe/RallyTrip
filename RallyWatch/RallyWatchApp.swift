import SwiftUI

@main
struct RallyWatchApp: App {
    @StateObject private var connection = WatchConnection()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            NavigationStack { WatchDashboard() }
                .environmentObject(connection)
                .tint(.green)
                .onAppear { connection.setActive(phase == .active) }
                .onChange(of: phase) { _, value in connection.setActive(value == .active) }
        }
    }
}
