import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject private var session: RallySession
    @State private var official = "5,000"
    @State private var profileName = ""
    @State private var saveAsNew = false
    @State private var showManual = false
    @State private var saved = false
    @State private var editingProfile: CalibrationProfile?
    private var summary: CalibrationSummary? { try? CalibrationEngine.summarize(session.calibrationMeasurements) }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "AKTIVER KALIBRIERFAKTOR")
                    Text(RallyFormat.decimal(session.factor, digits: 5))
                        .font(.system(size: 46, weight: .semibold, design: .monospaced))
                        .minimumScaleFactor(0.5).lineLimit(1)
                    Text(session.data.settings.profile.name).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
                Text("Messstrecke × Faktor = Rallyestrecke. Änderungen gelten ab der nächsten Fahrt.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            liveMeasurement
            measurementList
            evaluation
            profileList
        }.navigationTitle("Kalibrierung").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .onAppear { profileName = session.data.settings.profile.name }
            .sheet(isPresented: $showManual) { ManualCalibrationView() }
            .sheet(item: $editingProfile) { profile in CalibrationProfileEditor(profile: profile) }
            .onChange(of: session.calibrationMeasurements) { _, _ in saved = false }
            .onChange(of: profileName) { _, _ in saved = false }
            .onChange(of: saveAsNew) { _, _ in saved = false }
    }

    private var liveMeasurement: some View {
        Section {
            if let capture = session.calibrationCapture {
                LabeledContent("Referenzstrecke", value: "\(RallyFormat.distance(capture.officialMeters)) km")
                LabeledContent("GPS-Rohstrecke", value: "\(RallyFormat.distance(max(0, session.meter.raw - capture.rawStart))) km")
                    .font(.system(.headline, design: .monospaced))
                GPSStatus()
                if capture.isDemo { Label("Demo-Messung", systemImage: "testtube.2").foregroundStyle(.orange) }
                if capture.interrupted {
                    Label("Messung unterbrochen – bitte neu messen", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                } else if !capture.hasFix {
                    Text("Warte auf den ersten gültigen GPS-Punkt. Erst danach losfahren.").font(.caption).foregroundStyle(.secondary)
                }
                Button("Am Ziel: Messung übernehmen", systemImage: "flag.checkered") { session.completeCalibration() }
                    .disabled(capture.interrupted || !capture.hasFix || session.meter.raw <= capture.rawStart)
                Button("Messung verwerfen", role: .destructive) { session.cancelCalibration() }
            } else {
                NumericField(label: "Offizielle Strecke", value: $official, unit: "km")
                Button("Am Start: Messung beginnen", systemImage: "ruler") {
                    if let km = RallyFormat.parse(official) { session.beginCalibration(officialMeters: km * 1000) }
                    saved = false
                }.disabled((RallyFormat.parse(official) ?? 0) <= 0 || session.stageActive || session.state == .paused || session.state == .scheduled)
                Button("Messwerte manuell hinzufügen", systemImage: "plus") { showManual = true }
                if session.busy && !session.stageActive && session.state != .scheduled {
                    Button("Kalibrierfahrt beenden & speichern") { session.finish() }
                }
            }
        } header: { Text("Referenzstrecke messen") }
        footer: { Text("Am Start und Ziel jeweils im Stand bedienen. Rohstrecke bleibt unabhängig von TOTAL-Sync und Trip-Reset. Eine laufende Kalibrierung bleibt beim Ansichtswechsel erhalten; Pausen und verworfene GPS-Punkte machen sie ungültig.") }
    }

    private var measurementList: some View {
        Section {
            if session.calibrationMeasurements.isEmpty {
                Text("Noch keine Referenzmessungen. Sammle mehrere unabhängige Durchfahrten.").foregroundStyle(.secondary)
            }
            ForEach($session.calibrationMeasurements) { $measurement in
                Toggle(isOn: $measurement.included) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Soll \(RallyFormat.distance(measurement.officialMeters)) km · GPS \(RallyFormat.distance(measurement.rawMeters)) km").font(.subheadline)
                        if let factor = try? CalibrationEngine.factor(officialMeters: measurement.officialMeters, measuredMeters: measurement.rawMeters) {
                            Text("× \(RallyFormat.decimal(factor, digits: 5))\(measurement.isDemo ? " · DEMO" : "")")
                                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        }
                    }
                }
            }.onDelete { session.calibrationMeasurements.remove(atOffsets: $0) }
        } header: { Text("Messreihe · \(session.calibrationMeasurements.count)") }
        footer: { Text("Fehlerhafte Durchfahrten ausschalten, um sie auszuschließen. Demo und echte Messungen getrennt auswerten. Nicht gespeicherte Messreihen bleiben bis zum Beenden der App erhalten.") }
    }

    @ViewBuilder private var evaluation: some View {
        if let summary {
            Section("Auswertung") {
                LabeledContent("Gewichteter Faktor", value: RallyFormat.decimal(summary.factor, digits: 5))
                    .font(.system(.headline, design: .monospaced))
                LabeledContent("Verwendete Messungen", value: "\(summary.count)")
                LabeledContent("Referenzstrecke gesamt", value: "\(RallyFormat.distance(summary.officialMeters)) km")
                LabeledContent("Faktor-Spannweite", value: "\(RallyFormat.decimal(summary.spreadPercent, digits: 2)) %")
                LabeledContent("Änderung zum aktiven Faktor", value: "\(RallyFormat.decimal((summary.factor / session.factor - 1) * 100, digits: 2)) %")
                if summary.containsShortMeasurement {
                    Text("Eine Referenz ist kürzer als 1 km. Längere, eindeutig markierte Strecken verringern den Einfluss kleiner Start-/Zielfehler.").font(.caption).foregroundStyle(.orange)
                }
                if summary.spreadPercent > 1 {
                    Text("Die Einzelfaktoren weichen um mehr als 1 % voneinander ab. Prüfe Messpunkte und GPS-Empfang vor dem Übernehmen.").font(.caption).foregroundStyle(.orange)
                }
                Text("Summe der Referenzstrecken ÷ Summe der Rohstrecken. Die Spannweite ist eine Vergleichshilfe, kein Genauigkeitsnachweis.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Faktor übernehmen") {
                Toggle("Neues Fahrzeugprofil anlegen", isOn: $saveAsNew)
                TextField("Profilname", text: $profileName)
                Button(saveAsNew ? "Neues Profil speichern" : "Aktives Profil aktualisieren") {
                    saved = session.saveCalibrationProfile(id: saveAsNew ? nil : session.data.settings.profile.id,
                        name: profileName, factor: summary.factor, method: "Referenzmessungen",
                        measurements: session.calibrationMeasurements)
                }.disabled(saved || session.busy || session.calibrationCapture != nil || profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if session.busy { Text("Beende zuerst die Fahrt, um den Faktor zu übernehmen.").font(.caption).foregroundStyle(.secondary) }
                if saved { Label("Profil mit Messreihe gespeichert", systemImage: "checkmark.circle").foregroundStyle(.green) }
            }
        } else if session.calibrationMeasurements.contains(where: \.included) {
            Section {
                Text("Messreihe nicht auswertbar. Bitte Demo- und echte Messungen nicht mischen und ungültige Einträge ausschließen.").foregroundStyle(.orange)
            }
        }
    }

    private var profileList: some View {
        Section("Fahrzeugprofile & direkter Faktor") {
            ForEach(session.data.settings.profiles) { profile in
                HStack {
                    Button {
                        session.selectCalibrationProfile(profile.id)
                        profileName = session.data.settings.profile.name; saved = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                Text("× \(RallyFormat.decimal(profile.factor, digits: 5))").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                            }
                            if profile.id == session.data.settings.profile.id { Image(systemName: "checkmark.circle.fill") }
                        }
                    }.buttonStyle(.borderless).disabled(session.busy || session.calibrationCapture != nil)
                    Spacer()
                    Button { editingProfile = profile } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                        .buttonStyle(.borderless).accessibilityLabel("\(profile.name) bearbeiten")
                }
            }
            Button("Profil mit eigenem Faktor anlegen", systemImage: "plus") {
                editingProfile = CalibrationProfile(name: "Neues Fahrzeug")
            }.disabled(session.busy)
        }
    }
}

private struct ManualCalibrationView: View {
    @EnvironmentObject private var session: RallySession
    @Environment(\.dismiss) private var dismiss
    @State private var official = "5,000"
    @State private var measured = ""
    @State private var enteredFactor = "1,00000"
    @State private var usesDisplayedDistance = false
    @State private var isDemo = false
    @State private var validation: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Referenz und Messwert") {
                    NumericField(label: "Offizielle Strecke", value: $official, unit: "km")
                    Toggle("Messwert ist bereits kalibriert", isOn: $usesDisplayedDistance)
                    NumericField(label: usesDisplayedDistance ? "Angezeigte Strecke" : "GPS-Rohstrecke", value: $measured, unit: "km")
                    if usesDisplayedDistance {
                        NumericField(label: "Damals verwendeter Faktor", value: $enteredFactor, unit: "×")
                        Text("Nur die gefahrene Differenz ohne manuelle Korrekturen eingeben. Ein TOTAL-Sync kann nicht rückwirkend herausgerechnet werden.").font(.caption).foregroundStyle(.secondary)
                    }
                    Toggle("Demo-Messung", isOn: $isDemo)
                }
                if let validation { Text(validation).foregroundStyle(.red) }
            }.navigationTitle("Messwerte ergänzen")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Hinzufügen") { add() } }
                }.onAppear { enteredFactor = RallyFormat.decimal(session.factor, digits: 12); isDemo = session.isDemo }
        }
    }
    private func add() {
        do {
            guard let reference = RallyFormat.parse(official), let measured = RallyFormat.parse(measured) else { throw RallyError.invalidCalibration }
            var raw = measured * 1000
            if usesDisplayedDistance {
                guard let factor = RallyFormat.parse(enteredFactor) else { throw RallyError.invalidCalibration }
                raw = try CalibrationEngine.rawDistance(displayedMeters: raw, appliedFactor: factor)
            }
            _ = try CalibrationEngine.factor(officialMeters: reference * 1000, measuredMeters: raw)
            session.calibrationMeasurements.append(.init(officialMeters: reference * 1000, rawMeters: raw, isDemo: isDemo))
            dismiss()
        } catch { validation = error.localizedDescription }
    }
}

private struct CalibrationProfileEditor: View {
    @EnvironmentObject private var session: RallySession
    @Environment(\.dismiss) private var dismiss
    let profile: CalibrationProfile
    @State private var name = ""
    @State private var factor = ""
    @State private var confirmDelete = false
    private var exists: Bool { session.data.settings.profiles.contains { $0.id == profile.id } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Profil bearbeiten") {
                    TextField("Fahrzeugname", text: $name)
                    NumericField(label: "Kalibrierfaktor", value: $factor, unit: "×")
                    Button("Faktor auf 1,00000 zurücksetzen") { factor = "1,00000" }
                    Text("Zulässiger Faktor: 0,5 bis 2,0. Der Wert wird erst mit Speichern übernommen.").font(.caption).foregroundStyle(.secondary)
                }.disabled(session.busy || session.calibrationCapture != nil)
                if let history = profile.history, !history.isEmpty {
                    Section("Kalibrierhistorie") {
                        ForEach(Array(history.reversed())) { record in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(record.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                                Text("\(RallyFormat.decimal(record.previousFactor, digits: 5)) → \(RallyFormat.decimal(record.factor, digits: 5))")
                                    .font(.system(.subheadline, design: .monospaced))
                                Text("\(record.method) · \(record.measurements.count) Messungen").font(.caption)
                                Button("Diesen Faktor wiederherstellen") { factor = RallyFormat.decimal(record.factor, digits: 12) }.disabled(session.busy)
                            }.padding(.vertical, 4)
                        }
                    }
                }
                if exists {
                    Section {
                        Button("Profil löschen", role: .destructive) { confirmDelete = true }
                            .disabled(session.busy || session.calibrationCapture != nil || session.data.settings.profiles.count <= 1)
                    } footer: { Text("Mindestens ein Fahrzeugprofil bleibt erhalten.") }
                }
            }.navigationTitle("Fahrzeugprofil")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Schließen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") {
                            guard let value = RallyFormat.parse(factor) else { return }
                            let changed = abs(value - profile.factor) > 1e-10
                            if session.saveCalibrationProfile(id: exists ? profile.id : nil, name: name, factor: value,
                                method: changed || !exists ? "Direkte Eingabe" : "Umbenennung") { dismiss() }
                        }.disabled(session.busy || session.calibrationCapture != nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                   (try? CalibrationEngine.validateFactor(RallyFormat.parse(factor) ?? .nan)) == nil)
                    }
                }.onAppear { name = profile.name; factor = RallyFormat.decimal(profile.factor, digits: 12) }
                .confirmationDialog("Profil \(profile.name) einschließlich Kalibrierhistorie löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Profil löschen", role: .destructive) { if session.deleteCalibrationProfile(profile.id) { dismiss() } }
                }
        }
    }
}
