import SwiftUI
import Combine
import WatchConnectivity
import WatchKit

@MainActor
final class WatchConnection: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: WatchSnapshot?
    @Published private(set) var reachable = false
    @Published private(set) var pendingCommand: UUID?
    @Published private(set) var lastReply: WatchReply?
    @Published private(set) var feedback: String?
    @Published private(set) var now = Date()
    private var active = false
    private var pollID: UUID?
    private var timer: AnyCancellable?

    var fresh: Bool { active && snapshot?.isFresh(at: now) == true }
    var canSend: Bool { active && reachable && fresh && pendingCommand == nil }

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func setActive(_ value: Bool) {
        active = value
        timer?.cancel(); timer = nil
        now = Date()
        guard value else { return }
        refresh()
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.now = Date()
            self?.refresh()
        }
    }

    func refresh() {
        let session = WCSession.default
        reachable = session.activationState == .activated && session.isReachable
        guard active, reachable, pollID == nil, pendingCommand == nil else { return }
        let id = UUID()
        pollID = id
        session.sendMessage(["requestState": true], replyHandler: { [weak self] response in
            let data = response["snapshot"] as? Data
            let error = response["error"] as? String
            Task { @MainActor in
                guard let self, self.pollID == id else { return }
                self.pollID = nil
                if let data { self.receive(data) }
                else { self.feedback = error ?? "iPhone-Daten nicht lesbar." }
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in
                guard let self, self.pollID == id else { return }
                self.pollID = nil
                self.reachable = false
            }
        })
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, self.pollID == id else { return }
            self.pollID = nil
        }
    }

    @discardableResult
    func send(_ action: WatchAction, correction: Double = 0) -> UUID? {
        now = Date()
        reachable = WCSession.default.activationState == .activated && WCSession.default.isReachable
        guard canSend, let snapshot else { feedback = "Bitte zuerst mit dem iPhone verbinden."; return nil }
        let command = WatchCommand(sessionID: snapshot.sessionID, action: action, correctionMeters: correction)
        if let error = command.rejection(for: snapshot) { feedback = error; return nil }
        guard let data = try? JSONEncoder().encode(command) else { return nil }
        pendingCommand = command.id
        feedback = nil
        WCSession.default.sendMessage(["command": data], replyHandler: { [weak self] response in
            let replyData = response["reply"] as? Data
            let error = response["error"] as? String
            Task { @MainActor in
                guard let self, self.pendingCommand == command.id else { return }
                self.pendingCommand = nil
                if let replyData, let reply = try? JSONDecoder().decode(WatchReply.self, from: replyData), reply.commandID == command.id {
                    self.accept(reply.snapshot)
                    self.lastReply = reply
                    self.feedback = reply.message
                    WKInterfaceDevice.current().play(reply.accepted ? .click : .failure)
                } else {
                    self.feedback = error ?? "Bestätigung unklar. Bitte auf dem iPhone prüfen."
                }
                self.refresh()
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in self?.unconfirmed(command.id) }
        })
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            self?.unconfirmed(command.id)
        }
        return command.id
    }

    private func unconfirmed(_ id: UUID) {
        guard pendingCommand == id else { return }
        pendingCommand = nil
        feedback = "Keine Bestätigung. Vor erneutem Tippen auf dem iPhone prüfen."
        WKInterfaceDevice.current().play(.failure)
        // Never queue or automatically resend a start/correction.
        refresh()
    }

    private func receive(_ data: Data) {
        guard let value = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        accept(value)
    }

    private func accept(_ value: WatchSnapshot) {
        guard value.version == 1 else { feedback = "Bitte beide Apps aktualisieren."; return }
        if let current = snapshot, value.generatedAt < current.generatedAt { return }
        snapshot = value
        now = Date()
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let data = session.receivedApplicationContext["snapshot"] as? Data
        Task { @MainActor [weak self] in
            if let data { self?.receive(data) }
            self?.refresh()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.refresh() }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext["snapshot"] as? Data
        Task { @MainActor [weak self] in if let data { self?.receive(data) } }
    }
}
