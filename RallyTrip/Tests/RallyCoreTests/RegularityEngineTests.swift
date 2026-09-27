import XCTest
@testable import RallyCore

final class RegularityEngineTests: XCTestCase {
    func testAudioCadenceFollowsMagnitudeAndLEDDeadband() {
        var audio = RallyAudioFeedback()
        XCTAssertNil(audio.update(now: 0, mode: .regularity, enabled: true, deviation: 0.5))
        XCTAssertEqual(audio.update(now: 0, mode: .regularity, enabled: true, deviation: 1), .beep(late: true))
        XCTAssertNil(audio.update(now: 1.4, mode: .regularity, enabled: true, deviation: 1))
        XCTAssertEqual(audio.update(now: 1.5, mode: .regularity, enabled: true, deviation: 1), .beep(late: true))
        XCTAssertEqual(audio.update(now: 2, mode: .regularity, enabled: true, deviation: 3), .beep(late: true))
        XCTAssertNil(audio.update(now: 2.1, mode: .regularity, enabled: true, deviation: -10))
        XCTAssertEqual(audio.update(now: 2.21, mode: .regularity, enabled: true, deviation: -10), .beep(late: false))
        XCTAssertEqual(RallyAudioFeedback.interval(deviation: 1), 1.5)
        XCTAssertEqual(RallyAudioFeedback.interval(deviation: 3), 0.5)
        XCTAssertEqual(RallyAudioFeedback.interval(deviation: 100), 0.2)
        XCTAssertEqual(RallyAudioFeedback.interval(deviation: -100), 0.2)
        XCTAssertNil(audio.update(now: 3, mode: .regularity, enabled: true, deviation: -0.5))
    }

    func testAudioSilencesOnDisableMissingGPSAndNonfiniteDeviation() {
        var audio = RallyAudioFeedback()
        XCTAssertNil(audio.update(now: 0, mode: .circuit, enabled: false, deviation: 8, lap: 0, remaining: 3))
        XCTAssertNil(audio.update(now: 1, mode: .regularity, enabled: true, deviation: nil))
        XCTAssertNil(audio.update(now: 2, mode: .regularity, enabled: true, deviation: .nan))
        XCTAssertNil(audio.update(now: 3, mode: .regularity, enabled: true, deviation: .infinity))
        XCTAssertEqual(audio.update(now: 4, mode: .regularity, enabled: true, deviation: -1), .beep(late: false))
        XCTAssertNil(audio.update(now: 4.1, mode: .regularity, enabled: false, deviation: -1))
        XCTAssertEqual(audio.update(now: 4.2, mode: .regularity, enabled: true, deviation: -1), .beep(late: false))
    }

    func testCircuitCountdownSaysEachSecondOnceAndOverridesBeeps() {
        var audio = RallyAudioFeedback()
        XCTAssertEqual(audio.update(now: 7, mode: .circuit, enabled: true, deviation: 10, lap: 0, remaining: 3), .countdown(3))
        XCTAssertNil(audio.update(now: 7.1, mode: .circuit, enabled: true, deviation: 10, lap: 0, remaining: 2.9))
        XCTAssertEqual(audio.update(now: 8, mode: .circuit, enabled: true, deviation: -10, lap: 0, remaining: 2), .countdown(2))
        XCTAssertEqual(audio.update(now: 9, mode: .circuit, enabled: true, deviation: 10, lap: 0, remaining: 1), .countdown(1))
        XCTAssertNil(audio.update(now: 9.9, mode: .circuit, enabled: true, deviation: 10, lap: 0, remaining: 0.1))
        XCTAssertEqual(audio.update(now: 10.2, mode: .circuit, enabled: true, deviation: 10, lap: 0, remaining: -0.2), .beep(late: true))
        XCTAssertEqual(audio.update(now: 17, mode: .circuit, enabled: true, deviation: nil, lap: 10, remaining: 3), .countdown(3))
    }

    func testCountdownSkipsMissedSecondsAndRequiresCircuitLap() {
        var audio = RallyAudioFeedback()
        XCTAssertNil(audio.update(now: 0, mode: .regularity, enabled: true, deviation: nil, lap: 0, remaining: 3))
        XCTAssertNil(audio.update(now: 1, mode: .circuit, enabled: true, deviation: nil, remaining: 3))
        XCTAssertNil(audio.update(now: 2, mode: .circuit, enabled: true, deviation: nil, lap: 0, remaining: nil))
        XCTAssertEqual(audio.update(now: 3, mode: .circuit, enabled: true, deviation: nil, lap: 0, remaining: 1.4), .countdown(2))
        XCTAssertNil(audio.update(now: 4, mode: .circuit, enabled: true, deviation: nil, lap: 0, remaining: -1))
        XCTAssertNil(audio.update(now: 5, mode: .circuit, enabled: true, deviation: nil, lap: 0, remaining: .nan))
        XCTAssertEqual(audio.update(now: 6, mode: .circuit, enabled: true, deviation: nil, lap: 5, remaining: 3), .countdown(3))
    }

    func testAudioPreferencesDefaultsMigrationReversalAndPersistence() throws {
        var settings = try JSONDecoder().decode(RallyAudioPreferences.self, from: Data("{}".utf8))
        XCTAssertTrue(settings.deviationBeeps)
        XCTAssertTrue(settings.finishCountdown)
        XCTAssertTrue(settings.usesHighTone(late: true))
        XCTAssertFalse(settings.usesHighTone(late: false))
        settings.highToneWhenEarly = true
        settings.deviationBeeps = false
        settings.finishCountdown = false
        let restored = try JSONDecoder().decode(RallyAudioPreferences.self, from: JSONEncoder().encode(settings))
        XCTAssertEqual(restored, settings)
        XCTAssertTrue(restored.usesHighTone(late: false))
        XCTAssertFalse(restored.usesHighTone(late: true))
    }

    func testGeneratedTonesHaveDistinctPitchesAndClickFreePCMEnvelope() {
        func samples(_ data: Data) -> [Int16] {
            stride(from: 44, to: data.count, by: 2).map {
                Int16(bitPattern: UInt16(data[$0]) | (UInt16(data[$0 + 1]) << 8))
            }
        }
        let highData = RallyTone.wave(high: true)
        let lowData = RallyTone.wave(high: false)
        XCTAssertEqual(String(data: highData.prefix(4), encoding: .utf8), "RIFF")
        XCTAssertEqual(String(data: highData[8..<12], encoding: .utf8), "WAVE")
        XCTAssertEqual(highData.count, 44 + 3969 * 2)
        XCTAssertEqual(lowData.count, highData.count)
        let high = samples(highData), low = samples(lowData)
        for tone in [high, low] {
            XCTAssertEqual(tone.first, 0)
            XCTAssertEqual(tone.last, 0)
            XCTAssertLessThanOrEqual(tone.map { abs(Int($0)) }.max() ?? 0, 12000)
        }
        func crossings(_ tone: [Int16]) -> Int {
            zip(tone, tone.dropFirst()).filter { $0 <= 0 && $1 > 0 }.count
        }
        XCTAssertEqual(crossings(high), 90)
        XCTAssertEqual(crossings(low), 36)
    }

    func testSharedLEDScalePreservesCircuitThresholdsAndRejectsUnavailableValues() {
        XCTAssertNil(PaceLED.position(deviation: nil))
        XCTAssertNil(PaceLED.position(deviation: .nan))
        XCTAssertNil(PaceLED.position(deviation: .infinity))
        for value in [-0.5, 0, 0.5] { XCTAssertEqual(PaceLED.position(deviation: value), 0) }
        XCTAssertEqual(PaceLED.position(deviation: -0.51), -1)
        XCTAssertEqual(PaceLED.position(deviation: 0.51), 1)
        XCTAssertEqual(PaceLED.position(deviation: -2.1), -3)
        XCTAssertEqual(PaceLED.position(deviation: 2.1), 3)
        XCTAssertEqual(PaceLED.position(deviation: -Double.greatestFiniteMagnitude), -4)
        XCTAssertEqual(PaceLED.position(deviation: Double.greatestFiniteMagnitude), 4)
    }

    func testRegularityMapsElapsedMinusPlanSecondsToSharedLEDs() throws {
        let engine = try RegularityEngine(segments: [.init(startMeters: 0, speedKPH: 36), .init(startMeters: 1000, speedKPH: 72)])
        // 100 seconds for the first km, then 50 seconds for the second km.
        let late = engine.evaluate(distance: 2000, elapsed: 152.1)
        let early = engine.evaluate(distance: 2000, elapsed: 147.9)
        XCTAssertEqual(try XCTUnwrap(PaceLED.regularityDeviation(late, isLive: true)), 2.1, accuracy: 0.0001)
        XCTAssertEqual(PaceLED.position(deviation: PaceLED.regularityDeviation(late, isLive: true)), 3)
        XCTAssertEqual(PaceLED.position(deviation: PaceLED.regularityDeviation(early, isLive: true)), -3)
        XCTAssertNil(PaceLED.regularityDeviation(late, isLive: false), "Pause, missing GPS or no active stage must not light live pace LEDs")
    }

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
