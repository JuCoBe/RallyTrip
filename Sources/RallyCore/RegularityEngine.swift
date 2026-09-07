import Foundation

public enum RallyError: LocalizedError {
    case invalidSegments, invalidCalibration
    public var errorDescription: String? {
        switch self {
        case .invalidSegments:
            return "Der erste Schnitt muss bei 0 km beginnen. Kilometer müssen eindeutig und aufsteigend sein, Geschwindigkeiten zwischen 1 und 200 km/h liegen."
        case .invalidCalibration:
            return "Bitte positive Strecken eingeben. Der Kalibrierfaktor muss zwischen 0,5 und 2,0 liegen."
        }
    }
}

public struct RegularityResult {
    public let targetTime: Double
    public let deviation: Double
    public let targetSpeed: Double
    public let nextSpeed: Double?
    public let metersToChange: Double?
    public let segmentIndex: Int
}

public struct RegularityEngine {
    public let segments: [RegularitySegment]

    public init(segments: [RegularitySegment]) throws {
        guard !segments.isEmpty, segments[0].startMeters == 0 else { throw RallyError.invalidSegments }
        for (index, segment) in segments.enumerated() {
            guard segment.startMeters.isFinite, segment.speedKPH.isFinite,
                  segment.startMeters >= 0, (1...200).contains(segment.speedKPH),
                  index == 0 || segment.startMeters > segments[index - 1].startMeters
            else { throw RallyError.invalidSegments }
        }
        self.segments = segments
    }

    public func evaluate(distance: Double, elapsed: Double) -> RegularityResult {
        let meters = distance.isFinite ? max(0, distance) : 0
        var target = 0.0
        var current = 0
        for index in segments.indices {
            let segment = segments[index]
            guard meters >= segment.startMeters else { break }
            current = index
            let end = index + 1 < segments.count ? segments[index + 1].startMeters : meters
            target += max(0, min(meters, end) - segment.startMeters) / (segment.speedKPH / 3.6)
        }
        let next = current + 1 < segments.count ? segments[current + 1] : nil
        return RegularityResult(targetTime: target, deviation: max(0, elapsed) - target,
                                targetSpeed: segments[current].speedKPH,
                                nextSpeed: next?.speedKPH,
                                metersToChange: next.map { $0.startMeters - meters },
                                segmentIndex: current)
    }
}

public enum CalibrationEngine {
    public static func factor(officialMeters: Double, measuredMeters: Double) throws -> Double {
        guard officialMeters.isFinite, measuredMeters.isFinite,
              officialMeters > 0, measuredMeters > 0 else { throw RallyError.invalidCalibration }
        let value = officialMeters / measuredMeters
        guard (0.5...2).contains(value) else { throw RallyError.invalidCalibration }
        return value
    }
}

/// Injectable monotonic seconds; independent of wall-clock adjustments.
public struct StageClock {
    private var origin: Double?
    private var accumulated = 0.0
    public init() {}
    public mutating func start(at now: Double) { origin = now; accumulated = 0 }
    public mutating func pause(at now: Double) {
        accumulated = elapsed(at: now); origin = nil
    }
    public mutating func resume(at now: Double) { origin = now }
    public mutating func reset() { origin = nil; accumulated = 0 }
    public func elapsed(at now: Double) -> Double {
        accumulated + (origin.map { max(0, now - $0) } ?? 0)
    }
}
