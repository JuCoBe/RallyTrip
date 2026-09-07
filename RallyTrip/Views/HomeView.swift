import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: RallySession
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Label("RALLYTRIP", systemImage: "flag.checkered")
                            .font(.system(.headline, design: .monospaced)).tracking(3)
                        Spacer()
                        Text("V1.0").font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Jeder Meter.\nJede Sekunde.")
                                .font(.system(size: 37, weight: .bold, design: .rounded)).tracking(-1.5)
                            Text("Dein digitaler Rallye-Tripmaster.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    NavigationLink { TripmasterView() } label: {
                        Panel(accent: true) {
                            VStack(alignment: .leading, spacing: 28) {
                                HStack {
                                    Eyebrow(text: "01 / TRIPMASTER")
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.title2)
                                }
                                Instrument(label: session.busy ? "TOTAL · LIVE" : "BEREIT FÜR DIE NÄCHSTE ETAPPE",
                                           value: RallyFormat.distance(session.meter.total), unit: "km", size: 64)
                                HStack {
                                    Label(session.state.rawValue, systemImage: session.busy ? "record.circle" : "location.north.circle")
                                    Spacer()
                                    Text(session.data.settings.profile.name).lineLimit(1)
                                }.font(.system(.caption, design: .monospaced))
                            }
                        }
                    }.buttonStyle(.plain)

                    VStack(spacing: 10) {
                        NavigationLink { RegularityView() } label: {
                            MenuRow(number: "02", title: "Regularity", subtitle: "Sollschnitt. Timing. Präzision.", icon: "stopwatch")
                        }
                        NavigationLink { RouteView() } label: {
                            MenuRow(number: "03", title: "Route / Roadbook", subtitle: "Deine Strecke im Blick", icon: "point.topleft.down.to.point.bottomright.curvepath")
                        }
                        NavigationLink { CalibrationView() } label: {
                            MenuRow(number: "04", title: "Kalibrierung", subtitle: "Auf dein Fahrzeug abgestimmt", icon: "slider.horizontal.3")
                        }
                        NavigationLink { SettingsView() } label: {
                            MenuRow(number: "05", title: "Einstellungen", subtitle: "Display, Signale & Daten", icon: "gearshape")
                        }
                    }.buttonStyle(.plain)

                    if let notice = session.notice {
                        HStack(alignment: .top) {
                            Image(systemName: "checkmark.circle")
                            Text(notice).font(.caption)
                            Spacer()
                            Button { session.notice = nil } label: { Image(systemName: "xmark") }
                                .accessibilityLabel("Hinweis schließen")
                        }.foregroundStyle(.secondary)
                    }
                    HStack {
                        Label(session.isDemo ? "DEMO-MODUS" : "IPHONE GPS", systemImage: "location.circle")
                        Spacer()
                        Text("FAKTOR \(RallyFormat.decimal(session.factor, digits: 5))")
                    }.font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                }.padding(20)
            }.background(RallyStyle.background)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct MenuRow: View {
    var number: String
    var title: String
    var subtitle: String
    var icon: String
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 24, weight: .light)).frame(width: 32)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(.headline, design: .rounded))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(number).font(.system(.caption2, design: .monospaced)).foregroundStyle(.tertiary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }.padding(18).background(RallyStyle.panel, in: RoundedRectangle(cornerRadius: 20))
            .foregroundStyle(.primary)
    }
}
