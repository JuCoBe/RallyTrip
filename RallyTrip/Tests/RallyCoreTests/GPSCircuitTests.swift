import XCTest
@testable import RallyCore

final class GPSCircuitTests: XCTestCase {
    private let epoch = Date(timeIntervalSince1970: 1700000000)
    private func point(_ phase: Double, time: Double, speed: Double = 10) -> GPSPoint {
        let scale = 180 / Double.pi / 6_371_000
        return GPSPoint(latitude: 100 * sin(phase) * scale,
                        longitude: 100 * (1 - cos(phase)) * scale,
                        speedMPS: speed, accuracy: 3, timestamp: epoch.addingTimeInterval(time))
    }
    private func engine() -> GPSCircuitEngine {
        var engine = GPSCircuitEngine()
        engine.configure(.init(latitude: 0, longitude: 0, bearing: 0))
        engine.start()
        return engine
    }
    func testCrossingsReferenceAndSlowerLapLED() throws {
        var engine = engine()
        var crossings = 0
        for i in -10...126 {
            let time = i <= 63 ? Double(i + 10) : 73 + Double(i - 63) * 1.1
            let fix = point(Double(i) * 0.1, time: time)
            if engine.ingest(fix, at: time, now: fix.timestamp) { crossings += 1 }
            if i == 100 { XCTAssertGreaterThan(try XCTUnwrap(engine.deviation), 2) }
        }
        XCTAssertEqual(crossings, 3)
        XCTAssertEqual(engine.timer.laps.count, 2)
        XCTAssertEqual(try XCTUnwrap(engine.timer.reference), 62.83, accuracy: 0.05)
        XCTAssertGreaterThan(try XCTUnwrap(engine.timer.laps.last?.deviation), 6)
        let restored = GPSCircuitEngine(archive: try JSONDecoder().decode(CircuitGPSArchive.self,
            from: JSONEncoder().encode(engine.archive)))
        XCTAssertEqual(restored.timer.laps, engine.timer.laps)
        XCTAssertFalse(restored.enabled)
        XCTAssertFalse(restored.timer.isRunning)
        XCTAssertEqual(restored.reference.count, engine.reference.count)
    }
    func testReverseCrossingAndStationaryDriftDoNotStart() {
        var engine = engine()
        for i in stride(from: 10, through: -10, by: -1) {
            let time = Double(10 - i)
            let fix = point(Double(i) * 0.1, time: time)
            engine.ingest(fix, at: time, now: fix.timestamp)
        }
        XCTAssertFalse(engine.timer.isRunning)
        for i in 21...40 {
            let fix = point(i.isMultiple(of: 2) ? 0.01 : -0.01, time: Double(i), speed: 0)
            engine.ingest(fix, at: Double(i), now: fix.timestamp)
        }
        XCTAssertFalse(engine.timer.isRunning)
    }
    func testGapDiscardsLapAndNextCrossingRestartsReference() {
        var engine = engine()
        for i in -10...126 {
            if (20...30).contains(i) { continue }
            let time = Double(i + 10)
            let fix = point(Double(i) * 0.1, time: time)
            engine.ingest(fix, at: time, now: fix.timestamp)
            if i == 32 { XCTAssertFalse(engine.lapValid); XCTAssertNil(engine.deviation) }
            if i == 64 { XCTAssertTrue(engine.timer.laps.isEmpty); XCTAssertTrue(engine.lapValid) }
        }
        XCTAssertEqual(engine.timer.laps.count, 1)
        XCTAssertNotNil(engine.timer.reference)
    }
    func testInaccurateFixCannotTriggerAndGateChangeClearsResults() {
        var engine = engine()
        for i in -10...63 {
            let time = Double(i + 10)
            var fix = point(Double(i) * 0.1, time: time)
            if i == 0 { fix.accuracy = 50 }
            engine.ingest(fix, at: time, now: fix.timestamp)
        }
        XCTAssertTrue(engine.timer.laps.isEmpty)
        engine.stop()
        engine.configure(.init(latitude: 1, longitude: 2, bearing: 90))
        XCTAssertEqual(engine.gate?.latitude, 1)
        XCTAssertNil(engine.timer.reference)
    }
    func testAcceleratedDemoAtTrackLatitudeProducesReferenceAndFasterDelta() throws {
        var engine = GPSCircuitEngine()
        engine.configure(.init(latitude: 50.3356, longitude: 6.9475, bearing: 0))
        engine.start()
        var phase = -Double.pi / 2
        var clock = 0.0
        let scale = 180 / Double.pi / 6_371_000
        var sawFaster = false
        for _ in 0..<160 {
            let speed = engine.timer.reference == nil ? 48.0 : 52.0
            clock += 1 // 0.2 real seconds at 5x playback
            phase += speed / 3.6 / 100
            let fix = GPSPoint(latitude: 50.3356 + 100 * sin(phase) * scale,
                               longitude: 6.9475 + 100 * (1 - cos(phase)) * scale / cos(50.3356 * .pi / 180),
                               speedMPS: speed / 3.6, accuracy: 3, timestamp: epoch.addingTimeInterval(clock))
            engine.ingest(fix, at: clock, now: fix.timestamp)
            if let delta = engine.deviation, delta < -0.5 { sawFaster = true }
        }
        XCTAssertTrue(sawFaster)
        XCTAssertGreaterThanOrEqual(engine.timer.laps.count, 2)
        XCTAssertEqual(try XCTUnwrap(engine.timer.reference), 47.12, accuracy: 0.1)
        XCTAssertLessThan(try XCTUnwrap(engine.timer.laps[1].deviation), -3)
    }

}
