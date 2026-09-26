import XCTest
@testable import RallyCore

final class WatchProtocolTests: XCTestCase {
    private let time = Date(timeIntervalSince1970: 1_700_000_000)
    private let rideID = UUID()

    private func snapshot(_ state: WatchRideState = .running, stage: Bool = false, calibration: Bool = false) -> WatchSnapshot {
        WatchSnapshot(sessionID: rideID, generatedAt: time, state: state, stageActive: stage,
                      calibrationActive: calibration, totalMeters: 1234, tripMeters: 234,
                      deviationSeconds: stage ? 2.3 : nil, gpsStatus: "GPS verbunden", isDemo: true)
    }
    private func command(_ action: WatchAction, meters: Double = 0, age: Double = 0) -> WatchCommand {
        WatchCommand(sessionID: rideID, sentAt: time.addingTimeInterval(-age), action: action, correctionMeters: meters)
    }

    func testSnapshotRoundTripPreservesDeviationAndDemo() throws {
        let original = snapshot(.running, stage: true)
        let value = try JSONDecoder().decode(WatchSnapshot.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(value.sessionID, rideID)
        XCTAssertEqual(value.deviationSeconds, 2.3)
        XCTAssertEqual(value.totalMeters, 1234)
        XCTAssertTrue(value.isDemo)
        XCTAssertEqual(value.generatedAt, time)
    }

    func testCommandAndReplyRoundTripPreserveIdentity() throws {
        let original = command(.correctTotal, meters: -10)
        let decoded = try JSONDecoder().decode(WatchCommand.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.correctionMeters, -10)
        let reply = WatchReply(commandID: decoded.id, accepted: true, message: "Total korrigiert", snapshot: snapshot())
        let response = try JSONDecoder().decode(WatchReply.self, from: JSONEncoder().encode(reply))
        XCTAssertEqual(response.commandID, original.id)
        XCTAssertTrue(response.accepted)
    }

    func testStartTripOnlyAcceptsReadyWithoutCalibration() {
        let request = command(.startTrip)
        XCTAssertNil(request.rejection(for: snapshot(.ready), at: time))
        for state in [WatchRideState.running, .paused, .scheduled] {
            XCTAssertNotNil(request.rejection(for: snapshot(state), at: time))
        }
        XCTAssertNotNil(request.rejection(for: snapshot(.ready, calibration: true), at: time))
    }

    func testStageStartRejectsPauseScheduleActiveStageAndCalibration() {
        let request = command(.startStage)
        XCTAssertNil(request.rejection(for: snapshot(.ready), at: time))
        XCTAssertNil(request.rejection(for: snapshot(.running), at: time))
        for state in [WatchRideState.paused, .scheduled] {
            XCTAssertNotNil(request.rejection(for: snapshot(state), at: time))
        }
        XCTAssertNotNil(request.rejection(for: snapshot(.running, stage: true), at: time))
        XCTAssertNotNil(request.rejection(for: snapshot(.running, calibration: true), at: time))
    }

    func testCrownAcceptsWholeMeterCorrectionsWithinBounds() {
        for meters in [-100.0, -37, -10, -1, 1, 2, 10, 43, 100] {
            XCTAssertNil(command(.correctTotal, meters: meters).rejection(for: snapshot(), at: time))
        }
        for meters in [0.0, 0.5, -1.5, -101, 101, 1000, .infinity, -.infinity, .nan] {
            XCTAssertNotNil(command(.correctTotal, meters: meters).rejection(for: snapshot(), at: time))
        }
        XCTAssertNotNil(command(.correctTotal, meters: 10).rejection(for: snapshot(.ready), at: time))
        XCTAssertNotNil(command(.correctTotal, meters: 10).rejection(for: snapshot(.running, calibration: true), at: time))
        XCTAssertNil(command(.correctTotal, meters: 10).rejection(for: snapshot(.paused), at: time))
    }

    func testExpiredFutureAndWrongRideCommandsAreRejected() {
        XCTAssertNotNil(command(.correctTotal, meters: 10, age: 5.01).rejection(for: snapshot(), at: time))
        XCTAssertNotNil(command(.correctTotal, meters: 10, age: -2.01).rejection(for: snapshot(), at: time))
        XCTAssertNil(command(.correctTotal, meters: 10, age: 5).rejection(for: snapshot(), at: time))
        var changedRide = snapshot()
        changedRide.sessionID = UUID()
        XCTAssertNotNil(command(.correctTotal, meters: 10).rejection(for: changedRide, at: time))
    }

    func testStaleSnapshotAndUnknownProtocolDisableControl() {
        var value = snapshot()
        XCTAssertTrue(value.isFresh(at: time.addingTimeInterval(3)))
        XCTAssertFalse(value.isFresh(at: time.addingTimeInterval(3.01)))
        XCTAssertFalse(value.isFresh(at: time.addingTimeInterval(-3)))
        value.version = 2
        XCTAssertFalse(value.isFresh(at: time))
        XCTAssertNotNil(command(.correctTotal, meters: 10).rejection(for: value, at: time))
        var request = command(.startTrip)
        request.version = 2
        XCTAssertNotNil(request.rejection(for: snapshot(.ready), at: time))
    }

    func testDuplicateDeliveryDoesNotApplyCorrectionTwice() {
        var receipts = WatchCommandReceipts()
        var meter = TripMeter()
        meter.add(rawMeters: 100, factor: 1)
        let request = command(.correctTotal, meters: -10)
        for _ in 0..<2 {
            if receipts.reply(for: request.id, at: time) == nil {
                XCTAssertNil(request.rejection(for: snapshot(), at: time))
                meter.correctTotal(by: request.correctionMeters)
                receipts.remember(WatchReply(commandID: request.id, accepted: true, message: "OK", snapshot: snapshot()), at: time)
            }
        }
        XCTAssertEqual(meter.total, 90)
        XCTAssertEqual(meter.trip, 100)
        XCTAssertTrue(receipts.reply(for: request.id, at: time)?.accepted == true)
    }

    func testExpiredReceiptCannotReviveAnExpiredCommand() {
        var receipts = WatchCommandReceipts()
        let request = command(.correctTotal, meters: 10)
        receipts.remember(WatchReply(commandID: request.id, accepted: true, message: "OK", snapshot: snapshot()), at: time)
        let later = time.addingTimeInterval(31)
        XCTAssertNil(receipts.reply(for: request.id, at: later))
        XCTAssertNotNil(request.rejection(for: snapshot(), at: later))
    }

    func testMissingGPSDeviationStaysUnavailableOnTheWatch() throws {
        var value = snapshot(.running, stage: true)
        value.deviationSeconds = nil
        value.gpsStatus = "GPS prüfen"
        let received = try JSONDecoder().decode(WatchSnapshot.self, from: JSONEncoder().encode(value))
        XCTAssertNil(received.deviationSeconds)
        XCTAssertEqual(received.gpsStatus, "GPS prüfen")
    }
}
