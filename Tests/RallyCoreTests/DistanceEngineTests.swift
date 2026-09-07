import XCTest
@testable import RallyCore

final class DistanceEngineTests: XCTestCase {
    private let time = Date(timeIntervalSince1970: 1_700_000_000)
    private func point(meters: Double, second: Double, speed: Double = 10, accuracy: Double = 3) -> GPSPoint {
        GPSPoint(latitude: meters / 6_371_000 * 180 / .pi, longitude: 0,
                 speedMPS: speed, accuracy: accuracy, timestamp: time.addingTimeInterval(second))
    }

    func testMovingPointsMeasureActualCoordinateDistance() throws {
        var engine = DistanceEngine()
        let first = try XCTUnwrap(engine.ingest(point(meters: 0, second: 0), now: time))
        XCTAssertEqual(first.meters, 0)
        XCTAssertTrue(first.startsNewPath)
        let next = try XCTUnwrap(engine.ingest(point(meters: 10, second: 1), now: time.addingTimeInterval(1)))
        XCTAssertEqual(next.meters, 10, accuracy: 0.001)
        XCTAssertEqual(next.displaySpeedKPH, 36, accuracy: 0.001)
        XCTAssertFalse(next.startsNewPath)
    }

    func testStationaryJitterDoesNotCountAsDriving() throws {
        var engine = DistanceEngine()
        for i in 0..<60 {
            let sample = try XCTUnwrap(engine.ingest(point(meters: Double(i % 3), second: Double(i), speed: 0.2),
                                                    now: time.addingTimeInterval(Double(i))))
            XCTAssertEqual(sample.meters, 0)
            XCTAssertEqual(sample.displaySpeedKPH, 0)
        }
    }

    func testUnknownSpeedDoesNotAccumulateDrift() throws {
        var engine = DistanceEngine()
        _ = engine.ingest(point(meters: 0, second: 0, speed: -1), now: time)
        let next = try XCTUnwrap(engine.ingest(point(meters: 2, second: 1, speed: -1), now: time.addingTimeInterval(1)))
        XCTAssertEqual(next.meters, 0)
    }

    func testBadAccuracyStaleFutureAndOutOfOrderPointsAreRejected() {
        var engine = DistanceEngine()
        XCTAssertNil(engine.ingest(point(meters: 0, second: 0, accuracy: 21), now: time))
        XCTAssertNil(engine.ingest(point(meters: 0, second: 0, accuracy: -1), now: time))
        XCTAssertNil(engine.ingest(point(meters: 0, second: 0), now: time.addingTimeInterval(6)))
        XCTAssertNil(engine.ingest(point(meters: 0, second: 3), now: time))
        _ = engine.ingest(point(meters: 0, second: 2), now: time.addingTimeInterval(2))
        XCTAssertNil(engine.ingest(point(meters: 10, second: 1), now: time.addingTimeInterval(2)))
        XCTAssertNil(engine.ingest(point(meters: 10, second: 2), now: time.addingTimeInterval(2)))
    }

    func testTeleportDoesNotPoisonAnchor() throws {
        var engine = DistanceEngine()
        _ = engine.ingest(point(meters: 0, second: 0), now: time)
        XCTAssertNil(engine.ingest(point(meters: 1000, second: 1), now: time.addingTimeInterval(1)))
        let next = try XCTUnwrap(engine.ingest(point(meters: 20, second: 2), now: time.addingTimeInterval(2)))
        XCTAssertEqual(next.meters, 20, accuracy: 0.001)
    }

    func testLongGapAndResumeNeverBridgeUnmeasuredDistance() throws {
        var engine = DistanceEngine()
        _ = engine.ingest(point(meters: 0, second: 0), now: time)
        let afterGap = try XCTUnwrap(engine.ingest(point(meters: 200, second: 20), now: time.addingTimeInterval(20)))
        XCTAssertEqual(afterGap.meters, 0)
        XCTAssertTrue(afterGap.startsNewPath)
        engine.resetAnchor()
        let resumed = try XCTUnwrap(engine.ingest(point(meters: 1000, second: 21), now: time.addingTimeInterval(21)))
        XCTAssertEqual(resumed.meters, 0)
        XCTAssertTrue(resumed.startsNewPath)
    }

    func testSpeedSmoothingDoesNotAlterDistance() throws {
        var engine = DistanceEngine()
        _ = engine.ingest(point(meters: 0, second: 0), now: time)
        let fast = try XCTUnwrap(engine.ingest(point(meters: 20, second: 1, speed: 20), now: time.addingTimeInterval(1)))
        XCTAssertEqual(fast.meters, 20, accuracy: 0.001)
        XCTAssertLessThan(fast.displaySpeedKPH, 72)
        XCTAssertGreaterThan(fast.displaySpeedKPH, 36)
    }
}
