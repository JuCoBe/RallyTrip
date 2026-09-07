import XCTest
@testable import RallyCore

final class RegularityEngineTests: XCTestCase {
    func testEightKilometersAt48TakesTenMinutes() throws {
        let engine = try RegularityEngine(segments: [.init(startMeters: 0, speedKPH: 48)])
        let result = engine.evaluate(distance: 8000, elapsed: 601.24)
        XCTAssertEqual(result.targetTime, 600, accuracy: 0.000001)
        XCTAssertEqual(result.deviation, 1.24, accuracy: 0.000001)
    }

    func testPiecewiseTimeAcrossAllFourSegments() throws {
        let engine = try RegularityEngine(segments: RegularitySegment.example)
        let expected = 3420.0 / (48.0 / 3.6) + 3760.0 / (36.0 / 3.6)
            + 5420.0 / (52.0 / 3.6) + 1400.0 / (42.0 / 3.6)
        let result = engine.evaluate(distance: 14000, elapsed: expected - 0.73)
        XCTAssertEqual(result.targetTime, expected, accuracy: 0.000001)
        XCTAssertEqual(result.deviation, -0.73, accuracy: 0.000001)
        XCTAssertEqual(result.targetSpeed, 42)
        XCTAssertNil(result.nextSpeed)
    }

    func testExactBoundaryUsesNewSpeedWithoutRepricingPriorDistance() throws {
        let engine = try RegularityEngine(segments: RegularitySegment.example)
        let result = engine.evaluate(distance: 3420, elapsed: 256.5)
        XCTAssertEqual(result.targetTime, 256.5, accuracy: 0.000001)
        XCTAssertEqual(result.targetSpeed, 36)
        XCTAssertEqual(result.nextSpeed, 52)
        XCTAssertEqual(result.metersToChange, 3760)
        XCTAssertEqual(result.segmentIndex, 1)
        let before = engine.evaluate(distance: 3419.999, elapsed: 0)
        XCTAssertEqual(before.targetSpeed, 48)
        XCTAssertEqual(before.metersToChange!, 0.001, accuracy: 0.000001)
    }

    func testInvalidPlansAreRejected() {
        let invalid: [[RegularitySegment]] = [
            [], [.init(startMeters: 10, speedKPH: 48)],
            [.init(startMeters: 0, speedKPH: 0)],
            [.init(startMeters: 0, speedKPH: .infinity)],
            [.init(startMeters: 0, speedKPH: 48), .init(startMeters: 0, speedKPH: 36)],
            [.init(startMeters: 0, speedKPH: 48), .init(startMeters: -1, speedKPH: 36)],
            [.init(startMeters: 0, speedKPH: 48), .init(startMeters: .nan, speedKPH: 36)]
        ]
        for plan in invalid { XCTAssertThrowsError(try RegularityEngine(segments: plan)) }
    }

    func testNegativeDistanceDoesNotCreateNegativeTargetTime() throws {
        let engine = try RegularityEngine(segments: RegularitySegment.example)
        XCTAssertEqual(engine.evaluate(distance: -10, elapsed: 2).targetTime, 0)
    }

    func testCalibrationUsesOfficialOverRawDistance() throws {
        let factor = try CalibrationEngine.factor(officialMeters: 5000, measuredMeters: 4943)
        XCTAssertEqual(factor, 1.0115314586, accuracy: 0.000000001)
        XCTAssertThrowsError(try CalibrationEngine.factor(officialMeters: 0, measuredMeters: 20))
        XCTAssertThrowsError(try CalibrationEngine.factor(officialMeters: 5000, measuredMeters: 0))
        XCTAssertThrowsError(try CalibrationEngine.factor(officialMeters: .infinity, measuredMeters: 10))
        XCTAssertThrowsError(try CalibrationEngine.factor(officialMeters: 5000, measuredMeters: 1))
    }

    func testTripCorrectionsDoNotChangeRawCalibrationOrTrip() {
        var meter = TripMeter()
        meter.add(rawMeters: 100, factor: 1.1)
        meter.correctTotal(by: 10)
        XCTAssertEqual(meter.total, 120, accuracy: 0.000001)
        XCTAssertEqual(meter.trip, 110, accuracy: 0.000001)
        XCTAssertEqual(meter.raw, 100)
        meter.syncTotal(to: 23480)
        meter.resetTrip()
        meter.add(rawMeters: 10, factor: 1.1)
        XCTAssertEqual(meter.total, 23491, accuracy: 0.000001)
        XCTAssertEqual(meter.trip, 11, accuracy: 0.000001)
        XCTAssertEqual(meter.raw, 110)
        meter.correctTotal(by: -100000)
        XCTAssertEqual(meter.total, 0)
        meter.syncTotal(to: .nan)
        XCTAssertEqual(meter.total, 0)
    }

    func testMonotonicClockPausesResumesAndRestarts() {
        var clock = StageClock()
        clock.start(at: 100)
        XCTAssertEqual(clock.elapsed(at: 110), 10)
        clock.pause(at: 115)
        XCTAssertEqual(clock.elapsed(at: 1000), 15)
        clock.resume(at: 1000)
        XCTAssertEqual(clock.elapsed(at: 1002.5), 17.5)
        clock.start(at: 2000)
        XCTAssertEqual(clock.elapsed(at: 2001), 1)
        clock.reset()
        XCTAssertEqual(clock.elapsed(at: 9000), 0)
    }
}
