import XCTest
@testable import RallyCore

final class CircuitTimerTests: XCTestCase {
    func testReferenceAndSignedDifferences() throws {
        var timer = CircuitTimer()
        timer.start(at: 10)
        XCTAssertTrue(timer.completeLap(at: 110))
        XCTAssertEqual(timer.reference, 100)
        XCTAssertNil(timer.laps[0].deviation)
        XCTAssertTrue(timer.completeLap(at: 213))
        XCTAssertEqual(timer.laps[1].deviation, 3)
        XCTAssertTrue(timer.completeLap(at: 310))
        XCTAssertEqual(timer.laps[2].deviation, -3)
        XCTAssertEqual(timer.elapsed(at: 312), 2)
    }

    func testDoubleTapInvalidTimeAndRepeatedStartDoNotLoseTime() {
        var timer = CircuitTimer()
        timer.start(at: 10)
        timer.start(at: 15)
        XCTAssertFalse(timer.completeLap(at: .nan))
        XCTAssertFalse(timer.completeLap(at: 9))
        XCTAssertTrue(timer.completeLap(at: 20))
        XCTAssertFalse(timer.completeLap(at: 20.2))
        XCTAssertEqual(timer.elapsed(at: 25), 5)
        XCTAssertEqual(timer.reference, 10)
    }

    func testStopResumeAndSavedLapsPreserveReference() throws {
        var timer = CircuitTimer()
        timer.start(at: 0)
        timer.completeLap(at: 60)
        timer.stop()
        XCTAssertFalse(timer.completeLap(at: 120))
        timer.start(at: 500)
        timer.completeLap(at: 562)
        XCTAssertEqual(timer.laps[1].deviation, 2)
        let data = try JSONEncoder().encode(timer.laps)
        var restored = CircuitTimer(laps: try JSONDecoder().decode([CircuitLap].self, from: data))
        XCTAssertFalse(restored.isRunning)
        XCTAssertEqual(restored.reference, 60)
        restored.reset()
        XCTAssertTrue(restored.laps.isEmpty)
        XCTAssertNil(restored.reference)
    }
}
