import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: RallySession
    var body: some View {
        Form {
            Section("Display") {
                Picker("Darstellung", selection: $session.data.settings.theme) {
                    Text("System").tag("System")
                    Text("Hell").tag("Hell")
                    Text("Dunkel").tag("Dunkel")
                    Text("Nacht").tag("Nacht")
                }
                Toggle("Bildschirm während der Fahrt anlassen", isOn: $session.data.settings.keepAwake)
            }
            Section("Signale") {
                Toggle("Akustische Hinweise", isOn: $session.data.settings.sound)
                NavigationLink("Akustisches Feedback") { AudioFeedbackSettingsView() }
                Toggle("Haptisches Feedback", isOn: $session.data.settings.haptics)
            }
            Section("Apple Watch") {
                Label("Start, Zeitabweichung und Korrektur", systemImage: "applewatch")
                Text("Öffne RallyTrip auf dem iPhone und der gekoppelten Apple Watch. Die Watch kann eine Fahrt oder Wertungsprüfung starten. Total stellst du über die Digital Crown um bis zu 100 Meter in beide Richtungen nach und bestätigst mit Übernehmen. Das iPhone übernimmt die GPS-Messung.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("Ohne aktuelle Verbindung sind Start und Korrektur gesperrt. Erlaube den genauen Standort zuerst auf dem iPhone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section {
                Toggle("Demo-Modus", isOn: $session.isDemo).disabled(session.busy)
                if session.isDemo { DemoSpeedControl() }
                Text("Simuliert eine Fahrt mit der eingestellten Geschwindigkeit. Du kannst sie auch während einer Demo-Fahrt ändern. GPS wird dabei nicht verwendet. Der Modus kann nur zwischen Fahrten gewechselt werden.")
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
            .onChange(of: session.data.settings.sound) { _, _ in session.audioSettingsChanged() }
    }
}

private struct AudioFeedbackSettingsView: View {
    @EnvironmentObject private var session: RallySession
    var body: some View {
        Form {
            if !session.data.settings.sound {
                Section {
                    Button("Akustische Hinweise einschalten") { session.data.settings.sound = true }
                        .frame(minHeight: 44)
                    Text("Die Tonausgabe ist derzeit ausgeschaltet.").font(.caption)
                }
            }
            Section("Regularity und Rundstrecke") {
                Toggle("Abweichung durch Piepen melden", isOn: $session.data.settings.feedbackSounds.deviationBeeps)
                Picker("Tonzuordnung", selection: $session.data.settings.feedbackSounds.highToneWhenEarly) {
                    Text("Zu langsam: hoch · zu schnell: tief").tag(false)
                    Text("Zu schnell: hoch · zu langsam: tief").tag(true)
                }.pickerStyle(.inline)
                Text("Je größer die Zeitabweichung, desto schneller das Piepen: etwa alle 1,5 s bei 1 s Abweichung, alle 0,5 s bei 3 s und alle 0,2 s ab 7,5 s. Innerhalb ±0,5 s und ohne gültige Messdaten bleibt es ruhig.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Rundstrecke") {
                Toggle("Ziel-Countdown: drei, zwei, eins", isOn: $session.data.settings.feedbackSounds.finishCountdown)
                Text("Die letzten drei Sekunden bis Rundenstart + Referenzzeit werden angesagt. Der Countdown hat Vorrang vor Pieptönen und Schnittwechselansagen. Ohne Referenz oder bei ungültiger GPS-Runde erfolgt keine Ansage. In der Demo läuft er mit dem Zeitraffer.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("Bei gleichzeitig laufender Regularity- und Rundstreckenmessung hat die Rundstrecke Vorrang. Die Lautstärke stellst du über die Medienlautstärke des iPhones ein.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Akustisches Feedback").navigationBarTitleDisplayMode(.inline)
            .onChange(of: session.data.settings.feedbackSounds) { _, _ in session.audioSettingsChanged() }
            .onChange(of: session.data.settings.sound) { _, _ in session.audioSettingsChanged() }
    }
}

struct DemoSpeedControl: View {
    @EnvironmentObject private var session: RallySession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(value: $session.demoSpeedKPH, in: 0...200, step: 1) {
                Text("Demo: \(RallyFormat.decimal(session.demoSpeedKPH, digits: 0)) km/h")
                    .monospacedDigit()
            }
            Slider(value: $session.demoSpeedKPH, in: 0...200, step: 1)
                .accessibilityLabel("Demo-Geschwindigkeit")
                .accessibilityValue("\(RallyFormat.decimal(session.demoSpeedKPH, digits: 0)) Kilometer pro Stunde")
        }
    }
}
