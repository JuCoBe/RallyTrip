import SwiftUI
import MapKit
import UniformTypeIdentifiers

struct TrackMap: View {
    let paths: [[GPSPoint]]
    var body: some View {
        Map {
            ForEach(Array(paths.enumerated()), id: \.offset) { _, points in
                if points.count >= 2 {
                    MapPolyline(coordinates: points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
                        .stroke(.orange, lineWidth: 5)
                }
            }
            if let first = paths.first?.first {
                Marker("Start", systemImage: "flag", coordinate: CLLocationCoordinate2D(latitude: first.latitude, longitude: first.longitude))
                    .tint(.green)
            }
            if let last = paths.last?.last {
                Marker("Letzter Messpunkt", systemImage: "location.fill", coordinate: CLLocationCoordinate2D(latitude: last.latitude, longitude: last.longitude))
                    .tint(.orange)
            }
        }.mapStyle(.standard(elevation: .flat))
            .mapControls { MapCompass(); MapScaleView() }
            .overlay {
                if paths.allSatisfy(\.isEmpty) {
                    ContentUnavailableView("Noch keine Strecke", systemImage: "map",
                                           description: Text("Starte eine Fahrt mit GPS oder im Demo-Modus."))
                        .background(.regularMaterial)
                }
            }
    }
}

struct RouteView: View {
    @EnvironmentObject private var session: RallySession
    @State private var showRoadbook = false
    var body: some View {
        List {
            Section {
                TrackMap(paths: session.paths).frame(height: 270)
                    .clipShape(RoundedRectangle(cornerRadius: 18)).listRowInsets(EdgeInsets())
                GPSStatus()
            }
            Section {
                Button("Roadbook bearbeiten", systemImage: "square.and.pencil") { showRoadbook = true }
                if session.data.settings.roadbook.isEmpty {
                    Text("Lege Kilometerpunkte mit Richtung und Hinweis an.").foregroundStyle(.secondary)
                }
                ForEach(session.data.settings.roadbook.sorted { $0.meters < $1.meters }) { point in
                    HStack(spacing: 16) {
                        Image(systemName: point.symbol).font(.title2).frame(width: 28)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(point.instruction)
                            Text("\(RallyFormat.distance(point.meters)) km").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if session.meter.total >= point.meters && session.busy {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                    }
                }
            } header: { Text("Roadbook") }
            Section("Gespeicherte Fahrten · \(session.data.rides.count)") {
                if session.data.rides.isEmpty {
                    Text("Beendete Fahrten erscheinen hier mit ihrer GPS-Strecke.").foregroundStyle(.secondary)
                }
                ForEach(session.data.rides) { ride in
                    NavigationLink { RideDetailView(ride: ride) } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(ride.name).font(.headline)
                                if ride.isDemo { Text("DEMO").font(.caption2).foregroundStyle(.orange) }
                            }
                            Text(ride.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            Text("\(RallyFormat.distance(ride.totalMeters)) km · \(RallyFormat.duration(ride.elapsed))")
                                .font(.system(.subheadline, design: .monospaced))
                        }.padding(.vertical, 4)
                    }
                }.onDelete(perform: session.deleteRides)
            }
        }.navigationTitle("Route / Roadbook").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .sheet(isPresented: $showRoadbook) { RoadbookEditor() }
    }
}

struct RideDetailView: View {
    let ride: SavedRide
    @State private var showExporter = false
    @State private var exportError: String?
    var body: some View {
        List {
            TrackMap(paths: ride.paths).frame(height: 340).listRowInsets(EdgeInsets())
            Section("Fahrt") {
                LabeledContent("Datum", value: ride.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Total", value: "\(RallyFormat.distance(ride.totalMeters)) km")
                LabeledContent("Fahrtzeit ohne Pausen", value: RallyFormat.duration(ride.elapsed))
                LabeledContent("GPS-Rohdistanz", value: "\(RallyFormat.distance(ride.rawMeters)) km")
                LabeledContent("Kalibrierfaktor", value: RallyFormat.decimal(ride.calibrationFactor, digits: 5))
                if let deviation = ride.finalDeviation {
                    LabeledContent("Letzte WP-Abweichung", value: "\(RallyFormat.deviation(deviation)) s")
                }
                if ride.isDemo { Label("Simulierte Fahrt", systemImage: "testtube.2").foregroundStyle(.orange) }
            }
            Section {
                Button("GPS-Strecke als GPX exportieren", systemImage: "square.and.arrow.up") { showExporter = true }
                    .disabled(ride.paths.allSatisfy(\.isEmpty))
            } footer: { Text("GPX enthält die gemessenen GPS-Punkte. Kalibrierung und manuelle Kilometerkorrekturen verändern die Koordinaten nicht.") }
        }.navigationTitle(ride.name).navigationBarTitleDisplayMode(.inline)
            .fileExporter(isPresented: $showExporter, document: GPXDocument(ride: ride),
                          contentType: .rallyGPX, defaultFilename: "RallyTrip-\(ride.startedAt.formatted(.iso8601.year().month().day())).gpx") { result in
                if case .failure(let error) = result { exportError = error.localizedDescription }
            }
            .alert("Export fehlgeschlagen", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
    }
}

extension UTType {
    static let rallyGPX = UTType(exportedAs: "de.rallytrip.gpx", conformingTo: .xml)
}

struct GPXDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.rallyGPX] }
    var text: String
    init(ride: SavedRide) {
        let escaped = ride.name.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        let segments = ride.paths.filter { !$0.isEmpty }.map { points in
            "<trkseg>\n" + points.map { point in
                "<trkpt lat=\"\(point.latitude)\" lon=\"\(point.longitude)\"><ele>\(point.altitude)</ele><time>\(point.timestamp.ISO8601Format())</time></trkpt>"
            }.joined(separator: "\n") + "\n</trkseg>"
        }.joined(separator: "\n")
        text = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx version=\"1.1\" creator=\"RallyTrip\" xmlns=\"http://www.topografix.com/GPX/1/1\"><trk><name>\(escaped)</name>\(segments)</trk></gpx>"
    }
    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

struct RoadbookEditor: View {
    @EnvironmentObject private var session: RallySession
    @Environment(\.dismiss) private var dismiss
    @State private var points: [RoadbookPoint] = []
    @State private var km = ""
    @State private var instruction = ""
    @State private var symbol = "arrow.up"
    private let symbols = [("arrow.up", "Geradeaus"), ("arrow.turn.up.left", "Links"),
                           ("arrow.turn.up.right", "Rechts"), ("arrow.uturn.down", "Wenden"), ("flag.checkered", "Ziel")]

    var body: some View {
        NavigationStack {
            Form {
                Section("Neuer Punkt") {
                    NumericField(label: "Bei Kilometer", value: $km, unit: "km")
                    TextField("Hinweis, z. B. links an der Kirche", text: $instruction)
                    Picker("Richtung", selection: $symbol) {
                        ForEach(symbols, id: \.0) { value in Label(value.1, systemImage: value.0).tag(value.0) }
                    }
                    Button("Punkt hinzufügen") {
                        guard let distance = RallyFormat.parse(km), distance >= 0 else { return }
                        points.append(RoadbookPoint(meters: distance * 1000,
                                                    instruction: instruction.trimmingCharacters(in: .whitespaces), symbol: symbol))
                        points.sort { $0.meters < $1.meters }; km = ""; instruction = ""
                    }.disabled((RallyFormat.parse(km) ?? -1) < 0 || instruction.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section("Punkte · zum Löschen wischen") {
                    ForEach(points) { point in
                        Label("\(RallyFormat.distance(point.meters)) · \(point.instruction)", systemImage: point.symbol)
                    }.onDelete { points.remove(atOffsets: $0) }
                }
            }.navigationTitle("Roadbook")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") { session.data.settings.roadbook = points; session.persist(); dismiss() }
                    }
                }.onAppear { points = session.data.settings.roadbook }
        }
    }
}
