import SwiftUI

struct CalibrationView: View {
    @EnvironmentObject private var session: RallySession
    @State private var official = "5,000"
    @State private var measured = ""
    @State private var profileName = ""
    @State private var baseline: Double?
    @State private var validation: String?
    @State private var saved = false

    private var candidate: Double? {
        guard let official = RallyFormat.parse(official), let measured = RallyFormat.parse(measured) else { return nil }
        return try? CalibrationEngine.factor(officialMeters: official * 1000, measuredMeters: measured * 1000)
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Eyebrow(text: "AKTIVER KALIBRIERFAKTOR")
                    Text(RallyFormat.decimal(session.factor, digits: 5))
                        .font(.system(size: 48, weight: .semibold, design: .monospaced))
                    Text(session.data.settings.profile.name).foregroundStyle(.secondary)
                }.padding(.vertical, 12)
            }
            Section("Kalibrierstrecke") {
                NumericField(label: "Offizielle Strecke", value: $official, unit: "km")
                NumericField(label: "GPS-Rohstrecke", value: $measured, unit: "km")
                if let baseline {
                    Text("Gemessen: \(RallyFormat.distance(max(0, session.meter.raw - baseline))) km")
                        .font(.system(.headline, design: .monospaced))
                    Button("Messung übernehmen") {
                        measured = RallyFormat.decimal(max(0, session.meter.raw - baseline) / 1000, digits: 6)
                        self.baseline = nil
                    }
                } else {
                    Button("Kalibrierstrecke ab jetzt messen", systemImage: "ruler") {
                        if !session.busy { session.startTrip() }
                        baseline = session.meter.raw
                    }.disabled(session.state == .paused)
                }
                Text("Gemessen wird die GPS-Rohdistanz nach dem Qualitätsfilter: ohne den bisherigen Kalibrierfaktor und ohne manuelle Korrekturen.")
                    .font(.caption).foregroundStyle(.secondary)
                if let candidate {
                    LabeledContent("Neuer Faktor", value: RallyFormat.decimal(candidate, digits: 5))
                        .font(.system(.headline, design: .monospaced))
                }
            }
            Section("Fahrzeugprofil") {
                TextField("z. B. Porsche Spyder RS", text: $profileName)
                Button("Als neues Profil speichern") { save() }
                    .disabled(candidate == nil || profileName.trimmingCharacters(in: .whitespaces).isEmpty || session.busy)
                if session.busy {
                    if baseline == nil && !session.stageActive {
                        Button("Kalibrierfahrt beenden & speichern") { session.finish() }
                    }
                    Text("Beende die Fahrt, bevor du den Faktor speicherst. Laufende Fahrten behalten ihren Kalibrierfaktor.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let validation { Text(validation).foregroundStyle(.red) }
                if saved { Label("Profil gespeichert und aktiviert", systemImage: "checkmark.circle").foregroundStyle(.green) }
            }
            Section("Gespeicherte Profile") {
                ForEach(session.data.settings.profiles) { profile in
                    Button {
                        session.data.settings.selectedProfile = profile.id; session.persist()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name).foregroundStyle(.primary)
                                Text("× \(RallyFormat.decimal(profile.factor, digits: 5))")
                                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if session.data.settings.profile.id == profile.id { Image(systemName: "checkmark.circle.fill") }
                        }
                    }.disabled(session.busy)
                }
            }
        }.navigationTitle("Kalibrierung").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
    }

    private func save() {
        guard let candidate else { validation = RallyError.invalidCalibration.localizedDescription; return }
        let profile = CalibrationProfile(name: profileName.trimmingCharacters(in: .whitespaces), factor: candidate)
        session.data.settings.profiles.append(profile)
        session.data.settings.selectedProfile = profile.id
        session.persist(); saved = true; validation = nil
    }
}
