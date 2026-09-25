import Foundation
import WatchConnectivity

@MainActor
final class PhoneWatchBridge: NSObject, WCSessionDelegate {
    var snapshot: (() -> WatchSnapshot)?
    var refresh: (() -> Void)?
    var perform: ((WatchCommand) -> WatchReply)?
    private var lastContextUpdate = Date.distantPast

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func publish(force: Bool = false) {
        guard WCSession.isSupported() else { return }
        let connection = WCSession.default
        guard connection.activationState == .activated, connection.isPaired, connection.isWatchAppInstalled,
              force || Date().timeIntervalSince(lastContextUpdate) >= 5,
              let snapshot = snapshot?(), let data = try? JSONEncoder().encode(snapshot) else { return }
        do {
            try connection.updateApplicationContext(["snapshot": data])
            lastContextUpdate = Date()
        } catch {
            // This cache is optional. The watch obtains fresh state through request/reply.
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor [weak self] in self?.publish(force: true) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.publish(force: true) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        let commandData = message["command"] as? Data
        let requestsState = message["requestState"] as? Bool == true
        Task { @MainActor [weak self] in
            guard let self else { replyHandler(["error": "iPhone-App nicht bereit."]); return }
            if let commandData, let command = try? JSONDecoder().decode(WatchCommand.self, from: commandData),
               let reply = self.perform?(command), let data = try? JSONEncoder().encode(reply) {
                replyHandler(["reply": data])
                self.publish(force: true)
            } else if requestsState {
                self.refresh?()
                if let snapshot = self.snapshot?(), let data = try? JSONEncoder().encode(snapshot) {
                    replyHandler(["snapshot": data])
                } else { replyHandler(["error": "iPhone-App nicht bereit."]) }
            } else {
                replyHandler(["error": "Nachricht nicht unterstützt. Bitte beide Apps aktualisieren."])
            }
        }
    }
}
