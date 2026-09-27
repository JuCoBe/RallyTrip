import SwiftUI

/// Retains safe areas and a reachable exit in portrait, landscape and large text sizes.
struct DrivingFullscreen: ViewModifier {
    @Binding var enabled: Bool

    func body(content: Content) -> some View {
        content
            .toolbar(enabled ? .hidden : .visible, for: .navigationBar, .tabBar)
            .statusBarHidden(enabled)
            .safeAreaInset(edge: .top, spacing: 0) {
                if enabled {
                    HStack {
                        Spacer()
                        Button { enabled = false } label: {
                            Label("Vollbild beenden", systemImage: "arrow.down.right.and.arrow.up.left")
                                .font(.headline).padding(.horizontal, 16).frame(minHeight: 44)
                        }.buttonStyle(.bordered)
                    }.padding(.horizontal).background(RallyStyle.background)
                }
            }
    }
}

struct OptionalNameField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        TextField("Name (optional)", text: $text, prompt: Text(placeholder))
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done).frame(minHeight: 44)
            .accessibilityLabel("Name, optional. Ohne Eingabe: \(placeholder)")
    }
}

/// Shared selection and rename controls; names never act as storage keys.
struct NamedCircuitMenu<Value: Codable>: View {
    let items: [NamedCircuitItem<Value>]
    let selectedID: UUID?
    let kind: String
    let canSelect: Bool
    let select: (UUID) -> Bool
    let rename: (UUID, String) -> Bool
    var delete: ((UUID) -> Bool)? = nil
    @State private var editing: NamedCircuitItem<Value>?
    @State private var deleting: NamedCircuitItem<Value>?

    var body: some View {
        Menu {
            Section("Auswählen") {
                ForEach(items) { item in
                    Button { _ = select(item.id) } label: {
                        Label(item.displayName(kind), systemImage: item.id == selectedID ? "checkmark.circle.fill" : "circle")
                    }.disabled(!canSelect)
                }
            }
            Section("Umbenennen") {
                ForEach(items) { item in
                    Button(item.displayName(kind), systemImage: "pencil") { editing = item }
                }
            }
            if delete != nil {
                Section("Löschen") {
                    ForEach(items) { item in
                        Button(item.displayName(kind), role: .destructive) { deleting = item }
                            .disabled(!canSelect)
                    }
                }
            }
        } label: {
            Label("\(kind): \(items.first { $0.id == selectedID }?.displayName(kind) ?? "Auswählen")", systemImage: "chevron.up.chevron.down")
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }.buttonStyle(.bordered)
            .sheet(item: $editing) { item in
                CircuitNameEditor(title: "\(kind) umbenennen", name: item.name ?? "",
                                  placeholder: "\(kind) \(item.number)") { name in rename(item.id, name) }
            }
            .confirmationDialog("\(deleting?.displayName(kind) ?? kind) löschen? Ist diese Referenz aktiv, werden auch die aktuellen Vergleichsrunden gelöscht.",
                                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    if let item = deleting { _ = delete?(item.id) }
                    deleting = nil
                }
            }
    }
}

private struct CircuitNameEditor: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State var name: String
    let placeholder: String
    let save: (String) -> Bool

    var body: some View {
        NavigationStack {
            Form {
                OptionalNameField(placeholder: placeholder, text: $name)
                Text("Leer lassen, um „\(placeholder)“ zu verwenden.").font(.caption)
            }.navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Speichern") { if save(name) { dismiss() } }
                    }
                }
        }.presentationDetents([.medium, .large])
    }
}

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
    @ScaledMetric(relativeTo: .largeTitle) private var pointSize: CGFloat = 66

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

struct PaceLEDs: View {
    let deviation: Double?
    var title = "Tempo gegenüber Referenzrunde"
    let status: String
    var allowsTest = false
    @State private var testing = false
    private var selected: Int? { PaceLED.position(deviation: deviation) }
    var body: some View {
        VStack(spacing: 16) {
                Text(title).font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    ForEach(-4...4, id: \.self) { index in
                        let color: Color = index == 0 ? .green : index < 0 ? .cyan : .orange
                        let lit = testing || selected.map { value in
                            value == 0 ? index == 0 : (value < 0 ? (value...(-1)).contains(index) : (1...value).contains(index))
                        } == true
                        Circle()
                            .fill(color.opacity(lit ? 1 : 0.22))
                            .overlay(Circle().stroke(color.opacity(lit ? 1 : 0.6), lineWidth: lit ? 3 : 1))
                            .overlay(Circle().fill(.white.opacity(lit ? 0.8 : 0)).padding(10))
                            .shadow(color: color.opacity(lit ? 0.9 : 0), radius: 10)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }.frame(maxWidth: 660).padding(.vertical, 12).accessibilityHidden(true)
                HStack {
                    Text("← Zu schnell").foregroundStyle(.cyan)
                    Spacer()
                    Text("±0,5 s").foregroundStyle(.green)
                    Spacer()
                    Text("Zu langsam →").foregroundStyle(.orange)
                }.font(.caption.bold())
                if testing {
                    Text("Lampentest · keine Messwerte").font(.headline)
                } else if let deviation, deviation.isFinite {
                    Text(abs(deviation) <= 0.5 ? "Im Takt" : deviation < 0 ? "Zu schnell · voraus" : "Zu langsam · zurück")
                        .font(.headline)
                    MeterValue("\(RallyFormat.deviation(deviation)) s", size: 48)
                } else {
                    Text(status).font(.subheadline)
                    Text("LEDs bereit · noch kein Zeitvergleich").font(.caption)
                }
                if allowsTest {
                    Button(testing ? "Lampentest beenden" : "LED-Lampentest") { testing.toggle() }
                        .buttonStyle(.bordered).tint(.white).frame(minHeight: 44)
                }
        }.padding(20).frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background(Color(white: 0.055), in: RoundedRectangle(cornerRadius: 20))
            .onChange(of: allowsTest) { _, allowed in if !allowed { testing = false } }
    }
}
