import SwiftUI
import Combine
import AVFoundation

enum SessionState: String {
    case ready = "BEREIT", scheduled = "START GEPLANT", running = "AUFZEICHNUNG", paused = "PAUSIERT"
}

@MainActor
final class RallySession: ObservableObject {
    @Published var data = StoredData()
    @Published private(set) var meter = TripMeter()
    @Published private(set) var state: SessionState = .ready
    @Published private(set) var elapsed = 0.0
    @Published private(set) var stageElapsed = 0.0
    @Published private(set) var speed = 0.0
    @Published private(set) var accuracy: Double?
    @Published private(set) var gpsStatus = "GPS in Bereitschaft"
    @Published private(set) var fullAccuracy = true
    @Published private(set) var paths: [[GPSPoint]] = []
    @Published private(set) var stageActive = false
    @Published private(set) var stageDistance = 0.0
    @Published private(set) var countdown: Double?
    @Published var isDemo = false
    @Published var stageName = "WP 01"
    @Published var errorMessage: String?
    @Published var notice: String?
    @Published var calibrationMeasurements: [CalibrationMeasurement] = []
    @Published private(set) var calibrationCapture: CalibrationCapture?

    private let location = LocationEngine()
    private let speech = AVSpeechSynthesizer()
    private var filter = DistanceEngine()
    private let monotonic = ContinuousClock()
    private let epoch = ContinuousClock.now
    private var tripClock = StageClock()
    private var stageClock = StageClock()
    private var timer: AnyCancellable?
    private var deadline: Double?
    private var startedAt = Date()
    private var acceptedAfter = Date()
    private var lastGoodFix: Date?
    private var stageOrigin = 0.0
    private var rideFactor = 1.0
    private var rideSegments = RegularitySegment.example
    private var announcements: Set<String> = []
    private var demoLastTick: Double?
    private var demoMeters = 0.0
    private var lastCheckpoint = 0.0
    private var storageReadable = true

    var now: Double {
        let duration = epoch.duration(to: monotonic.now).components
        return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    }
    var busy: Bool { state != .ready }
    var canConfigure: Bool { state == .ready && !stageActive }
    var factor: Double { busy ? rideFactor : data.settings.profile.factor }
    var result: RegularityResult {
        // Validated on editing and loading; keep a safe default for a damaged file.
        let engine = (try? RegularityEngine(segments: stageActive ? rideSegments : data.settings.segments))
            ?? (try! RegularityEngine(segments: RegularitySegment.example))
        return engine.evaluate(distance: stageDistance, elapsed: stageElapsed)
    }
    var nextRoadbook: RoadbookPoint? {
        data.settings.roadbook.sorted { $0.meters < $1.meters }.first { $0.meters > meter.total }
    }

    init() {
        speech.usesApplicationAudioSession = false
        do {
            data = try RallyStore.load()
            _ = try RegularityEngine(segments: data.settings.segments)
            guard !data.settings.profiles.isEmpty,
                  data.settings.profiles.allSatisfy({ $0.factor.isFinite && (0.5...2).contains($0.factor) })
            else { throw RallyError.invalidCalibration }
        } catch {
            // Never overwrite an unreadable archive automatically.
            storageReadable = false
            data = StoredData()
            errorMessage = "Gespeicherte Daten konnten nicht gelesen werden. Die Originaldatei bleibt erhalten. \(error.localizedDescription)"
        }
        location.onPoint = { [weak self] point in self?.receive(point) }
        location.onStatus = { [weak self] message, precise in
            self?.gpsStatus = message; self?.fullAccuracy = precise
        }
        timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            self?.tick()
        }
        recoverCheckpoint()
    }

    func persist() {
        guard storageReadable else {
            errorMessage = "Archiv ist nicht lesbar. Sichere rallytrip.json aus der Dateien-App, bevor du die App-Daten zurücksetzt."
            return
        }
        do { try RallyStore.save(data) }
        catch { errorMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)" }
    }

    func feedback() {
        if data.settings.haptics { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    }

    private func speak(_ message: String) {
        guard data.settings.sound else { return }
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        speech.speak(utterance)
    }

    func startTrip() {
        guard state == .ready else { return }
        meter = TripMeter(); paths = []; filter.resetAnchor()
        elapsed = 0; stageElapsed = 0; stageDistance = 0
        stageClock.reset()
        stageActive = false; deadline = nil; countdown = nil
        speed = 0; accuracy = nil; lastGoodFix = nil
        startedAt = Date(); acceptedAfter = startedAt
        rideFactor = data.settings.profile.factor
        rideSegments = data.settings.segments
        tripClock.start(at: now)
        state = .running
        demoMeters = 0; demoLastTick = now
        gpsStatus = isDemo ? "DEMO · simuliertes GPS" : "GPS wird gesucht"
        if !isDemo { location.start() }
        updateIdleTimer(); feedback()
    }

    func startStage(at date: Date? = nil) {
        guard calibrationCapture == nil else {
            errorMessage = "Beende oder verwirf zuerst die laufende Kalibriermessung."; return
        }
        guard !stageActive, state != .scheduled, state != .paused else { return }
        if state == .ready { startTrip() }
        rideSegments = data.settings.segments
        announcements = []
        if let date, date.timeIntervalSinceNow > 0 {
            deadline = now + date.timeIntervalSinceNow
            countdown = date.timeIntervalSinceNow
            state = .scheduled
            notice = "Für den geplanten Start die App geöffnet lassen."
        } else { beginStage(at: now) }
    }

    private func beginStage(at instant: Double) {
        stageOrigin = meter.total
        stageDistance = 0
        stageClock.start(at: instant)
        stageActive = true; state = .running
        deadline = nil; countdown = nil
        // No GPS chord from before the stage start is charged to the new stage.
        filter.resetAnchor()
        acceptedAfter = Date()
        demoLastTick = now
        feedback(); speak("Start")
    }

    func cancelScheduledStart() {
        guard state == .scheduled else { return }
        deadline = nil; countdown = nil; state = .running
    }

    func pauseOrResume() {
        guard state == .running || state == .paused else { return }
        if state == .running {
            calibrationCapture?.markInterrupted()
            tripClock.pause(at: now)
            // The competition clock continues while distance measurement is paused.
            state = .paused
            location.stop(); speed = 0; accuracy = nil; lastGoodFix = nil
            gpsStatus = "Streckenmessung pausiert"
        } else {
            tripClock.resume(at: now)
            filter.resetAnchor(); acceptedAfter = Date(); demoLastTick = now
            state = .running
            if !isDemo { location.start() }
        }
        updateIdleTimer(); feedback(); checkpoint()
    }

    func resetTrip() { meter.resetTrip(); feedback() }
    func correctTotal(_ delta: Double) {
        meter.correctTotal(by: delta)
        updateStageDistance(); feedback()
    }
    func syncTotal(_ meters: Double) {
        meter.syncTotal(to: meters)
        updateStageDistance(); feedback()
    }
    private func updateStageDistance() {
        if stageActive { stageDistance = max(0, meter.total - stageOrigin) }
    }

    func finish() {
        guard busy else { return }
        tick()
        let ride = snapshot()
        guard storageReadable else { persist(); return }
        // Persist first, so a failed write leaves the active ride available for retry.
        var next = data
        next.rides.insert(ride, at: 0)
        do { try RallyStore.save(next) }
        catch { errorMessage = "Fahrt nicht gespeichert: \(error.localizedDescription)"; return }
        data = next
        calibrationCapture?.markInterrupted()
        location.stop(); tripClock.pause(at: now); stageClock.pause(at: now)
        state = .ready; stageActive = false; deadline = nil; countdown = nil
        speed = 0; gpsStatus = "Fahrt gespeichert"; accuracy = nil
        try? FileManager.default.removeItem(at: checkpointURL)
        updateIdleTimer(); feedback()
        notice = "Fahrt gespeichert. Du findest sie unter Route / Roadbook."
    }

    private func snapshot() -> SavedRide {
        SavedRide(name: stageActive ? stageName : "Ausfahrt", startedAt: startedAt,
                  elapsed: elapsed, totalMeters: meter.total, rawMeters: meter.raw,
                  calibrationFactor: rideFactor, segments: rideSegments,
                  paths: paths, isDemo: isDemo,
                  finalDeviation: stageActive ? result.deviation : nil)
    }

    private var checkpointURL: URL { URL.documentsDirectory.appending(path: "active-ride.json") }
    func checkpoint() {
        guard busy, storageReadable else { return }
        do {
            try JSONEncoder().encode(snapshot()).write(to: checkpointURL,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { errorMessage = "Zwischenspeichern fehlgeschlagen: \(error.localizedDescription)" }
    }
    private func recoverCheckpoint() {
        guard storageReadable, FileManager.default.fileExists(atPath: checkpointURL.path) else { return }
        do {
            var ride = try JSONDecoder().decode(SavedRide.self, from: Data(contentsOf: checkpointURL))
            // A completed save followed by process termination must not produce a duplicate.
            if !data.rides.contains(where: { $0.startedAt == ride.startedAt }) {
                ride.name += " · wiederhergestellt"
                var next = data; next.rides.insert(ride, at: 0)
                try RallyStore.save(next); data = next
                notice = "Die letzte unterbrochene Fahrt wurde bis zum letzten Speicherpunkt wiederhergestellt."
            }
            try FileManager.default.removeItem(at: checkpointURL)
        } catch { errorMessage = "Unterbrochene Fahrt nicht lesbar: \(error.localizedDescription)" }
    }

    private func tick() {
        let instant = now
        if let deadline {
            countdown = max(0, deadline - instant)
            if instant >= deadline { beginStage(at: deadline) }
        }
        elapsed = tripClock.elapsed(at: instant)
        stageElapsed = stageClock.elapsed(at: instant)
        if isDemo, state == .running || state == .scheduled {
            let dt = min(1, max(0, instant - (demoLastTick ?? instant)))
            if dt >= 0.2 {
                demoLastTick = instant
                let kph = (stageActive ? result.targetSpeed : 48) + sin(instant / 5) * 2
                demoMeters += kph / 3.6 * dt
                let phase = demoMeters / 2000
                receive(GPSPoint(latitude: 48.14 + sin(phase) * 0.0179864,
                                 longitude: 11.58 + (1 - cos(phase)) * 0.0269,
                                 speedMPS: kph / 3.6, accuracy: 3))
            }
        }
        if !isDemo, let fix = lastGoodFix, Date().timeIntervalSince(fix) > 5, state != .paused {
            if calibrationCapture?.hasFix == true { calibrationCapture?.markInterrupted() }
            speed = 0; accuracy = nil; gpsStatus = "GPS-Signal verloren · Messung unterbrochen"
        }
        if stageActive, state == .running { announceChange() }
        if busy, instant - lastCheckpoint > 10 {
            lastCheckpoint = instant; checkpoint()
        }
    }

    private func receive(_ point: GPSPoint) {
        // Location callbacks can wake the app when the UI timer is suspended.
        if let deadline, now >= deadline { beginStage(at: deadline) }
        guard state == .running || state == .scheduled,
              point.timestamp >= acceptedAfter else { return }
        guard isDemo || fullAccuracy else {
            if calibrationCapture?.hasFix == true { calibrationCapture?.markInterrupted() }
            speed = 0; accuracy = nil
            gpsStatus = "Genauer Standort erforderlich – keine Streckenmessung"
            return
        }
        guard let sample = filter.ingest(point) else {
            if calibrationCapture?.hasFix == true { calibrationCapture?.markInterrupted() }
            if point.accuracy > 20 {
                accuracy = nil; gpsStatus = "GPS zu ungenau · Messung unterbrochen"
            }
            return
        }
        lastGoodFix = point.timestamp
        calibrationCapture?.acceptedFix(newPath: sample.startsNewPath)
        accuracy = point.accuracy
        gpsStatus = isDemo ? "DEMO · simuliertes GPS" : "GPS verbunden"
        speed = sample.displaySpeedKPH
        meter.add(rawMeters: sample.meters, factor: rideFactor)
        updateStageDistance()
        if sample.startsNewPath || paths.isEmpty { paths.append([]) }
        // Store at receiver cadence, but do not keep thousands of stationary points.
        if sample.meters > 0 || paths[paths.count - 1].isEmpty { paths[paths.count - 1].append(point) }
        elapsed = tripClock.elapsed(at: now)
        stageElapsed = stageClock.elapsed(at: now)
        if stageActive { announceChange() }
        if now - lastCheckpoint > 10 { lastCheckpoint = now; checkpoint() }
    }

    private func announceChange() {
        let value = result
        let changeKey = "segment-\(value.segmentIndex)"
        if value.segmentIndex > 0, !announcements.contains(changeKey) {
            announcements.insert(changeKey)
            speak("Jetzt \(Int(value.targetSpeed))"); feedback()
        }
        guard let remaining = value.metersToChange else { return }
        // On a jump over multiple thresholds, announce only the closest relevant one.
        let thresholds = [50, 100, 200, 300]
        if let threshold = thresholds.first(where: { remaining <= Double($0) }) {
            let key = "\(value.segmentIndex)-\(threshold)"
            if !announcements.contains(key) {
                for crossed in thresholds where crossed >= threshold {
                    announcements.insert("\(value.segmentIndex)-\(crossed)")
                }
                speak("Schnittwechsel in \(threshold) Metern")
            }
        }
    }

    func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = data.settings.keepAwake && busy
    }
    func requestPreciseLocation() { location.requestPreciseLocation() }
    func beginCalibration(officialMeters: Double) {
        guard calibrationCapture == nil, !stageActive, state != .scheduled, state != .paused else { return }
        do {
            _ = try CalibrationCapture(officialMeters: officialMeters, rawStart: 0, isDemo: isDemo)
            if !busy { startTrip() }
            calibrationCapture = try CalibrationCapture(officialMeters: officialMeters, rawStart: meter.raw, isDemo: isDemo)
            filter.resetAnchor(); acceptedAfter = Date(); demoLastTick = now
            feedback()
        } catch { errorMessage = error.localizedDescription }
    }
    func completeCalibration() {
        guard let capture = calibrationCapture else { return }
        do {
            calibrationMeasurements.append(try capture.finish(rawTotal: meter.raw))
            calibrationCapture = nil; feedback()
        } catch { errorMessage = error.localizedDescription }
    }
    func cancelCalibration() { calibrationCapture = nil }

    @discardableResult
    func saveCalibrationProfile(id: UUID?, name: String, factor: Double, method: String,
                                measurements: [CalibrationMeasurement] = []) -> Bool {
        guard !busy, calibrationCapture == nil else { errorMessage = CalibrationIssue.busy.localizedDescription; return false }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { errorMessage = CalibrationIssue.emptyName.localizedDescription; return false }
        do {
            _ = try CalibrationEngine.validateFactor(factor)
            var settings = data.settings
            var profile: CalibrationProfile
            if let id {
                guard let existing = settings.profiles.first(where: { $0.id == id }) else { return false }
                profile = existing
            } else { profile = CalibrationProfile(name: cleanName) }
            let record = CalibrationRecord(previousFactor: profile.factor, factor: factor, method: method,
                                           measurements: measurements.filter(\.included))
            profile.name = cleanName; profile.factor = factor
            if method != "Umbenennung" { profile.history = (profile.history ?? []) + [record] }
            if let index = settings.profiles.firstIndex(where: { $0.id == profile.id }) { settings.profiles[index] = profile }
            else { settings.profiles.append(profile) }
            settings.selectedProfile = profile.id
            return saveCalibrationSettings(settings)
        } catch { errorMessage = error.localizedDescription; return false }
    }
    func selectCalibrationProfile(_ id: UUID) {
        guard !busy, calibrationCapture == nil, data.settings.profiles.contains(where: { $0.id == id }) else { return }
        var settings = data.settings; settings.selectedProfile = id
        _ = saveCalibrationSettings(settings)
    }
    @discardableResult
    func deleteCalibrationProfile(_ id: UUID) -> Bool {
        guard !busy, calibrationCapture == nil, data.settings.profiles.count > 1 else { return false }
        var settings = data.settings
        settings.profiles.removeAll { $0.id == id }
        if settings.selectedProfile == id { settings.selectedProfile = settings.profiles.first?.id }
        return saveCalibrationSettings(settings)
    }
    private func saveCalibrationSettings(_ settings: AppSettings) -> Bool {
        guard storageReadable else { persist(); return false }
        var next = data; next.settings = settings
        do { try RallyStore.save(next); data = next; feedback(); return true }
        catch { errorMessage = "Profil nicht gespeichert: \(error.localizedDescription)"; return false }
    }
    func deleteRides(at offsets: IndexSet) {
        guard storageReadable else { persist(); return }
        var next = data
        next.rides.remove(atOffsets: offsets)
        do { try RallyStore.save(next); data = next }
        catch { errorMessage = "Löschen nicht gespeichert: \(error.localizedDescription)" }
    }
}
