import SwiftUI

struct RegularityView: View {
    @EnvironmentObject private var session: RallySession
    @AppStorage("regularityFocusMode") private var focusMode = false
    @State private var showSegments = false
    @State private var showSchedule = false
    @State private var startDate = Date().addingTimeInterval(60)
    private var result: RegularityResult { session.result }
    private var hasLivePace: Bool { session.stageActive && session.accuracy != nil && session.state != .paused }
    private var paceStatus: String {
        if !session.stageActive { return "Warte auf Start" }
        if session.state == .paused { return "Streckenmessung pausiert" }
        if session.accuracy == nil { return "GPS prüfen" }
        return abs(result.deviation) <= 0.5 ? "Im Takt" : result.deviation > 0 ? "Zu spät" : "Zu früh"
    }
    private var deltaColor: Color {
        abs(result.deviation) <= 0.5 ? RallyStyle.accent : (result.deviation > 0 ? .primary : .blue)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: focusMode ? 12 : 16) {
                if !focusMode {
                    AdaptiveRow {
                        Eyebrow(text: session.stageName).frame(maxWidth: .infinity, alignment: .leading)
                        Button { showSegments = true } label: {
                            Label("Schnittplan", systemImage: "list.bullet").font(.subheadline).frame(minHeight: 44)
                        }.disabled(session.stageActive || session.state == .scheduled)
                    }
                }
                if let countdown = session.countdown {
                    Panel(accent: true) {
                        VStack(spacing: 12) {
                            Eyebrow(text: "Start in")
                            MeterValue(String(format: "%02d:%02d", Int(ceil(countdown)) / 60, Int(ceil(countdown)) % 60), size: 66)
                            Text("App bis zum Start geöffnet lassen.").font(.caption)
                        }.frame(maxWidth: .infinity)
                    }
                } else {
                    Panel {
                        VStack(spacing: 16) {
                            Eyebrow(text: session.stageActive ? "Zeitabweichung" : "Prüfung bereit")
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                MeterValue(hasLivePace ? RallyFormat.deviation(result.deviation) : "—", size: 66)
                                Text("s").font(.title2)
                            }.foregroundStyle(hasLivePace ? deltaColor : .primary)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(hasLivePace ? "Zeitabweichung \(RallyFormat.deviation(result.deviation)) Sekunden" : "Zeitabweichung nicht verfügbar")
                            Text(paceStatus)
                                .font(.headline)
                                .foregroundStyle(hasLivePace ? deltaColor : .secondary)
                            HStack(spacing: 5) {
                                ForEach(-7...7, id: \.self) { value in
                                    Capsule().fill(barColor(value)).frame(height: value == 0 ? 22 : 12)
                                }
                            }.accessibilityHidden(true)
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                }
                AdaptiveRow {
                    Panel(accent: true) { Instrument(label: "Sollschnitt", value: RallyFormat.decimal(result.targetSpeed, digits: 1), unit: "km/h", size: 38) }
                    Panel { Instrument(label: "Ist · GPS", value: session.accuracy == nil ? "—" : RallyFormat.decimal(session.speed, digits: 1), unit: "km/h", size: 38) }
                }
                if !focusMode {
                    Panel {
                        VStack(alignment: .leading, spacing: 20) {
                            Instrument(label: "Prüfungsdistanz", value: RallyFormat.distance(session.stageDistance), unit: "km", size: 43)
                            Divider()
                            AdaptiveRow {
                                VStack(alignment: .leading, spacing: 7) {
                                    Eyebrow(text: "Istzeit")
                                    Text(RallyFormat.duration(session.stageElapsed))
                                }.frame(maxWidth: .infinity, alignment: .leading)
                                VStack(alignment: .leading, spacing: 7) {
                                    Eyebrow(text: "Sollzeit")
                                    Text(RallyFormat.duration(result.targetTime))
                                }
                            }.font(.system(.title3, design: .monospaced))
                        }
                    }
                }
                if let remaining = result.metersToChange, let next = result.nextSpeed {
                    Panel {
                        AdaptiveRow {
                            Image(systemName: "arrow.triangle.swap").font(.title2)
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(text: "Nächster Schnittwechsel")
                                Text("In \(RallyFormat.decimal(remaining, digits: 0)) m")
                                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                            }
                            Text("\(RallyFormat.decimal(next, digits: 0))").font(.system(.largeTitle, design: .monospaced, weight: .bold))
                            Text("km/h").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if !session.stageActive && session.state != .scheduled {
                    AdaptiveRow {
                        ActionButton(title: "Startzeit", icon: "clock") {
                            startDate = Calendar.current.date(bySetting: .second, value: 0, of: Date().addingTimeInterval(120)) ?? Date().addingTimeInterval(120)
                            showSchedule = true
                        }
                        ActionButton(title: "WP starten", icon: "flag.checkered", prominent: true) { session.startStage() }
                    }.disabled(session.state == .paused || session.calibrationCapture != nil)
                    if session.calibrationCapture != nil {
                        Label("Beende zuerst die laufende Kalibriermessung.", systemImage: "info.circle")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if session.isDemo { DemoSpeedControl() }
                if session.busy { SessionControls() }
                GPSStatus()
                if !focusMode {
                    Text("+ = zu spät · − = zu früh. Die Abweichung hängt von der GPS- und Streckengenauigkeit ab.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.padding(20)
        }.background(RallyStyle.background)
            .navigationTitle("Regularity").navigationBarTitleDisplayMode(.inline)
            .modifier(DrivingFullscreen(enabled: $focusMode))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { focusMode.toggle() } label: {
                        Label("Vollbild", systemImage: "arrow.up.left.and.arrow.down.right")
                            .frame(minHeight: 44)
                    }.accessibilityLabel("Vollbild aktivieren")
                        .accessibilityValue(focusMode ? "Fokus aktiv" : "Alle Details sichtbar")
                }
            }
            .sheet(isPresented: $showSegments) { SegmentEditor() }
            .sheet(isPresented: $showSchedule) {
                NavigationStack {
                    Form {
                        Section("Geplanter Prüfungsstart") {
                            DatePicker("Datum und Uhrzeit", selection: $startDate, in: Date()...,
                                       displayedComponents: [.date, .hourAndMinute])
                            Text("Start erfolgt zur gewählten Minute bei Sekunde 00. Für Sekundenwerte kannst du unten nachstellen.")
                                .font(.caption).foregroundStyle(.secondary)
                            Stepper("Sekunde: \(Calendar.current.component(.second, from: startDate))", value: Binding(
                                get: { Calendar.current.component(.second, from: startDate) },
                                set: { second in
                                    startDate = Calendar.current.date(bySetting: .second, value: second, of: startDate) ?? startDate
                                }), in: 0...59)
                        }
                    }.navigationTitle("Startzeit")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { showSchedule = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Einplanen") { session.startStage(at: startDate); showSchedule = false }
                                    .disabled(startDate <= Date())
                            }
                        }
                }.presentationDetents([.medium, .large])
            }
    }

    private func barColor(_ value: Int) -> Color {
        let position = min(7, max(-7, Int(result.deviation.rounded())))
        return hasLivePace && value == position ? deltaColor : Color.secondary.opacity(0.2)
    }
}

private struct SegmentDraft: Identifiable {
    var id = UUID()
    var km: String
    var speed: String
}

struct SegmentEditor: View {
    @EnvironmentObject private var session: RallySession
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [SegmentDraft] = []
    @State private var name = ""
    @State private var validation: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Wertungsprüfung") { TextField("Name", text: $name) }
                Section {
                    ForEach($rows) { $row in
                        VStack {
                            NumericField(label: "Ab", value: $row.km, unit: "km")
                            NumericField(label: "Sollschnitt", value: $row.speed, unit: "km/h")
                        }
                    }.onDelete { rows.remove(atOffsets: $0) }
                    Button("Schnittwechsel hinzufügen", systemImage: "plus") {
                        rows.append(SegmentDraft(km: "", speed: "48"))
                    }
                } header: { Text("Schnittplan") }
                footer: { Text("Beginne bei 0,000 km. Die Sollzeit wird für jedes Segment separat berechnet und aufsummiert.") }
                if let validation { Text(validation).foregroundStyle(.red) }
            }.navigationTitle("Schnittplan")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Speichern") { save() } }
                }
                .onAppear {
                    name = session.stageName
                    rows = session.data.settings.segments.map {
                        SegmentDraft(km: RallyFormat.distance($0.startMeters), speed: RallyFormat.decimal($0.speedKPH, digits: 2))
                    }
                }
        }
    }

    private func save() {
        var segments: [RegularitySegment] = []
        for row in rows {
            guard let km = RallyFormat.parse(row.km), let speed = RallyFormat.parse(row.speed) else {
                validation = "Bitte alle Kilometer und Geschwindigkeiten als Zahlen eingeben."; return
            }
            segments.append(.init(startMeters: km * 1000, speedKPH: speed))
        }
        do {
            _ = try RegularityEngine(segments: segments)
            session.data.settings.segments = segments
            session.stageName = name.trimmingCharacters(in: .whitespaces).isEmpty ? "WP 01" : name
            session.persist(); dismiss()
        } catch { validation = error.localizedDescription }
    }
}


struct CircuitView: View {
    @EnvironmentObject private var session: RallySession
    @State private var showGate = false
    @State private var confirmStop = false
    @State private var confirmReset = false
    @State private var savedReference = false
    @AppStorage("circuitFocusMode") private var focusMode = false

    private var elapsed: Double { session.circuit.elapsed(at: session.circuitNow) }
    private func lapTime(_ seconds: Double) -> String {
        let centiseconds = Int((max(0, seconds) * 100).rounded(.down))
        return String(format: "%02d:%02d,%02d", centiseconds / 6000, (centiseconds / 100) % 60, centiseconds % 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !focusMode {
                    Toggle("Rundstrecken-Demo", isOn: Binding(get: { session.circuitDemo }, set: { session.setCircuitDemo($0); savedReference = false }))
                        .disabled(session.circuitGPS.enabled)
                    if session.circuitDemo {
                        Panel {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("DEMO · Kreisstrecke 628 m", systemImage: "testtube.2").font(.headline)
                                DemoSpeedControl()
                                Picker("Zeitraffer", selection: $session.circuitDemoRate) {
                                    Text("1×").tag(1.0)
                                    Text("2×").tag(2.0)
                                    Text("5×").tag(5.0)
                                }.pickerStyle(.segmented)
                                Text("Zeitraffer beschleunigt Fahrt und Uhr gemeinsam. Fahre die Referenz z. B. mit 48 km/h, danach mit 44 oder 52 km/h. Start/Ziel wird automatisch überfahren. Demo und echte Runden sind getrennt gespeichert.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Panel(accent: true) {
                    VStack(spacing: 12) {
                        Eyebrow(text: session.circuit.isRunning
                            ? "Runde \(session.circuit.laps.count + 1) · \(session.circuit.reference == nil ? "Referenzrunde" : "Bestätigungsrunde")"
                            : "Rundstrecke · bereit")
                        MeterValue(lapTime(elapsed), size: focusMode ? 80 : 60)
                            .accessibilityLabel("Rundenzeit \(lapTime(elapsed))")
                        if let reference = session.circuit.reference {
                            Text("Referenz: \(lapTime(reference))").monospacedDigit()
                            if session.circuit.isRunning {
                                Text(elapsed <= reference ? "Noch bis zur Referenzzeit" : "Referenzzeit überschritten")
                                    .font(.subheadline)
                                MeterValue(lapTime(abs(reference - elapsed)), size: 36)
                            }
                        } else {
                            Text("Die erste abgeschlossene Runde setzt die Referenz.")
                                .font(.subheadline)
                        }
                    }.frame(maxWidth: .infinity)
                }
                CircuitLEDs(deviation: session.circuitGPS.deviation,
                            status: !session.circuitGPS.lapValid ? "GPS-Lücke · Runde wird verworfen" :
                                session.circuit.reference == nil ? "Referenzrunde aufzeichnen" : "Warte auf gültige GPS-Vergleichsdaten",
                            allowsTest: !session.circuitGPS.enabled)
                Label(session.circuitGPSStatus, systemImage: "location.fill")
                    .font(.subheadline).foregroundStyle(.secondary)
                if session.circuitGPS.enabled {
                    if !session.circuit.isRunning {
                        Text("Bereit: Startlinie in Fahrtrichtung überqueren. Zuvor mindestens 75 m vom Punkt entfernen.")
                            .font(.headline)
                    }
                    Text("Rundenwechsel automatisch per GPS")
                        .font(.subheadline)
                    Button("Messung beenden", role: .destructive) { confirmStop = true }
                        .frame(minHeight: 44)
                } else {
                    if !session.circuitDemo {
                    Button { showGate = true } label: {
                        Label(session.circuitGPS.gate == nil ? "Start/Ziel festlegen" : "Start/Ziel ändern", systemImage: "mappin.and.ellipse")
                    }.frame(minHeight: 44)
                    }
                    if let gate = session.circuitGPS.gate {
                        Text(String(format: "%.6f, %.6f · Richtung %.0f°", gate.latitude, gate.longitude, gate.bearing))
                            .font(.caption).monospacedDigit()
                    }
                    ActionButton(title: "GPS-Rundenerkennung starten", icon: "play.fill", prominent: true) {
                        session.startCircuit()
                    }.disabled(session.circuitGPS.gate == nil)
                }
                if !focusMode, let last = session.circuit.laps.last, let deviation = last.deviation {
                    Panel {
                        VStack(spacing: 8) {
                            Eyebrow(text: "Letzte Runde · \(last.number)")
                            MeterValue(RallyFormat.deviation(deviation), size: 44)
                            Text("Sekunden · \(deviation >= 0 ? "langsamer" : "schneller") als Referenz")
                                .font(.subheadline)
                        }.frame(maxWidth: .infinity)
                    }
                }
                if !focusMode {
                    if session.circuit.reference != nil {
                        Button {
                            savedReference = session.saveCircuit()
                        } label: {
                            Label(savedReference ? "Referenzrunde gespeichert" : "Referenzrunde speichern", systemImage: savedReference ? "checkmark.circle.fill" : "square.and.arrow.down")
                        }.frame(minHeight: 44)
                        Text("Die Referenzzeit und ihr GPS-Vergleichsprofil werden nach Rundenende automatisch gespeichert und beim nächsten Start wiederverwendet.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Die Startlinie ist 50 m breit und liegt quer zur eingestellten Fahrtrichtung. Nach mindestens 75 m Entfernung und 10 Sekunden kann die nächste Überfahrt zählen. Die LED-Abweichung vergleicht Zeiten bei gleicher gefahrener Rundendistanz: Blau = voraus / zu schnell, Orange = zurück / zu langsam, Grün = ±0,5 s.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if !session.circuit.laps.isEmpty {
                        Panel {
                            VStack(alignment: .leading, spacing: 14) {
                                Eyebrow(text: "Abgeschlossene Runden")
                                ForEach(session.circuit.laps.reversed()) { lap in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Runde \(lap.number) · \(lapTime(lap.seconds))")
                                            .font(.headline).monospacedDigit()
                                        Text(lap.deviation.map { "\(RallyFormat.deviation($0)) s · + langsamer / − schneller" } ?? "Referenzrunde")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }.accessibilityElement(children: .combine)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("Abgeschlossene Runden bleiben nach einem App-Neustart erhalten. Eine laufende Runde wird dabei verworfen. Die GPS-Messung ist unabhängig vom Tripmaster und dessen Demo-Modus. GPS-Lücken machen die aktuelle Runde ungültig; an Start/Ziel beginnt eine neue Runde. Keine offizielle Zeitnahme.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !focusMode && !session.circuitGPS.enabled && !session.circuit.laps.isEmpty {
                    Button("Neue Referenz / Runden löschen", role: .destructive) { confirmReset = true }
                        .frame(minHeight: 44)
                }
            }.padding(20)
        }.background(RallyStyle.background)
            .navigationTitle("Rundstrecke").navigationBarTitleDisplayMode(.inline)
            .modifier(DrivingFullscreen(enabled: $focusMode))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { focusMode.toggle() } label: {
                        Label("Vollbild", systemImage: "arrow.up.left.and.arrow.down.right")
                            .frame(minHeight: 44)
                    }.accessibilityLabel("Vollbild aktivieren")
                }
            }
            .onAppear { session.monitorCircuitGPS() }
            .onDisappear { session.stopCircuitPreview() }
            .sheet(isPresented: $showGate, onDismiss: { savedReference = false }) { CircuitGateEditor() }
            .confirmationDialog("Messung beenden? Die laufende, unvollständige Runde wird verworfen.", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("Beenden", role: .destructive) { session.stopCircuit() }
            }
            .confirmationDialog("Alle Runden und die Referenzzeit löschen?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Runden löschen", role: .destructive) { session.resetCircuit(); savedReference = false }
            }
    }
}


private struct CircuitLEDs: View {
    let deviation: Double?
    let status: String
    var allowsTest = false
    @State private var testing = false
    private var selected: Int? {
        guard let deviation, deviation.isFinite else { return nil }
        if abs(deviation) <= 0.5 { return 0 }
        return (deviation < 0 ? -1 : 1) * max(1, Int(min(4, ceil(abs(deviation)))))
    }
    var body: some View {
        VStack(spacing: 16) {
                Text("Tempo gegenüber Referenzrunde").font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(-4...4, id: \.self) { index in
                        let color: Color = index == 0 ? .green : index < 0 ? .cyan : .orange
                        let lit = testing || selected.map { value in
                            value == 0 ? index == 0 : (value < 0 ? (value...(-1)).contains(index) : (1...value).contains(index))
                        } == true
                        Circle()
                            .fill(color.opacity(lit ? 1 : 0.22))
                            .overlay(Circle().stroke(color.opacity(lit ? 1 : 0.6), lineWidth: lit ? 3 : 1))
                            .overlay(Circle().fill(.white.opacity(lit ? 0.8 : 0)).padding(10))
                            .shadow(color: color.opacity(lit ? 0.9 : 0), radius: 10)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }.frame(maxWidth: 660).padding(.vertical, 12).accessibilityHidden(true)
                HStack {
                    Text("← Zu schnell").foregroundStyle(.cyan)
                    Spacer()
                    Text("±0,5 s").foregroundStyle(.green)
                    Spacer()
                    Text("Zu langsam →").foregroundStyle(.orange)
                }.font(.caption.bold())
                if testing {
                    Text("Lampentest · keine Messwerte").font(.headline)
                } else if let deviation, deviation.isFinite {
                    Text(abs(deviation) <= 0.5 ? "Im Takt" : deviation < 0 ? "Zu schnell · voraus" : "Zu langsam · zurück")
                        .font(.headline)
                    MeterValue("\(RallyFormat.deviation(deviation)) s", size: 48)
                } else {
                    Text(status).font(.subheadline)
                    Text("LEDs bereit · noch kein Zeitvergleich").font(.caption)
                }
                if allowsTest {
                    Button(testing ? "Lampentest beenden" : "LED-Lampentest") { testing.toggle() }
                        .buttonStyle(.bordered).tint(.white).frame(minHeight: 44)
                }
        }.padding(20).frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 20))
            .onChange(of: allowsTest) { _, allowed in if !allowed { testing = false } }
    }
}

private struct CircuitGateEditor: View {
    @EnvironmentObject private var session: RallySession
    @Environment(\.dismiss) private var dismiss
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var bearing = ""
    private var gate: CircuitGate? {
        guard let lat = RallyFormat.parse(latitude), let lon = RallyFormat.parse(longitude),
              let direction = RallyFormat.parse(bearing) else { return nil }
        let value = CircuitGate(latitude: lat, longitude: lon, bearing: direction)
        return value.isValid ? value : nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Start-/Zielpunkt") {
                    TextField("Breitengrad (z. B. 50,3356)", text: $latitude)
                    TextField("Längengrad (z. B. 6,9475)", text: $longitude)
                    Button("Aktuelle GPS-Position übernehmen") {
                        guard let fix = session.circuitFix, Date().timeIntervalSince(fix.timestamp) <= 5 else { return }
                        latitude = String(format: "%.7f", fix.latitude)
                        longitude = String(format: "%.7f", fix.longitude)
                        if fix.course >= 0, fix.course < 360, fix.speedMPS >= 2 {
                            bearing = String(format: "%.0f", fix.course.truncatingRemainder(dividingBy: 360))
                        }
                    }.disabled(session.circuitFix == nil)
                    Text(session.circuitGPSStatus).font(.caption)
                }
                Section("Fahrtrichtung über Start/Ziel") {
                    TextField("Richtung in Grad (0–359)", text: $bearing)
                    Text("0° Nord · 90° Ost · 180° Süd · 270° West. Die Richtung verhindert Rundenzählung bei einer Rückwärtsüberfahrt. Beim Übernehmen einer Position in Bewegung wird auch die GPS-Fahrtrichtung übernommen.")
                        .font(.footnote)
                }
                Section {
                    Text("Die Zielkoordinate und Fahrtrichtung bleiben nach einem App-Neustart gespeichert. Nur eine Änderung von Punkt oder Richtung setzt die bisherige Referenz und Rundenliste zurück.")
                        .font(.footnote)
                }
            }.navigationTitle("Start/Ziel")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Zielkoordinate speichern") {
                            if let gate, session.configureCircuit(gate) { dismiss() }
                        }.disabled(gate == nil)
                    }
                }
                .onAppear {
                    if let gate = session.circuitGPS.gate {
                        latitude = String(gate.latitude)
                        longitude = String(gate.longitude)
                        bearing = String(gate.bearing)
                    }
                }
        }
    }
}
