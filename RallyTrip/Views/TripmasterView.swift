import SwiftUI

struct TripmasterView: View {
    @EnvironmentObject private var session: RallySession
    @State private var correction = 10
    @State private var showSync = false
    @State private var syncValue = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GPSStatus()
                Panel(accent: true) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Eyebrow(text: "TOTAL")
                            Spacer()
                            Text(session.state.rawValue).font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(RallyFormat.distance(session.meter.total))
                                .font(.system(size: 76, weight: .semibold, design: .monospaced))
                                .tracking(-4).minimumScaleFactor(0.3).lineLimit(1)
                            Text("km").foregroundStyle(.secondary)
                        }.accessibilityLabel("Gesamt \(RallyFormat.distance(session.meter.total)) Kilometer")
                        Divider().overlay(Color.black.opacity(0.15))
                        HStack {
                            Label(session.data.settings.profile.name, systemImage: "car.side")
                            Spacer()
                            Text("× \(RallyFormat.decimal(session.factor, digits: 5))")
                        }.font(.system(.caption, design: .monospaced))
                    }
                }
                Panel {
                    HStack {
                        Instrument(label: "TRIP · ROADBOOK", value: RallyFormat.distance(session.meter.trip), unit: "km", size: 44)
                        Spacer()
                        Button { session.resetTrip() } label: {
                            Image(systemName: "arrow.counterclockwise").font(.title2)
                                .frame(width: 54, height: 54).background(.quaternary, in: Circle())
                        }.buttonStyle(.plain).accessibilityLabel("Trip auf null setzen")
                    }
                }
                HStack(spacing: 12) {
                    Panel { Instrument(label: "GESCHWINDIGKEIT", value: RallyFormat.decimal(session.speed, digits: 1), unit: "km/h", size: 36) }
                    Panel {
                        VStack(alignment: .leading, spacing: 16) {
                            Eyebrow(text: "FAHRTZEIT")
                            Text(RallyFormat.duration(session.elapsed)).font(.system(.title3, design: .monospaced, weight: .semibold))
                                .minimumScaleFactor(0.5).lineLimit(1)
                        }.frame(maxHeight: .infinity)
                    }
                }
                VStack(spacing: 12) {
                    HStack {
                        Eyebrow(text: "TOTAL KORRIGIEREN")
                        Spacer()
                        Picker("Korrekturschritt", selection: $correction) {
                            Text("1 m").tag(1); Text("10 m").tag(10); Text("100 m").tag(100)
                        }.pickerStyle(.segmented).frame(maxWidth: 190)
                    }
                    HStack(spacing: 10) {
                        ActionButton(title: "−\(correction) m", icon: "minus") { session.correctTotal(-Double(correction)) }
                        ActionButton(title: "SYNC", icon: "scope") {
                            syncValue = RallyFormat.distance(session.meter.total); showSync = true
                        }
                        ActionButton(title: "+\(correction) m", icon: "plus") { session.correctTotal(Double(correction)) }
                    }
                }
                if let next = session.nextRoadbook {
                    Panel {
                        HStack(spacing: 16) {
                            Image(systemName: next.symbol).font(.title)
                            VStack(alignment: .leading, spacing: 5) {
                                Eyebrow(text: "NÄCHSTER ROADBOOK-PUNKT")
                                Text(next.instruction).font(.headline)
                            }
                            Spacer()
                            Text("\(RallyFormat.distance(next.meters - session.meter.total)) km")
                                .font(.system(.subheadline, design: .monospaced))
                        }
                    }
                }
                SessionControls()
            }.padding(20)
        }.navigationTitle("Tripmaster").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
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
                }.presentationDetents([.medium])
            }
    }
}
