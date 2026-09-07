import Foundation

public struct RegularitySegment: Codable, Identifiable, Equatable {
    public var id: UUID
    public var startMeters: Double
    public var speedKPH: Double

    public init(id: UUID = UUID(), startMeters: Double, speedKPH: Double) {
        self.id = id
        self.startMeters = startMeters
        self.speedKPH = speedKPH
    }

    public static let example: [Self] = [
        .init(startMeters: 0, speedKPH: 48),
        .init(startMeters: 3420, speedKPH: 36),
        .init(startMeters: 7180, speedKPH: 52),
        .init(startMeters: 12600, speedKPH: 42)
    ]
}

public struct GPSPoint: Codable, Equatable {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double
    public var speedMPS: Double
    public var course: Double
    public var accuracy: Double
    public var timestamp: Date

    public init(latitude: Double, longitude: Double, altitude: Double = 0,
                speedMPS: Double, course: Double = 0, accuracy: Double, timestamp: Date = Date()) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speedMPS = speedMPS
        self.course = course
        self.accuracy = accuracy
        self.timestamp = timestamp
    }

    public func distance(to other: Self) -> Double {
        let rad = Double.pi / 180
        let dLat = (other.latitude - latitude) * rad
        let dLon = (other.longitude - longitude) * rad
        let a = pow(sin(dLat / 2), 2)
            + cos(latitude * rad) * cos(other.latitude * rad) * pow(sin(dLon / 2), 2)
        return 6_371_000 * 2 * asin(sqrt(min(1, max(0, a))))
    }
}

public struct CalibrationProfile: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var name: String
    public var factor: Double
    public init(name: String, factor: Double = 1) { self.name = name; self.factor = factor }
}

public struct RoadbookPoint: Codable, Identifiable {
    public var id = UUID()
    public var meters: Double
    public var instruction: String
    public var symbol: String
    public init(meters: Double, instruction: String, symbol: String = "arrow.up") {
        self.meters = meters; self.instruction = instruction; self.symbol = symbol
    }
}

public struct SavedRide: Codable, Identifiable {
    public var id = UUID()
    public var name: String
    public var startedAt: Date
    public var elapsed: Double
    public var totalMeters: Double
    public var rawMeters: Double
    public var calibrationFactor: Double
    public var segments: [RegularitySegment]
    // Separate paths preserve pauses and GPS gaps without drawing connecting lines.
    public var paths: [[GPSPoint]]
    public var isDemo: Bool
    public var finalDeviation: Double?

    public init(name: String, startedAt: Date, elapsed: Double, totalMeters: Double,
                rawMeters: Double, calibrationFactor: Double, segments: [RegularitySegment],
                paths: [[GPSPoint]], isDemo: Bool, finalDeviation: Double?) {
        self.name = name; self.startedAt = startedAt; self.elapsed = elapsed
        self.totalMeters = totalMeters; self.rawMeters = rawMeters
        self.calibrationFactor = calibrationFactor; self.segments = segments
        self.paths = paths; self.isDemo = isDemo; self.finalDeviation = finalDeviation
    }
}
