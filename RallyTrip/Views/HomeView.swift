import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: RallySession
    @State private var selection = Destination.overview

    private enum Destination: Hashable {
        case overview, tripmaster, regularity, route
    }

    init(initialTab: String? = nil) {
        let destination: Destination
        switch initialTab {
        case "tripmaster": destination = .tripmaster
        case "regularity": destination = .regularity
        case "route": destination = .route
        default: destination = .overview
        }
        _selection = State(initialValue: destination)
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { overview }
                .tabItem { Label("Übersicht", systemImage: "square.grid.2x2") }
                .tag(Destination.overview)
            NavigationStack { TripmasterView() }
                .tabItem { Label("Tripmaster", systemImage: "speedometer") }
                .tag(Destination.tripmaster)
            NavigationStack { RegularityView() }
                .tabItem { Label("Regularity", systemImage: "stopwatch") }
                .tag(Destination.regularity)
            NavigationStack { RouteView() }
                .tabItem { Label("Route", systemImage: "map") }
                .tag(Destination.route)
        }
    }

    private var overview: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Label(session.state.rawValue, systemImage: session.busy ? "record.circle" : "flag.checkered")
                        .font(.headline).foregroundStyle(.tint)
                    Instrument(label: "Gesamtstrecke", value: RallyFormat.distance(session.meter.total), unit: "km", size: 56)
                    GPSStatus()
                    ActionButton(title: session.busy ? "Zur laufenden Fahrt" : "Tripmaster öffnen",
                                 icon: "speedometer", prominent: true) { selection = .tripmaster }
                }.padding(.vertical, 8)
            } header: { Text("Deine Fahrt") }

            if session.isDemo {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Demo-Modus aktiv").font(.headline)
                            Text("Die angezeigte Fahrt ist simuliert.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "testtube.2").foregroundStyle(.tint) }
                }
            }

            Section("Vorbereitung") {
                NavigationLink { CalibrationView() } label: {
                    overviewLabel("Kalibrierung", subtitle: session.data.settings.profile.name, icon: "slider.horizontal.3")
                }
                Button { selection = .regularity } label: {
                    overviewLabel("Wertungsprüfung", subtitle: "Schnittplan und Startzeit", icon: "stopwatch")
                }.foregroundStyle(.primary)
                Button { selection = .route } label: {
                    overviewLabel("Route und Fahrten", subtitle: "Roadbook, Strecken und GPX-Export", icon: "map")
                }.foregroundStyle(.primary)
            }

            Section("Fahrzeug") {
                LabeledContent("Profil", value: session.data.settings.profile.name)
                LabeledContent("Kalibrierfaktor", value: RallyFormat.decimal(session.factor, digits: 5))
            }

            if let notice = session.notice {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Label(notice, systemImage: "checkmark.circle")
                            .font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        Button { session.notice = nil } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44)
                        }.buttonStyle(.borderless).accessibilityLabel("Hinweis schließen")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("RallyTrip")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "gearshape").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Einstellungen")
            }
        }
    }

    private func overviewLabel(_ title: String, subtitle: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }.padding(.vertical, 6)
        } icon: { Image(systemName: icon).foregroundStyle(.tint) }
    }
}
