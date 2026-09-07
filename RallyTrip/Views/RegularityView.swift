import SwiftUI

struct RegularityView: View {
    @EnvironmentObject private var session: RallySession
    @State private var showSegments = false
    @State private var showSchedule = false
    @State private var startDate = Date().addingTimeInterval(60)
    private var result: RegularityResult { session.result }
    private var deltaColor: Color {
        abs(result.deviation) <= 0.5 ? .green : (result.deviation > 0 ? .orange : .cyan)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Eyebrow(text: session.stageName.uppercased())
                    Spacer()
                    Button { showSegments = true } label: { Label("Schnittplan", systemImage: "list.bullet") }
                        .font(.subheadline).disabled(session.stageActive || session.state == .scheduled)
                }
                if let countdown = session.countdown {
                    Panel(accent: true) {
                        VStack(spacing: 12) {
                            Eyebrow(text: "START IN")
                            Text(String(format: "%02d:%02d", Int(ceil(countdown)) / 60, Int(ceil(countdown)) % 60))
                                .font(.system(size: 72, weight: .bold, design: .monospaced))
                            Text("App bis zum Start geöffnet lassen.").font(.caption)
                        }.frame(maxWidth: .infinity)
                    }
                } else {
                    Panel {
                        VStack(spacing: 16) {
                            Eyebrow(text: session.stageActive ? "ZEITABWEICHUNG" : "PRÜFUNG BEREIT")
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(session.stageActive ? RallyFormat.deviation(result.deviation) : "±0,00")
                                    .font(.system(size: 76, weight: .semibold, design: .monospaced))
                                    .tracking(-4).minimumScaleFactor(0.3).lineLimit(1)
                                Text("s").font(.title2)
                            }.foregroundStyle(session.stageActive ? deltaColor : .primary)
                            Text(!session.stageActive ? "WARTE AUF START" : abs(result.deviation) <= 0.5 ? "IM TAKT" : result.deviation > 0 ? "ZU SPÄT" : "ZU FRÜH")
                                .font(.system(.caption, design: .monospaced, weight: .bold)).tracking(3)
                                .foregroundStyle(session.stageActive ? deltaColor : .secondary)
                            HStack(spacing: 5) {
                                ForEach(-7...7, id: \.self) { value in
                                    Capsule().fill(barColor(value)).frame(height: value == 0 ? 22 : 12)
                                }
                            }.accessibilityHidden(true)
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                }
                HStack(spacing: 12) {
                    Panel(accent: true) { Instrument(label: "SOLLSCHNITT", value: RallyFormat.decimal(result.targetSpeed, digits: 1), unit: "km/h", size: 38) }
                    Panel { Instrument(label: "IST · GPS", value: RallyFormat.decimal(session.speed, digits: 1), unit: "km/h", size: 38) }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 20) {
                        Instrument(label: "PRÜFUNGSDISTANZ", value: RallyFormat.distance(session.stageDistance), unit: "km", size: 43)
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 7) {
                                Eyebrow(text: "ISTZEIT")
                                Text(RallyFormat.duration(session.stageElapsed))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 7) {
                                Eyebrow(text: "SOLLZEIT")
                                Text(RallyFormat.duration(result.targetTime))
                            }
                        }.font(.system(.title3, design: .monospaced))
                    }
                }
                if let remaining = result.metersToChange, let next = result.nextSpeed {
                    Panel {
                        HStack {
                            Image(systemName: "arrow.triangle.swap").font(.title2)
                            VStack(alignment: .leading, spacing: 6) {
                                Eyebrow(text: "NÄCHSTER SCHNITTWECHSEL")
                                Text("In \(RallyFormat.decimal(remaining, digits: 0)) m")
                                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                            }
                            Spacer()
                            Text("\(RallyFormat.decimal(next, digits: 0))").font(.system(.largeTitle, design: .monospaced, weight: .bold))
                            Text("km/h").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if !session.stageActive && session.state != .scheduled {
                    HStack(spacing: 12) {
                        ActionButton(title: "Startzeit", icon: "clock") {
                            startDate = Calendar.current.date(bySetting: .second, value: 0, of: Date().addingTimeInterval(120)) ?? Date().addingTimeInterval(120)
                            showSchedule = true
                        }
                        ActionButton(title: "WP starten", icon: "flag.checkered", prominent: true) { session.startStage() }
                    }.disabled(session.state == .paused)
                }
                if session.busy { SessionControls() }
                GPSStatus()
                Text("+ = zu spät · − = zu früh. Die Abweichung hängt von der GPS- und Streckengenauigkeit ab.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(20)
        }.navigationTitle("Regularity").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
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
        return session.stageActive && value == position ? deltaColor : Color.secondary.opacity(0.2)
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
