import XCTest
@testable import RallyCore

final class CalibrationTests: XCTestCase {
    func testDifferentLengthRunsUseDistanceWeighting() throws {
        let result = try CalibrationEngine.summarize([
            .init(officialMeters: 1000, rawMeters: 900),
            .init(officialMeters: 9000, rawMeters: 9000)
        ])
        XCTAssertEqual(result.factor, 10000.0 / 9900, accuracy: 1e-12)
        XCTAssertNotEqual(result.factor, (1000.0 / 900 + 1) / 2, accuracy: 1e-6)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.officialMeters, 10000)
        XCTAssertEqual(result.rawMeters, 9900)
    }

    func testExcludedRunCannotInfluenceResultEvenIfInvalid() throws {
        var excluded = CalibrationMeasurement(officialMeters: .nan, rawMeters: 0)
        excluded.included = false
        let result = try CalibrationEngine.summarize([.init(officialMeters: 5000, rawMeters: 4943), excluded])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.factor, 5000.0 / 4943, accuracy: 1e-12)
        XCTAssertEqual(result.spreadPercent, 0)
        XCTAssertThrowsError(try CalibrationEngine.summarize([excluded]))
    }

    func testAlreadyCalibratedDistanceUsesOldFactorExactlyOnce() throws {
        let raw = try CalibrationEngine.rawDistance(displayedMeters: 4950, appliedFactor: 1.1)
        XCTAssertEqual(raw, 4500, accuracy: 1e-9)
        let factor = try CalibrationEngine.factor(officialMeters: 5000, measuredMeters: raw)
        XCTAssertEqual(factor, 1.1 * 5000 / 4950, accuracy: 1e-12)
    }

    func testDirectFactorAndDisplayedDistanceRejectInvalidValues() {
        for value in [Double.nan, .infinity, -.infinity, 0, -1, 0.49, 2.01] {
            XCTAssertThrowsError(try CalibrationEngine.validateFactor(value))
            XCTAssertThrowsError(try CalibrationEngine.rawDistance(displayedMeters: 5000, appliedFactor: value))
        }
        for value in [Double.nan, .infinity, 0, -1] {
            XCTAssertThrowsError(try CalibrationEngine.rawDistance(displayedMeters: value, appliedFactor: 1))
        }
        XCTAssertEqual(try CalibrationEngine.validateFactor(0.5), 0.5)
        XCTAssertEqual(try CalibrationEngine.validateFactor(2), 2)
    }

    func testMixedDemoAndGPSAreRejectedUnlessOneIsExcluded() throws {
        let actual = CalibrationMeasurement(officialMeters: 5000, rawMeters: 4900)
        var demo = CalibrationMeasurement(officialMeters: 5000, rawMeters: 5000, isDemo: true)
        XCTAssertThrowsError(try CalibrationEngine.summarize([actual, demo]))
        demo.included = false
        XCTAssertEqual(try CalibrationEngine.summarize([actual, demo]).count, 1)
    }

    func testSpreadAndShortReferenceHint() throws {
        let result = try CalibrationEngine.summarize([
            .init(officialMeters: 500, rawMeters: 500),
            .init(officialMeters: 510, rawMeters: 500)
        ])
        XCTAssertTrue(result.containsShortMeasurement)
        XCTAssertEqual(result.factor, 1.01, accuracy: 1e-12)
        XCTAssertEqual(result.spreadPercent, 0.02 / 1.01 * 100, accuracy: 1e-10)
    }

    func testCaptureUsesRawDistanceDifferenceAndPreservesDemoFlag() throws {
        var capture = try CalibrationCapture(officialMeters: 5000, rawStart: 1234, isDemo: true)
        capture.acceptedFix(newPath: true)
        capture.acceptedFix(newPath: false)
        let result = try capture.finish(rawTotal: 6177)
        XCTAssertEqual(result.rawMeters, 4943)
        XCTAssertEqual(result.officialMeters, 5000)
        XCTAssertTrue(result.isDemo)
    }

    func testCaptureRejectsNoFixNoDistanceAndMeterReset() throws {
        var capture = try CalibrationCapture(officialMeters: 1000, rawStart: 2000, isDemo: false)
        XCTAssertThrowsError(try capture.finish(rawTotal: 3000))
        capture.acceptedFix(newPath: true)
        XCTAssertThrowsError(try capture.finish(rawTotal: 2000))
        XCTAssertThrowsError(try capture.finish(rawTotal: 1000))
        XCTAssertThrowsError(try capture.finish(rawTotal: .nan))
        XCTAssertThrowsError(try CalibrationCapture(officialMeters: 0, rawStart: 0, isDemo: false))
    }

    func testPauseAndGPSGapInvalidateCapturePermanently() throws {
        var paused = try CalibrationCapture(officialMeters: 1000, rawStart: 0, isDemo: false)
        paused.acceptedFix(newPath: true)
        paused.markInterrupted()
        paused.acceptedFix(newPath: false)
        XCTAssertThrowsError(try paused.finish(rawTotal: 1000))
        var gap = try CalibrationCapture(officialMeters: 1000, rawStart: 0, isDemo: false)
        gap.acceptedFix(newPath: true)
        XCTAssertFalse(gap.interrupted)
        gap.acceptedFix(newPath: true)
        XCTAssertTrue(gap.interrupted)
        XCTAssertThrowsError(try gap.finish(rawTotal: 1000))
    }

    func testOldProfileWithoutHistoryStillDecodes() throws {
        let json = """
        {"id":"D5B875A0-5039-456A-9BF2-35A5AAD214C2","name":"Mein Fahrzeug","factor":1.01153}
        """
        let profile = try JSONDecoder().decode(CalibrationProfile.self, from: Data(json.utf8))
        XCTAssertEqual(profile.name, "Mein Fahrzeug")
        XCTAssertNil(profile.history)
        XCTAssertEqual(profile.factor, 1.01153)
    }

    func testHistoryRoundTripPreservesFactorsAndReferenceMeasurements() throws {
        var profile = CalibrationProfile(name: "Porsche", factor: 1.01)
        profile.history = [.init(previousFactor: 1, factor: 1.01, method: "Referenzmessungen",
                                 measurements: [.init(officialMeters: 5050, rawMeters: 5000)])]
        let decoded = try JSONDecoder().decode(CalibrationProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(decoded, profile)
    }
}
