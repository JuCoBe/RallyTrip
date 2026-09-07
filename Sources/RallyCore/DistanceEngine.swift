import Foundation

public struct DistanceSample {
    public let meters: Double
    public let displaySpeedKPH: Double
    public let startsNewPath: Bool
}

/// Coordinate distance and display smoothing are deliberately independent.
public struct DistanceEngine {
    private var previous: GPSPoint?
    private var speeds: [Double] = []
    private var smoothedSpeed = 0.0
    public init() {}

    public mutating func resetAnchor() {
        previous = nil; speeds = []; smoothedSpeed = 0
    }

    public mutating func ingest(_ point: GPSPoint, now: Date = Date()) -> DistanceSample? {
        guard point.latitude.isFinite, point.longitude.isFinite,
              (-90...90).contains(point.latitude), (-180...180).contains(point.longitude),
              point.accuracy.isFinite, (0...20).contains(point.accuracy),
              point.speedMPS.isFinite, (-1...80).contains(point.speedMPS),
              now.timeIntervalSince(point.timestamp) <= 5,
              now.timeIntervalSince(point.timestamp) >= -1 else { return nil }
        if let previous, point.timestamp <= previous.timestamp { return nil }

        var meters = 0.0
        var newPath = previous == nil
        if let last = previous {
            let dt = point.timestamp.timeIntervalSince(last.timestamp)
            if dt > 5 {
                newPath = true
                speeds = []
                smoothedSpeed = 0
            } else {
                let step = last.distance(to: point)
                // Reject impossible speed and large jumps inconsistent with receiver speed.
                let receiverSpeed = max(max(last.speedMPS, point.speedMPS), 0)
                let plausible = receiverSpeed * dt * 2 + max(10, last.accuracy + point.accuracy)
                guard step / dt <= 80, step <= plausible else { return nil }
                // Unknown or stationary speed must not add position drift.
                if point.speedMPS >= 0.8 { meters = step }
            }
        }
        previous = point
        let speed = point.speedMPS >= 0.8 ? point.speedMPS * 3.6 : 0
        speeds.append(speed)
        if speeds.count > 5 { speeds.removeFirst() }
        let sorted = speeds.sorted()
        let median = sorted[sorted.count / 2]
        smoothedSpeed = speed == 0 ? 0 : (speeds.count == 1 ? speed : smoothedSpeed * 0.65 + median * 0.35)
        return DistanceSample(meters: meters, displaySpeedKPH: smoothedSpeed, startsNewPath: newPath)
    }
}

public struct TripMeter {
    public private(set) var total = 0.0
    public private(set) var trip = 0.0
    public private(set) var raw = 0.0
    public init() {}
    public mutating func add(rawMeters: Double, factor: Double) {
        guard rawMeters.isFinite, rawMeters >= 0, factor.isFinite, factor > 0 else { return }
        raw += rawMeters
        total += rawMeters * factor
        trip += rawMeters * factor
    }
    public mutating func correctTotal(by meters: Double) {
        guard meters.isFinite else { return }
        total = max(0, total + meters)
    }
    public mutating func syncTotal(to meters: Double) {
        guard meters.isFinite, meters >= 0 else { return }
        total = meters
    }
    public mutating func resetTrip() { trip = 0 }
}
