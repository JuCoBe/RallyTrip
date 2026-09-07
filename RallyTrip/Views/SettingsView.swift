import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: RallySession
    var body: some View {
        Form {
            Section("Display") {
                Picker("Darstellung", selection: $session.data.settings.theme) {
                    Text("Hell").tag("Hell")
                    Text("Dunkel").tag("Dunkel")
                    Text("Nacht").tag("Nacht")
                }
                Toggle("Bildschirm während der Fahrt anlassen", isOn: $session.data.settings.keepAwake)
            }
            Section("Signale") {
                Toggle("Akustische Schnittwechsel-Hinweise", isOn: $session.data.settings.sound)
                Toggle("Haptisches Feedback", isOn: $session.data.settings.haptics)
            }
            Section {
                Toggle("Demo-Modus", isOn: $session.isDemo).disabled(session.busy)
                Text("Simuliert eine Fahrt mit etwa 48 km/h. GPS wird im Demo-Modus nicht verwendet. Der Modus kann nur zwischen Fahrten gewechselt werden.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("Ausprobieren") }
            Section("Messquelle") {
                LabeledContent("Geschwindigkeit & Strecke", value: "iPhone GPS")
                LabeledContent("GPS-Filter", value: "≤ 20 m · ≤ 5 s")
                if !session.fullAccuracy {
                    Button("Genauen Standort anfordern") { session.requestPreciseLocation() }
                }
                Button("iPhone-Einstellungen öffnen", systemImage: "arrow.up.forward.app") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                Text("OBD und externe GNSS-Empfänger sind für spätere Versionen vorgesehen.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Daten & Genauigkeit") {
                Text("Fahrten und Profile bleiben lokal auf dem iPhone. Du kannst GPS-Strecken aus einer gespeicherten Fahrt als GPX exportieren. Die App-Dateien sind in der Dateien-App unter RallyTrip erreichbar.")
                Text("Ohne genaues GPS stoppt die Streckenzählung. GPS-Lücken und Pausen werden auf der Karte getrennt dargestellt. Die Zeitmessung einer Wertungsprüfung läuft dabei weiter.")
                Text("Die Anzeige in Hundertstelsekunden beschreibt die Rechenauflösung, nicht die Messgenauigkeit des iPhone-GPS.")
            }.font(.footnote)
            Section {
                HStack {
                    Label("RallyTrip", systemImage: "flag.checkered")
                    Spacer()
                    Text("1.0 · iOS 17+").foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("Einstellungen").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .onDisappear { session.persist(); session.updateIdleTimer() }
            .onChange(of: session.data.settings.keepAwake) { _, _ in session.updateIdleTimer() }
    }
}
