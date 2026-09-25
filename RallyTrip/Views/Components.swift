import SwiftUI

enum RallyStyle {
    static let accent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.70, green: 0.88, blue: 0.35, alpha: 1)
            : UIColor(red: 0.22, green: 0.36, blue: 0.08, alpha: 1)
    })
    static let background = Color(uiColor: .systemGroupedBackground)
    static let panel = Color(uiColor: .secondarySystemGroupedBackground)
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
    var accent = false
    var inset: CGFloat = 20
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(inset).frame(maxWidth: .infinity, alignment: .leading)
            .background(RallyStyle.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .leading) {
                if accent {
                    Capsule().fill(.tint).frame(width: 4)
                        .padding(.vertical, 22).accessibilityHidden(true)
                }
            }
            .foregroundStyle(.primary)
    }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text).font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

/// Instruments scale with the system text size and use stable digit widths.
struct MeterValue: View {
    var value: String
    @ScaledMetric(relativeTo: .largeTitle) private var pointSize: CGFloat

    init(_ value: String, size: CGFloat = 66) {
        self.value = value
        _pointSize = ScaledMetric(wrappedValue: size, relativeTo: .largeTitle)
    }

    var body: some View {
        Text(value).font(.system(size: pointSize, weight: .semibold, design: .rounded))
            .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
    }
}

/// Give accessibility text full-width columns instead of squeezing controls.
struct AdaptiveRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        layout { content }
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
                MeterValue(value, size: size)
                Text(unit).font(.subheadline).foregroundStyle(.secondary).fixedSize()
            }
        }.accessibilityElement(children: .combine)
    }
}

struct ActionButton: View {
    @Environment(\.colorScheme) private var colorScheme
    var title: String
    var icon: String
    var prominent = false
    var action: () -> Void
    var body: some View {
        if prominent {
            button.buttonStyle(.borderedProminent)
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private var button: some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.headline)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
        }.controlSize(.large).buttonBorderShape(.roundedRectangle(radius: 16))
    }
}

struct GPSStatus: View {
    @EnvironmentObject private var session: RallySession
    var body: some View {
        AdaptiveRow(spacing: 8) {
            Label(session.gpsStatus, systemImage: session.accuracy == nil ? "location.slash" : "location.fill")
                .frame(maxWidth: .infinity, alignment: .leading)
            if let accuracy = session.accuracy {
                Text("± \(Int(accuracy)) m").monospacedDigit()
                    .accessibilityLabel("GPS-Genauigkeit plus minus \(Int(accuracy)) Meter")
            }
        }.font(.subheadline).foregroundStyle(.secondary).accessibilityElement(children: .combine)
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
                AdaptiveRow {
                    if session.state == .scheduled {
                        ActionButton(title: "Start abbrechen", icon: "xmark") { session.cancelScheduledStart() }
                    } else {
                        ActionButton(title: session.state == .paused ? "Fortsetzen" : "Pause",
                                     icon: session.state == .paused ? "play.fill" : "pause.fill", prominent: true) {
                            session.pauseOrResume()
                        }
                    }
                    ActionButton(title: "Beenden", icon: "stop.fill") { confirmFinish = true }
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
        AdaptiveRow {
            Text(label).frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                TextField("0,000", text: $value).keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing).frame(minWidth: 100, minHeight: 44)
                    .accessibilityLabel("\(label), \(unit)")
                Text(unit).foregroundStyle(.secondary).fixedSize()
            }
        }
    }
}
