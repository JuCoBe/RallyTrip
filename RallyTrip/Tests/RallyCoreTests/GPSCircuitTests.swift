import XCTest
@testable import RallyCore

final class GPSCircuitTests: XCTestCase {
    private func recordedEngine() -> GPSCircuitEngine {
        var result = engine()
        for i in -10...63 {
            let time = Double(i + 10)
            let fix = point(Double(i) * 0.1, time: time)
            result.ingest(fix, at: time, now: fix.timestamp)
        }
        result.stop()
        return result
    }

    private func roundTrip(_ engine: GPSCircuitEngine) throws -> GPSCircuitEngine {
        GPSCircuitEngine(archive: try JSONDecoder().decode(CircuitGPSArchive.self,
            from: JSONEncoder().encode(engine.archive)))
    }

    func testLegacyArchiveMigratesUnnamedItemsWithoutChangingMeasurements() throws {
        let original = recordedEngine()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original.archive)) as? [String: Any])
        for key in ["startPoints", "references", "selectedStartPointID", "selectedReferenceID"] { json.removeValue(forKey: key) }
        let archive = try JSONDecoder().decode(CircuitGPSArchive.self, from: JSONSerialization.data(withJSONObject: json))
        let migrated = GPSCircuitEngine(archive: archive)
        XCTAssertEqual(migrated.startPointName, "Startpunkt 1")
        XCTAssertEqual(migrated.referenceName, "Referenzrunde 1")
        XCTAssertEqual(migrated.timer.laps, original.timer.laps)
        XCTAssertEqual(migrated.gate, original.gate)
        XCTAssertEqual(migrated.reference.last?.seconds, original.reference.last?.seconds)
        XCTAssertEqual(migrated.reference.count, original.reference.count)
        let restored = try roundTrip(migrated)
        XCTAssertEqual(restored.references.count, 1)
        XCTAssertEqual(restored.startPoints.count, 1)
        XCTAssertEqual(restored.selectedReferenceID, migrated.selectedReferenceID)
        XCTAssertEqual(restored.selectedStartPointID, migrated.selectedStartPointID)
        XCTAssertFalse(restored.enabled)
        XCTAssertFalse(restored.timer.isRunning)
    }

    func testNamesSurviveRestartAndRenamingPreservesTimingAndProfile() throws {
        var engine = recordedEngine()
        let gate = try XCTUnwrap(engine.gate)
        let laps = engine.timer.laps
        let profile = engine.reference
        let referenceID = try XCTUnwrap(engine.selectedReferenceID)
        let startID = try XCTUnwrap(engine.selectedStartPointID)
        XCTAssertTrue(engine.saveStartPoint(gate, name: "  Hotel Parkplatz  "))
        XCTAssertTrue(engine.saveReference(name: "Samstag trocken"))
        XCTAssertEqual(engine.startPointName, "Hotel Parkplatz")
        XCTAssertEqual(engine.referenceName, "Samstag trocken")
        XCTAssertEqual(engine.timer.laps, laps)
        XCTAssertEqual(engine.selectedStartPointID, startID)
        XCTAssertEqual(engine.selectedReferenceID, referenceID)
        engine = try roundTrip(engine)
        XCTAssertEqual(engine.startPointName, "Hotel Parkplatz")
        XCTAssertEqual(engine.referenceName, "Samstag trocken")
        engine.start()
        XCTAssertTrue(engine.renameStartPoint(startID, name: "Start WP1"))
        XCTAssertTrue(engine.renameReference(referenceID, name: "WP 3 Training"))
        XCTAssertTrue(engine.enabled)
        XCTAssertEqual(engine.timer.laps, laps)
        XCTAssertEqual(engine.reference.map(\.seconds), profile.map(\.seconds))
        XCTAssertEqual(engine.reference.map(\.meters), profile.map(\.meters))
        let restored = try roundTrip(engine)
        XCTAssertEqual(restored.startPointName, "Start WP1")
        XCTAssertEqual(restored.referenceName, "WP 3 Training")
        XCTAssertEqual(restored.timer.laps, laps)
    }

    func testEmptyNamesUseStableDefaultsAndDoNotCreateDuplicateItems() throws {
        var engine = recordedEngine()
        let gate = try XCTUnwrap(engine.gate)
        XCTAssertTrue(engine.saveStartPoint(gate, name: "Start"))
        XCTAssertTrue(engine.saveReference(name: "Referenz"))
        XCTAssertTrue(engine.saveStartPoint(gate, name: " \n\t "))
        XCTAssertTrue(engine.saveReference(name: " \n\t "))
        let restored = try roundTrip(engine)
        XCTAssertEqual(restored.startPointName, "Startpunkt 1")
        XCTAssertEqual(restored.referenceName, "Referenzrunde 1")
        XCTAssertEqual(restored.startPoints.count, 1)
        XCTAssertEqual(restored.references.count, 1)
    }

    func testSelectionRestoresMatchingGateAndProfileAndResetOnlyDeletesActiveReference() throws {
        var engine = recordedEngine()
        let originalGate = try XCTUnwrap(engine.gate)
        let originalTime = engine.timer.reference
        let referenceID = try XCTUnwrap(engine.selectedReferenceID)
        XCTAssertTrue(engine.saveStartPoint(originalGate, name: "Start A"))
        XCTAssertTrue(engine.saveReference(name: "Runde A"))
        XCTAssertTrue(engine.saveStartPoint(.init(latitude: 1, longitude: 2, bearing: 90), name: "Start B"))
        let secondPoint = try XCTUnwrap(engine.selectedStartPointID)
        XCTAssertNil(engine.timer.reference)
        XCTAssertEqual(engine.references.count, 1)
        XCTAssertTrue(engine.selectReference(referenceID))
        XCTAssertEqual(engine.startPointName, "Start A")
        XCTAssertEqual(engine.gate, originalGate)
        XCTAssertEqual(engine.timer.reference, originalTime)
        XCTAssertFalse(engine.reference.isEmpty)
        engine.start()
        XCTAssertFalse(engine.selectStartPoint(secondPoint))
        XCTAssertFalse(engine.selectReference(referenceID))
        XCTAssertFalse(engine.deleteReference(referenceID))
        var sawSlower = false
        for i in -10...126 {
            let time = Double(i + 10) * 1.1
            let fix = point(Double(i) * 0.1, time: time)
            engine.ingest(fix, at: time, now: fix.timestamp)
            if let delta = engine.deviation, delta > 0.5 { sawSlower = true }
        }
        XCTAssertTrue(sawSlower)
        engine.stop()
        XCTAssertTrue(engine.selectStartPoint(secondPoint))
        engine.reset() // No current reference: the saved A reference must survive.
        XCTAssertEqual(engine.references.count, 1)
        XCTAssertTrue(engine.selectReference(referenceID))
        engine.reset()
        XCTAssertTrue(engine.references.isEmpty)
        XCTAssertTrue(engine.timer.laps.isEmpty)
        XCTAssertEqual(engine.startPoints.count, 2)
        XCTAssertEqual(engine.startPointName, "Start A")
        XCTAssertTrue(try roundTrip(engine).references.isEmpty)
    }

    func testDuplicateNamesAreSeparateIdentitiesAndInactiveRenameDoesNotSwitchSelection() throws {
        var engine = recordedEngine()
        let first = try XCTUnwrap(engine.selectedStartPointID)
        XCTAssertTrue(engine.renameStartPoint(first, name: "Start"))
        XCTAssertTrue(engine.saveStartPoint(.init(latitude: 1, longitude: 2, bearing: 90), name: "Start"))
        let second = try XCTUnwrap(engine.selectedStartPointID)
        XCTAssertNotEqual(first, second)
        XCTAssertTrue(engine.renameStartPoint(first, name: "Start alt"))
        XCTAssertEqual(engine.selectedStartPointID, second)
        XCTAssertTrue(engine.selectStartPoint(first))
        XCTAssertEqual(engine.startPointName, "Start alt")
        XCTAssertFalse(engine.renameReference(UUID(), name: "Unbekannt"))
        XCTAssertFalse(engine.selectReference(UUID()))
        XCTAssertEqual(engine.references.count, 1)
    }

    func testNewReferenceKeepsPreviousNamedReferenceAndDeletionIsIsolated() throws {
        var engine = recordedEngine()
        let firstID = try XCTUnwrap(engine.selectedReferenceID)
        XCTAssertTrue(engine.saveReference(name: "Samstag trocken"))
        XCTAssertTrue(engine.prepareNewReference())
        XCTAssertNil(engine.timer.reference)
        XCTAssertEqual(engine.references.count, 1)
        engine.start()
        XCTAssertFalse(engine.prepareNewReference())
        for i in -10...63 {
            let time = Double(i + 10) * 1.1
            let fix = point(Double(i) * 0.1, time: time)
            engine.ingest(fix, at: time, now: fix.timestamp)
        }
        engine.stop()
        let secondID = try XCTUnwrap(engine.selectedReferenceID)
        XCTAssertNotEqual(firstID, secondID)
        XCTAssertEqual(engine.referenceName, "Referenzrunde 2")
        XCTAssertTrue(engine.saveReference(name: "Sonntag nass"))
        engine = try roundTrip(engine)
        XCTAssertEqual(engine.references.count, 2)
        XCTAssertEqual(engine.startPoints.count, 1)
        XCTAssertEqual(engine.referenceName, "Sonntag nass")
        let laps = engine.timer.laps
        XCTAssertTrue(engine.renameReference(firstID, name: "Samstag"))
        XCTAssertEqual(engine.selectedReferenceID, secondID)
        XCTAssertTrue(engine.deleteReference(firstID))
        XCTAssertEqual(engine.timer.laps, laps)
        XCTAssertEqual(engine.referenceName, "Sonntag nass")
        XCTAssertEqual(try roundTrip(engine).references.count, 1)
    }

    func testSavingUnchangedGatePreservesReferenceAndProfile() throws {
        var engine = engine()
        for i in -10...63 {
            let time = Double(i + 10)
            let fix = point(Double(i) * 0.1, time: time)
            engine.ingest(fix, at: time, now: fix.timestamp)
        }
        engine.stop()
        let gate = try XCTUnwrap(engine.gate)
        let laps = engine.timer.laps
        let profileCount = engine.reference.count
        XCTAssertFalse(laps.isEmpty)
        XCTAssertGreaterThan(profileCount, 2)
        engine.configure(gate)
        XCTAssertEqual(engine.timer.laps, laps)
        XCTAssertEqual(engine.reference.count, profileCount)

        let data = try JSONEncoder().encode(engine.archive)
        var restored = GPSCircuitEngine(archive: try JSONDecoder().decode(CircuitGPSArchive.self, from: data))
        XCTAssertEqual(restored.gate, gate)
        XCTAssertEqual(restored.timer.reference, engine.timer.reference)
        XCTAssertEqual(restored.reference.last?.meters, engine.reference.last?.meters)
        XCTAssertEqual(restored.reference.last?.seconds, engine.reference.last?.seconds)
        XCTAssertFalse(restored.timer.isRunning)
        restored.start()
        var sawComparison = false
        for i in -10...40 {
            let time = Double(i + 10) * 1.1
            let fix = point(Double(i) * 0.1, time: time)
            restored.ingest(fix, at: time, now: fix.timestamp)
            if let delta = restored.deviation, delta > 0.5 { sawComparison = true }
        }
        XCTAssertTrue(sawComparison, "Stored GPS profile must drive the LEDs after restarting")
        restored.stop()
        restored.reset()
        XCTAssertEqual(restored.gate, gate)
        XCTAssertNil(restored.timer.reference)
        XCTAssertTrue(restored.reference.isEmpty)
    }

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
