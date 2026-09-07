import SwiftUI

enum RallyStyle {
    static let lime = Color(red: 0.79, green: 0.96, blue: 0.28)
    static let background = Color(uiColor: .systemBackground)
    static let panel = Color(uiColor: .secondarySystemBackground)
}

enum RallyFormat {
    static func decimal(_ value: Double, digits: Int = 3) -> String {
        value.formatted(.number.locale(Locale(identifier: "de_DE"))
            .precision(.fractionLength(digits)).grouping(.never))
    }
    static func distance(_ meters: Double) -> String { decimal(meters / 1000) }
    static func duration(_ seconds: Double) -> String {
        let value = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
    }
    static func deviation(_ seconds: Double) -> String {
        (seconds < 0 ? "−" : "+") + decimal(abs(seconds), digits: 2)
    }
    static func parse(_ text: String) -> Double? {
        let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
        return value.flatMap { $0.isFinite ? $0 : nil }
    }
}

struct Panel<Content: View>: View {
    @EnvironmentObject private var session: RallySession
    var accent = false
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(accent ? (session.data.settings.theme == "Nacht" ? Color(red: 0.65, green: 0.23, blue: 0.08) : RallyStyle.lime) : RallyStyle.panel, in: RoundedRectangle(cornerRadius: 24))
            .foregroundStyle(accent ? Color.black : Color.primary)
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text).font(.system(size: 11, weight: .bold, design: .monospaced))
            .tracking(2).foregroundStyle(.secondary)
    }
}

struct Instrument: View {
    var label: String
    var value: String
    var unit: String
    var size: CGFloat = 66
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: label)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value).font(.system(size: size, weight: .semibold, design: .monospaced))
                    .tracking(-3).minimumScaleFactor(0.35).lineLimit(1)
                    .contentTransition(.numericText())
                Text(unit).font(.system(.subheadline, design: .monospaced)).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine)
    }
}

struct ActionButton: View {
    @EnvironmentObject private var session: RallySession
    var title: String
    var icon: String
    var prominent = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(.subheadline, design: .rounded, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(prominent ? (session.data.settings.theme == "Nacht" ? Color.orange : RallyStyle.lime) : RallyStyle.panel, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(prominent ? Color.black : Color.primary)
        }.buttonStyle(.plain)
    }
}

struct GPSStatus: View {
    @EnvironmentObject private var session: RallySession
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(session.accuracy == nil ? Color.orange : Color.green).frame(width: 7, height: 7)
            Text(session.gpsStatus).font(.caption)
            Spacer(minLength: 0)
            if let accuracy = session.accuracy {
                Text("± \(Int(accuracy)) m").font(.system(.caption, design: .monospaced))
            }
        }.foregroundStyle(.secondary).accessibilityElement(children: .combine)
    }
}

struct SessionControls: View {
    @EnvironmentObject private var session: RallySession
    @State private var confirmFinish = false
    var body: some View {
        VStack(spacing: 10) {
            if session.state == .ready {
                ActionButton(title: "Fahrt starten", icon: "play.fill", prominent: true) { session.startTrip() }
            } else {
                HStack(spacing: 12) {
                    if session.state == .scheduled {
                        ActionButton(title: "Start abbrechen", icon: "xmark") { session.cancelScheduledStart() }
                    } else {
                        ActionButton(title: session.state == .paused ? "Fortsetzen" : "Pause",
                                     icon: session.state == .paused ? "play.fill" : "pause.fill") {
                            session.pauseOrResume()
                        }
                    }
                    ActionButton(title: "Beenden", icon: "stop.fill", prominent: true) { confirmFinish = true }
                }
                if session.state == .paused && session.stageActive {
                    Text("Streckenmessung pausiert. Die Prüfungszeit läuft weiter.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .confirmationDialog("Fahrt beenden und speichern?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Beenden & speichern") { session.finish() }
            Button("Weiterfahren", role: .cancel) {}
        }
    }
}

struct NumericField: View {
    var label: String
    @Binding var value: String
    var unit: String
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0,000", text: $value).keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing).frame(maxWidth: 130)
                .accessibilityLabel(label)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}
