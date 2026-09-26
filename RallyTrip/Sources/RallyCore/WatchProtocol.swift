import Foundation

public enum WatchRideState: String, Codable, Sendable {
    case ready, scheduled, running, paused
}

/// Shared wire format. The iPhone remains authoritative for every measurement.
public struct WatchSnapshot: Codable, Sendable {
    public var version = 1
    public var sessionID: UUID
    public var generatedAt: Date
    public var state: WatchRideState
    public var stageActive: Bool
    public var calibrationActive: Bool
    public var totalMeters: Double
    public var tripMeters: Double
    public var deviationSeconds: Double?
    public var countdown: Double?
    public var stageName: String
    public var gpsStatus: String
    public var isDemo: Bool

    public init(sessionID: UUID, generatedAt: Date = Date(), state: WatchRideState,
                stageActive: Bool = false, calibrationActive: Bool = false,
                totalMeters: Double = 0, tripMeters: Double = 0, deviationSeconds: Double? = nil,
                countdown: Double? = nil, stageName: String = "WP 01", gpsStatus: String = "", isDemo: Bool = false) {
        self.sessionID = sessionID; self.generatedAt = generatedAt; self.state = state
        self.stageActive = stageActive; self.calibrationActive = calibrationActive
        self.totalMeters = totalMeters; self.tripMeters = tripMeters; self.deviationSeconds = deviationSeconds
        self.countdown = countdown; self.stageName = stageName; self.gpsStatus = gpsStatus; self.isDemo = isDemo
    }

    public func isFresh(at date: Date = Date()) -> Bool {
        version == 1 && (-2...3).contains(date.timeIntervalSince(generatedAt))
    }
    public var canStartTrip: Bool { state == .ready && !calibrationActive }
    public var canStartStage: Bool {
        (state == .ready || state == .running) && !stageActive && !calibrationActive
    }
    public var canCorrect: Bool { state != .ready && !calibrationActive }
}

public enum WatchAction: String, Codable, Sendable {
    case startTrip, startStage, correctTotal
}

public struct WatchCommand: Codable, Sendable {
    public var version = 1
    public var id: UUID
    public var sessionID: UUID
    public var sentAt: Date
    public var action: WatchAction
    public var correctionMeters: Double

    public init(id: UUID = UUID(), sessionID: UUID, sentAt: Date = Date(), action: WatchAction, correctionMeters: Double = 0) {
        self.id = id; self.sessionID = sessionID; self.sentAt = sentAt
        self.action = action; self.correctionMeters = correctionMeters
    }

    public func rejection(for snapshot: WatchSnapshot, at now: Date = Date()) -> String? {
        guard version == 1, snapshot.version == 1 else { return "Bitte beide Apps aktualisieren." }
        guard (-2...5).contains(now.timeIntervalSince(sentAt)) else { return "Befehl zu alt. Anzeige aktualisieren." }
        guard sessionID == snapshot.sessionID else { return "Die Fahrt hat gewechselt. Anzeige aktualisieren." }
        switch action {
        case .startTrip:
            return snapshot.canStartTrip ? nil : "Fahrt bereits aktiv oder Kalibrierung läuft."
        case .startStage:
            return snapshot.canStartStage ? nil : "WP-Start derzeit nicht möglich. iPhone prüfen."
        case .correctTotal:
            guard correctionMeters.isFinite, correctionMeters != 0,
                  (-100...100).contains(correctionMeters), correctionMeters.rounded() == correctionMeters
            else { return "Korrektur muss zwischen −100 und +100 Metern liegen, in ganzen Metern." }
            return snapshot.canCorrect ? nil : "Korrektur benötigt eine Fahrt ohne laufende Kalibrierung."
        }
    }
}

public struct WatchReply: Codable, Sendable {
    public var commandID: UUID
    public var accepted: Bool
    public var message: String
    public var snapshot: WatchSnapshot

    public init(commandID: UUID, accepted: Bool, message: String, snapshot: WatchSnapshot) {
        self.commandID = commandID; self.accepted = accepted; self.message = message; self.snapshot = snapshot
    }
}

/// Remember outcomes longer than the five-second command validity window.
/// A duplicate delivery gets its original outcome without applying another correction.
public struct WatchCommandReceipts {
    private var replies: [UUID: (receivedAt: Date, reply: WatchReply)] = [:]
    public init() {}

    public mutating func reply(for id: UUID, at now: Date = Date()) -> WatchReply? {
        replies = replies.filter { now.timeIntervalSince($0.value.receivedAt) < 30 }
        return replies[id]?.reply
    }
    public mutating func remember(_ reply: WatchReply, at now: Date = Date()) {
        replies[reply.commandID] = (now, reply)
    }
}
