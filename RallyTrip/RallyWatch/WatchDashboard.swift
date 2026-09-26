import SwiftUI

struct WatchDashboard: View {
    @EnvironmentObject private var connection: WatchConnection

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                WatchConnectionStatus()
                if let snapshot = connection.snapshot {
                    if snapshot.isDemo { Label("Demo", systemImage: "testtube.2").font(.caption).foregroundStyle(.orange) }
                    VStack(spacing: 4) {
                        Text(snapshot.stageName).font(.headline)
                        if let countdown = snapshot.countdown, connection.fresh {
                            Text("Start in").font(.caption).foregroundStyle(.secondary)
                            Text("\(Int(ceil(countdown))) s").font(.system(.largeTitle, design: .rounded)).monospacedDigit()
                        } else {
                            Text("Zeitabweichung").font(.caption).foregroundStyle(.secondary)
                            Text(deviation(snapshot)).font(.system(.largeTitle, design: .rounded, weight: .semibold))
                                .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                            Text(pace(snapshot)).font(.headline)
                                .foregroundStyle(paceColor(snapshot))
                        }
                    }.accessibilityElement(children: .combine)

                    LabeledContent(connection.fresh ? "Total" : "Total · letzter Stand", value: "\(WatchFormat.kilometers(snapshot.totalMeters)) km")
                        .font(.caption).monospacedDigit()

                    if snapshot.state == .ready {
                        Button { connection.send(.startTrip) } label: {
                            Label("Fahrt starten", systemImage: "play.fill").frame(minHeight: 44)
                        }.buttonStyle(.borderedProminent)
                            .disabled(!connection.canSend || !snapshot.canStartTrip)
                    }
                    if !snapshot.stageActive && snapshot.state != .scheduled {
                        Button { connection.send(.startStage) } label: {
                            Label("WP starten", systemImage: "flag.checkered").frame(minHeight: 44)
                        }.buttonStyle(.borderedProminent)
                            .disabled(!connection.canSend || !snapshot.canStartStage)
                    }
                    NavigationLink { WatchCorrectionView() } label: {
                        Label("Korrektur", systemImage: "plusminus").frame(minHeight: 44)
                    }
                    if snapshot.calibrationActive {
                        Text("Kalibrierung läuft. Start und Korrektur am iPhone freigeben.").font(.caption)
                    }
                    Text(snapshot.gpsStatus).font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("RallyTrip auf dem gekoppelten iPhone öffnen.")
                        .font(.callout).multilineTextAlignment(.center)
                    Button("Verbinden") { connection.refresh() }.frame(minHeight: 44)
                }
                WatchCommandFeedback()
            }.padding(.horizontal, 4)
        }.navigationTitle("RallyTrip")
    }

    private func deviation(_ snapshot: WatchSnapshot) -> String {
        guard connection.fresh, let seconds = snapshot.deviationSeconds else { return "— s" }
        return "\(seconds < 0 ? "−" : "+")\(WatchFormat.decimal(abs(seconds), digits: 1)) s"
    }
    private func pace(_ snapshot: WatchSnapshot) -> String {
        guard connection.fresh else { return "Anzeige veraltet" }
        if snapshot.state == .paused { return "Messung pausiert" }
        guard snapshot.stageActive else { return "Prüfung bereit" }
        guard let delta = snapshot.deviationSeconds else { return "GPS prüfen" }
        return abs(delta) <= 0.5 ? "Im Takt" : delta > 0 ? "Zu spät" : "Zu früh"
    }
    private func paceColor(_ snapshot: WatchSnapshot) -> Color {
        guard connection.fresh, let delta = snapshot.deviationSeconds else { return .secondary }
        return abs(delta) <= 0.5 ? .green : delta > 0 ? .orange : .cyan
    }
}

struct WatchCorrectionView: View {
    @EnvironmentObject private var connection: WatchConnection
    @State private var crownMeters = 0.0
    @State private var submittedCommand: UUID?
    @FocusState private var crownFocused: Bool

    private var canEdit: Bool { connection.canSend && connection.snapshot?.canCorrect == true }
    private var correction: Double { crownMeters.rounded() }
    private var correctionLabel: String {
        "\(correction > 0 ? "+" : correction < 0 ? "−" : "")\(Int(abs(correction))) m"
    }
    private var crownBinding: Binding<Double> {
        Binding(get: { crownMeters }, set: { value in
            guard canEdit, value.isFinite else { return }
            crownMeters = min(100, max(-100, value))
        })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                WatchConnectionStatus()
                if let snapshot = connection.snapshot {
                    Text(connection.fresh ? "Total" : "Total · letzter Stand").font(.caption).foregroundStyle(.secondary)
                    Text("\(WatchFormat.kilometers(snapshot.totalMeters)) km")
                        .font(.system(.title2, design: .rounded)).monospacedDigit()
                        .minimumScaleFactor(0.5).lineLimit(1)
                    VStack(spacing: 4) {
                        Text("Krone drehen").font(.caption).foregroundStyle(.secondary)
                        Text(correctionLabel).font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .monospacedDigit().minimumScaleFactor(0.5).lineLimit(1)
                        Text("−100 bis +100 m · 1 m pro Schritt").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 70).padding(8)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                    .focusable(canEdit)
                    .focused($crownFocused)
                    .digitalCrownRotation(crownBinding, from: -100.0, through: 100.0, by: 1.0,
                                          sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
                    .onTapGesture { crownFocused = canEdit }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Streckenkorrektur")
                    .accessibilityValue(correctionLabel)
                    .accessibilityHint("Mit der Digital Crown einstellen. Erst Übernehmen ändert die Strecke.")
                    .accessibilityAdjustableAction { direction in
                        guard canEdit else { return }
                        switch direction {
                        case .increment: crownMeters = min(100, correction + 1)
                        case .decrement: crownMeters = max(-100, correction - 1)
                        @unknown default: break
                        }
                    }
                    Text("Vorschau: \(WatchFormat.kilometers(max(0, snapshot.totalMeters + correction))) km")
                        .font(.caption).monospacedDigit()
                    Button {
                        submittedCommand = connection.send(.correctTotal, correction: correction)
                    } label: {
                        Label("Übernehmen", systemImage: "checkmark").frame(minHeight: 44)
                    }.buttonStyle(.borderedProminent).disabled(!canEdit || correction == 0)
                    Button {
                        crownMeters = 0
                        crownFocused = canEdit
                    } label: {
                        Text("Verwerfen").frame(minHeight: 44)
                    }.disabled(connection.pendingCommand != nil || correction == 0)
                    Text("Ändert Total und die WP-Distanz. Trip bleibt unverändert.")
                        .font(.caption2).foregroundStyle(.secondary)
                    if !snapshot.canCorrect {
                        Text("Zuerst Fahrt starten und Kalibrierung beenden.").font(.caption)
                    }
                }
                WatchCommandFeedback()
            }.padding(.horizontal, 4)
        }.navigationTitle("Korrektur")
            .onAppear { crownFocused = canEdit }
            .onChange(of: canEdit) { _, enabled in crownFocused = enabled }
            .onChange(of: connection.snapshot?.sessionID) { _, _ in
                crownMeters = 0
                submittedCommand = nil
            }
            .onChange(of: connection.lastReply?.commandID) { _, id in
                guard id == submittedCommand, connection.lastReply?.accepted == true else { return }
                crownMeters = 0
                submittedCommand = nil
                crownFocused = canEdit
            }
    }
}

private struct WatchConnectionStatus: View {
    @EnvironmentObject private var connection: WatchConnection
    var body: some View {
        Label(connection.reachable && connection.fresh ? "iPhone verbunden" : "Auf iPhone warten",
              systemImage: connection.reachable && connection.fresh ? "iphone.radiowaves.left.and.right" : "iphone.slash")
            .font(.caption2).foregroundStyle(.secondary)
    }
}

private struct WatchCommandFeedback: View {
    @EnvironmentObject private var connection: WatchConnection
    var body: some View {
        if connection.pendingCommand != nil {
            ProgressView("Warte auf iPhone …").font(.caption)
        } else if let feedback = connection.feedback {
            Text(feedback).font(.caption).multilineTextAlignment(.center)
        }
    }
}

private enum WatchFormat {
    static func decimal(_ value: Double, digits: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: "de_DE")).precision(.fractionLength(digits)).grouping(.never))
    }
    static func kilometers(_ meters: Double) -> String { decimal(meters / 1000, digits: 3) }
}
