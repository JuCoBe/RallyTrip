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

/// Manual start/finish timing. All timestamps must use the same monotonic clock.
public struct CircuitLap: Codable, Identifiable, Equatable {
    public var id: Int { number }
    public let number: Int
    public let seconds: Double
    public let deviation: Double?
}

public struct CircuitTimer {
    public private(set) var laps: [CircuitLap]
    public private(set) var lapStartedAt: Double?
    public var isRunning: Bool { lapStartedAt != nil }
    public var reference: Double? { laps.first?.seconds }

    public init(laps: [CircuitLap] = []) { self.laps = laps }

    public mutating func start(at instant: Double) {
        guard !isRunning, instant.isFinite else { return }
        lapStartedAt = instant
    }

    public func elapsed(at instant: Double) -> Double {
        guard let start = lapStartedAt, instant.isFinite else { return 0 }
        return max(0, instant - start)
    }

    @discardableResult
    public mutating func completeLap(at instant: Double) -> Bool {
        guard isRunning, instant.isFinite else { return false }
        let duration = elapsed(at: instant)
        // Ignore accidental double taps; do not move the start timestamp.
        guard duration >= 1 else { return false }
        let delta = reference.map { duration - $0 }
        laps.append(CircuitLap(number: laps.count + 1, seconds: duration, deviation: delta))
        lapStartedAt = instant
        return true
    }

    /// Keeps completed laps; the incomplete lap is discarded.
    public mutating func stop() { lapStartedAt = nil }
    public mutating func reset() { self = CircuitTimer() }
}

public struct CircuitGate: Codable, Equatable {
    public var latitude: Double
    public var longitude: Double
    /// Direction of travel, clockwise from north.
    public var bearing: Double
    public init(latitude: Double, longitude: Double, bearing: Double) {
        self.latitude = latitude; self.longitude = longitude; self.bearing = bearing
    }
    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite && bearing.isFinite &&
        (-85...85).contains(latitude) && (-180...180).contains(longitude) && (0..<360).contains(bearing)
    }
    public func coordinates(_ point: GPSPoint) -> (along: Double, across: Double) {
        let north = (point.latitude - latitude) * .pi / 180 * 6_371_000
        let east = (point.longitude - longitude) * .pi / 180 * 6_371_000 * cos(latitude * .pi / 180)
        let angle = bearing * .pi / 180
        return (north * cos(angle) + east * sin(angle), east * cos(angle) - north * sin(angle))
    }
}

public struct CircuitTracePoint: Codable {
    public let meters: Double
    public let seconds: Double
}

public struct CircuitGPSArchive: Codable {
    public var gate: CircuitGate?
    public var laps: [CircuitLap]
    public var reference: [CircuitTracePoint]
}

/// A 50 m wide start/finish line perpendicular to the configured travel direction.
public struct GPSCircuitEngine {
    public private(set) var timer = CircuitTimer()
    public private(set) var gate: CircuitGate?
    public private(set) var enabled = false
    public private(set) var deviation: Double?
    public private(set) var lapValid = true
    public private(set) var reference: [CircuitTracePoint] = []
    private var trace: [CircuitTracePoint] = []
    private var distance = 0.0
    private var filter = DistanceEngine()
    private var previous: (point: GPSPoint, instant: Double)?
    private var armed = false
    private var lastCrossing: Double?

    public init(archive: CircuitGPSArchive? = nil) {
        if let archive {
            gate = archive.gate?.isValid == true ? archive.gate : nil
            timer = CircuitTimer(laps: archive.laps)
            reference = archive.reference
        }
    }
    public var archive: CircuitGPSArchive { .init(gate: gate, laps: timer.laps, reference: reference) }
    public mutating func configure(_ gate: CircuitGate) {
        guard !enabled, gate.isValid else { return }
        self = GPSCircuitEngine()
        self.gate = gate
    }
    public mutating func start() {
        guard gate?.isValid == true, !enabled else { return }
        enabled = true; filter.resetAnchor(); previous = nil; armed = false
        lastCrossing = nil; deviation = nil; lapValid = true
    }
    public mutating func stop() {
        enabled = false; timer.stop(); previous = nil; deviation = nil
    }
    public mutating func reset() {
        let savedGate = gate
        self = GPSCircuitEngine()
        gate = savedGate
    }
    public mutating func interrupt() {
        if timer.isRunning { lapValid = false }
        deviation = nil; previous = nil; filter.resetAnchor(); armed = false
    }
    /// Returns true at an accepted crossing. Interpolates time between receiver fixes.
    @discardableResult
    public mutating func ingest(_ point: GPSPoint, at instant: Double, now: Date = Date()) -> Bool {
        guard enabled, let gate, instant.isFinite else { return false }
        guard let sample = filter.ingest(point, now: now) else {
            interrupt(); return false
        }
        let old = previous
        previous = (point, instant)
        if sample.startsNewPath, timer.isRunning { lapValid = false; deviation = nil }
        if let old, instant <= old.instant { interrupt(); return false }
        let position = gate.coordinates(point)
        // Require leaving the line area before any crossing; no start from GPS drift.
        if hypot(position.along, position.across) > 75 { armed = true }
        let oldDistance = distance
        if timer.isRunning { distance += sample.meters }
        if let old, !sample.startsNewPath, armed, point.speedMPS >= 2,
           instant - (lastCrossing ?? -1e10) >= 10 {
            let before = gate.coordinates(old.point)
            if before.along < 0, position.along >= 0 {
                let fraction = -before.along / (position.along - before.along)
                let across = before.across + fraction * (position.across - before.across)
                if abs(across) <= 25 {
                    let crossing = old.instant + fraction * (instant - old.instant)
                    if timer.isRunning {
                        if lapValid {
                            let end = CircuitTracePoint(meters: oldDistance + sample.meters * fraction,
                                                        seconds: timer.elapsed(at: crossing))
                            if timer.reference == nil { reference = trace + [end] }
                            timer.completeLap(at: crossing)
                        } else {
                            // Incomplete GPS laps never become a reference or a result.
                            timer.stop(); timer.start(at: crossing)
                        }
                    } else { timer.start(at: crossing) }
                    distance = sample.meters * (1 - fraction)
                    trace = [.init(meters: 0, seconds: 0)]
                    lapValid = true; armed = false; lastCrossing = crossing; deviation = nil
                    updateTrace(at: instant)
                    return true
                }
            }
        }
        updateTrace(at: instant)
        return false
    }
    private mutating func updateTrace(at instant: Double) {
        guard timer.isRunning, lapValid else { deviation = nil; return }
        let elapsed = timer.elapsed(at: instant)
        if timer.reference == nil {
            // Bound the reference memory footprint while preserving a distance/time profile.
            if trace.count < 20000, distance - (trace.last?.meters ?? -5) >= 5 {
                trace.append(.init(meters: distance, seconds: elapsed))
            }
        }
        guard reference.count >= 2, let last = reference.last, distance <= last.meters else {
            deviation = nil; return
        }
        // Compare times at equal travelled distance, not elapsed time against a whole lap.
        var low = 0, high = reference.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if reference[middle].meters < distance { low = middle } else { high = middle }
        }
        let a = reference[low], b = reference[high]
        guard b.meters > a.meters else { deviation = nil; return }
        let fraction = max(0, min(1, (distance - a.meters) / (b.meters - a.meters)))
        deviation = elapsed - (a.seconds + fraction * (b.seconds - a.seconds))
    }
}
