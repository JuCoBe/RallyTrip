import SwiftUI

struct TripmasterView: View {
    @EnvironmentObject private var session: RallySession
    @State private var correction = 10
    @State private var showSync = false
    @State private var syncValue = ""
    @AppStorage("tripmasterFocusMode") private var focusMode = false

    var body: some View {
        ScrollView {
            VStack(spacing: focusMode ? 12 : 16) {
                GPSStatus()
                Panel(accent: true, inset: focusMode ? 16 : 20) {
                    VStack(alignment: .leading, spacing: 18) {
                        if !focusMode {
                            Label(session.state.rawValue, systemImage: session.state == .paused ? "pause.circle" : "record.circle")
                                .font(.subheadline).foregroundStyle(.tint)
                        }
                        Instrument(label: "Total · Gesamtstrecke", value: RallyFormat.distance(session.meter.total), unit: "km", size: focusMode ? 56 : 66)
                        if !focusMode {
                            Divider()
                            AdaptiveRow {
                                Label(session.data.settings.profile.name, systemImage: "car.side")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("× \(RallyFormat.decimal(session.factor, digits: 5))").monospacedDigit()
                            }.font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Panel(inset: focusMode ? 16 : 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        AdaptiveRow {
                            Instrument(label: "Trip · Roadbook", value: RallyFormat.distance(session.meter.trip), unit: "km", size: 44)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button { session.resetTrip() } label: {
                                Image(systemName: "arrow.counterclockwise").font(.title2)
                                    .frame(width: 54, height: 54)
                            }.buttonStyle(.bordered).buttonBorderShape(.circle)
                                .accessibilityLabel("Trip auf null setzen")
                                .accessibilityHint("Der letzte Reset kann rückgängig gemacht werden.")
                                .disabled(session.meter.trip == 0)
                        }
                        if session.meter.canUndoTripReset {
                            Button {
                                session.undoTripReset()
                            } label: {
                                Label("Letzten Reset rückgängig", systemImage: "arrow.uturn.backward")
                                    .font(.subheadline).frame(minHeight: 44)
                            }
                        }
                    }
                }
                AdaptiveRow {
                    Panel(inset: focusMode ? 16 : 20) { Instrument(label: "Geschwindigkeit", value: session.accuracy == nil ? "—" : RallyFormat.decimal(session.speed, digits: 1), unit: "km/h", size: 36) }
                    if !focusMode {
                        Panel { Instrument(label: "Durchschnitt", value: RallyFormat.decimal(session.averageSpeed, digits: 1), unit: "km/h", size: 36) }
                    }
                }
                if !focusMode {
                    LabeledContent("Fahrtzeit", value: RallyFormat.duration(session.elapsed))
                        .font(.subheadline).monospacedDigit().padding(.horizontal, 4)
                    VStack(spacing: 12) {
                        AdaptiveRow {
                            Eyebrow(text: "Total korrigieren").frame(maxWidth: .infinity, alignment: .leading)
                            Picker("Korrekturschritt", selection: $correction) {
                                Text("1 m").tag(1); Text("10 m").tag(10); Text("100 m").tag(100)
                            }.pickerStyle(.segmented).frame(minHeight: 44)
                        }
                        AdaptiveRow(spacing: 10) {
                            ActionButton(title: "\(correction) m", icon: "minus") { session.correctTotal(-Double(correction)) }
                                .accessibilityLabel("Total um \(correction) Meter verringern")
                            ActionButton(title: "\(correction) m", icon: "plus") { session.correctTotal(Double(correction)) }
                                .accessibilityLabel("Total um \(correction) Meter erhöhen")
                        }
                        ActionButton(title: "Mit Roadbook abgleichen", icon: "scope") {
                            syncValue = RallyFormat.distance(session.meter.total); showSync = true
                        }
                    }
                }
                if let next = session.nextRoadbook {
                    Panel {
                        AdaptiveRow(spacing: 16) {
                            Image(systemName: next.symbol).font(.title)
                            VStack(alignment: .leading, spacing: 5) {
                                Eyebrow(text: "Nächster Roadbook-Punkt")
                                Text(next.instruction).font(.headline)
                            }
                            Text("In \(RallyFormat.distance(next.meters - session.meter.total)) km")
                                .font(.system(.subheadline, design: .monospaced))
                        }
                    }
                }
                SessionControls()
            }.padding(20)
        }.background(RallyStyle.background)
            .navigationTitle("Tripmaster").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { focusMode.toggle() } label: {
                        Label(focusMode ? "Alle Details" : "Fokus", systemImage: focusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .frame(minHeight: 44)
                    }.accessibilityLabel(focusMode ? "Alle Details anzeigen" : "Fokusmodus aktivieren")
                        .accessibilityValue(focusMode ? "Fokus aktiv" : "Alle Details sichtbar")
                }
            }
            .sheet(isPresented: $showSync) {
                NavigationStack {
                    Form {
                        Section("Roadbook-Distanz übernehmen") {
                            NumericField(label: "Total", value: $syncValue, unit: "km")
                        }
                        Text("Trip bleibt unverändert. Während einer Prüfung wird auch die Prüfungsdistanz korrigiert.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.navigationTitle("Strecke synchronisieren")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { showSync = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Übernehmen") {
                                    if let km = RallyFormat.parse(syncValue), km >= 0 {
                                        session.syncTotal(km * 1000); showSync = false
                                    }
                                }.disabled((RallyFormat.parse(syncValue) ?? -1) < 0)
                            }
                        }
                }.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            }
    }
}
