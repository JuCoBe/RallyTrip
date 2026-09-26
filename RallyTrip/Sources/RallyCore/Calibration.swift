import Foundation

public struct CalibrationMeasurement: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var officialMeters: Double
    public var rawMeters: Double
    public var included = true
    public var date = Date()
    public var isDemo: Bool
    public init(officialMeters: Double, rawMeters: Double, isDemo: Bool = false) {
        self.officialMeters = officialMeters; self.rawMeters = rawMeters; self.isDemo = isDemo
    }
}

public struct CalibrationRecord: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var date = Date()
    public var previousFactor: Double
    public var factor: Double
    public var method: String
    public var measurements: [CalibrationMeasurement]
    public init(previousFactor: Double, factor: Double, method: String,
                measurements: [CalibrationMeasurement] = []) {
        self.previousFactor = previousFactor; self.factor = factor
        self.method = method; self.measurements = measurements
    }
}

public struct CalibrationSummary {
    public let factor: Double
    public let officialMeters: Double
    public let rawMeters: Double
    public let count: Int
    /// Range between the smallest and largest individual factors, relative to the combined factor.
    public let spreadPercent: Double
    public var containsShortMeasurement: Bool
}

extension CalibrationEngine {
    public static func validateFactor(_ value: Double) throws -> Double {
        guard value.isFinite, (0.5...2).contains(value) else { throw RallyError.invalidCalibration }
        return value
    }

    /// A displayed distance has already had its old factor applied. Convert back to raw first.
    public static func rawDistance(displayedMeters: Double, appliedFactor: Double) throws -> Double {
        _ = try validateFactor(appliedFactor)
        guard displayedMeters.isFinite, displayedMeters > 0 else { throw RallyError.invalidCalibration }
        let raw = displayedMeters / appliedFactor
        guard raw.isFinite, raw > 0 else { throw RallyError.invalidCalibration }
        return raw
    }

    /// Weight by measured distance: sum(official) / sum(raw), never a mean of factors.
    public static func summarize(_ measurements: [CalibrationMeasurement]) throws -> CalibrationSummary {
        let included = measurements.filter(\.included)
        guard !included.isEmpty else { throw RallyError.invalidCalibration }
        guard Set(included.map(\.isDemo)).count == 1 else { throw CalibrationIssue.mixedSources }
        var factors: [Double] = []
        for measurement in included {
            factors.append(try factor(officialMeters: measurement.officialMeters, measuredMeters: measurement.rawMeters))
        }
        let official = included.reduce(0) { $0 + $1.officialMeters }
        let raw = included.reduce(0) { $0 + $1.rawMeters }
        let combined = try factor(officialMeters: official, measuredMeters: raw)
        return CalibrationSummary(factor: combined, officialMeters: official, rawMeters: raw,
                                  count: included.count,
                                  spreadPercent: ((factors.max() ?? combined) - (factors.min() ?? combined)) / combined * 100,
                                  containsShortMeasurement: included.contains { $0.officialMeters < 1000 })
    }
}

public enum CalibrationIssue: LocalizedError {
    case mixedSources, interrupted, noMeasurement, busy, emptyName
    public var errorDescription: String? {
        switch self {
        case .mixedSources: return "Demo- und echte GPS-Messungen können nicht gemeinsam ausgewertet werden."
        case .interrupted: return "Diese Messung enthält eine Pause oder GPS-Lücke. Bitte die Kalibrierstrecke erneut ohne Unterbrechung messen."
        case .noMeasurement: return "Es liegt noch keine positive GPS-Strecke vor."
        case .busy: return "Beende zuerst die Fahrt. Während einer Fahrt bleiben Profil und Faktor unverändert."
        case .emptyName: return "Bitte einen Profilnamen eingeben."
        }
    }
}

public struct CalibrationCapture {
    public let officialMeters: Double
    public let rawStart: Double
    public let isDemo: Bool
    public private(set) var interrupted = false
    public private(set) var hasFix = false
    public init(officialMeters: Double, rawStart: Double, isDemo: Bool) throws {
        guard officialMeters.isFinite, officialMeters > 0, rawStart.isFinite, rawStart >= 0
        else { throw RallyError.invalidCalibration }
        self.officialMeters = officialMeters; self.rawStart = rawStart; self.isDemo = isDemo
    }
    public mutating func markInterrupted() { interrupted = true }
    public mutating func acceptedFix(newPath: Bool) {
        if hasFix && newPath { interrupted = true }
        hasFix = true
    }
    public func finish(rawTotal: Double) throws -> CalibrationMeasurement {
        guard !interrupted else { throw CalibrationIssue.interrupted }
        guard hasFix, rawTotal.isFinite, rawTotal > rawStart else { throw CalibrationIssue.noMeasurement }
        _ = try CalibrationEngine.factor(officialMeters: officialMeters, measuredMeters: rawTotal - rawStart)
        return CalibrationMeasurement(officialMeters: officialMeters, rawMeters: rawTotal - rawStart, isDemo: isDemo)
    }
}
