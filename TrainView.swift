import SwiftUI
import UIKit

struct TrainView: View {

    @EnvironmentObject private var settings: AppSettings
    @State private var selectedDrill: DrillType? = nil
    @State private var steadySessionActive: Bool = false
    @State private var showBaselineScan: Bool = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Train")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("10 seconds each. One thing at a time.")
                        .font(.system(size: 22))
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

                // ── Baseline Scan card ───────────────────────────────────
                Button { showBaselineScan = true } label: {
                    BaselineScanCard(profile: settings.tremorProfile)
                }
                .buttonStyle(DrillCardButtonStyle())

                // ── Tremor profile badge (once scanned) ──────────────────
                if let profile = settings.tremorProfile {
                    TremorProfileBadge(profile: profile)
                }

                // ── Steady session ───────────────────────────────────────
                Button { steadySessionActive = true } label: {
                    SteadySessionBanner(settings: settings)
                }
                .buttonStyle(DrillCardButtonStyle())

                // Section header
                HStack {
                    Text("Individual Phases")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .textCase(.uppercase)
                        .kerning(0.5)
                    Spacer()
                    if settings.totalSessionCount > 0 {
                        Text("\(settings.drillSessions.count) sessions logged")
                            .font(.system(size: 15))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(.top, 4)

                // Drill cards
                VStack(spacing: 18) {
                    ForEach(DrillType.allCases) { drill in
                        Button { selectedDrill = drill } label: {
                            TrainDrillCard(drill: drill)
                        }
                        .buttonStyle(DrillCardButtonStyle())
                    }
                }

            }
            .padding(.horizontal, 20)
            .padding(.bottom, 48)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .fullScreenCover(item: $selectedDrill) { drill in
            DrillSessionView(type: drill, isSteadySession: false, onNextPhase: nil)
                .environmentObject(settings)
        }
        .fullScreenCover(isPresented: $steadySessionActive) {
            SteadySessionCoordinator()
                .environmentObject(settings)
        }
        .fullScreenCover(isPresented: $showBaselineScan) {
            BaselineScanView()
                .environmentObject(settings)
        }
    }
}

// MARK: - Baseline Scan Card

private struct BaselineScanCard: View {
    let profile: TremorProfile?

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(profile == nil
                          ? Color(red: 0.40, green: 0.33, blue: 0.85)
                          : Color(red: 0.40, green: 0.33, blue: 0.85).opacity(0.12))
                    .frame(width: 76, height: 76)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(profile == nil ? .white : Color(red: 0.40, green: 0.33, blue: 0.85))
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("Tremor Scan")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.textPrimary)
                }

                if let p = profile {
                    Text("Last scan: \(p.formattedDate)")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                    HStack(spacing: 12) {
                        Label(String(format: "%.1f mm", p.amplitudeMM),
                              systemImage: "waveform")
                        Label(String(format: "%.1f Hz", p.dominantFrequencyHz),
                              systemImage: "clock")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)
                } else {
                    Text("Map your tremor profile before training")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                    Text("~60 seconds · 4 phases")
                        .font(.system(size: 15))
                        .foregroundColor(.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
}

// MARK: - Tremor Profile Badge

private struct TremorProfileBadge: View {
    let profile: TremorProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Tremor Profile")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
                .kerning(0.4)

            HStack(spacing: 8) {
                profilePill(
                    value: shakeLabel(profile.amplitudeMM),
                    sub: "Shake",
                    color: amplitudeColor(profile.amplitudeMM)
                )
                profilePill(
                    value: speedLabel(profile.dominantFrequencyHz),
                    sub: "Speed",
                    color: .metricBlue
                )
                profilePill(
                    value: profile.biasLabel,
                    sub: "Direction",
                    color: Color(red: 0.20, green: 0.78, blue: 0.68)
                )
                profilePill(
                    value: staminaLabel(profile.fatigueIncrease),
                    sub: "Stamina",
                    color: fatigueColor(profile.fatigueIncrease)
                )
            }
        }
        .padding(18)
        .background(Color.cardBackground)
        .cornerRadius(18)
    }

    private func profilePill(value: String, sub: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
            Text(sub)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(color.opacity(0.20), lineWidth: 1))
    }

    private func shakeLabel(_ mm: Double) -> String {
        switch mm {
        case ..<0.8: return "Minimal"
        case ..<2.0: return "Mild"
        case ..<4.5: return "Moderate"
        default:     return "Strong"
        }
    }

    private func speedLabel(_ hz: Double) -> String {
        switch hz {
        case ..<3.5: return "Slow"
        case ..<6.0: return "Medium"
        case ..<9.0: return "Fast"
        default:     return "Very Fast"
        }
    }

    private func staminaLabel(_ pct: Double) -> String {
        pct < 12 ? "Steady" : pct < 28 ? "Tires a bit" : "Tires fast"
    }

    private func amplitudeColor(_ mm: Double) -> Color {
        mm < 1.5 ? .metricGreen : mm < 3.5 ? .metricOrange : .metricRed
    }

    private func fatigueColor(_ pct: Double) -> Color {
        pct < 12 ? .metricGreen : pct < 28 ? .metricOrange : .metricRed
    }
}

// MARK: - Steady Session Banner

private struct SteadySessionBanner: View {
    let settings: AppSettings

    private var overallAvg: Int? {
        guard !settings.drillSessions.isEmpty else { return nil }
        let all = settings.drillSessions.map { $0.asAvgStability }
        return all.reduce(0, +) / all.count
    }

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: 64, height: 64)
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .offset(x: 2)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Steady Session")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text("All 5 phases  ·  ~1 minute  ·  Guided")
                    .font(.system(size: 17))
                    .foregroundColor(.textSecondary)
                if let avg = overallAvg {
                    Text("Avg score: \(avg)%")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.brandPrimary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(UIColor.tertiaryLabel))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .background(Color.cardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.brandPrimary.opacity(0.20), lineWidth: 1.5)
        )
    }
}

// MARK: - Drill Card

struct TrainDrillCard: View {

    let drill: DrillType
    @EnvironmentObject private var settings: AppSettings

    private var bestScore: CGFloat? { settings.bestScore(for: drill) }
    private var completionCount: Int { settings.completionCount(for: drill) }
    private var lastScore: CGFloat? {
        settings.drillSessions
            .filter { $0.drillType == drill }
            .sorted { $0.date < $1.date }
            .last?.score
    }
    private var recentScores: [CGFloat] {
        settings.drillSessions
            .filter { $0.drillType == drill }
            .sorted { $0.date < $1.date }
            .suffix(5)
            .map { $0.score }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(drill.accentColor.opacity(0.12))
                        .frame(width: 84, height: 84)
                    Image(systemName: drill.systemIcon)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundColor(drill.accentColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 5) {
                    Text(drill.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text(drill.subtitle)
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                    Text(drill.motorSkillLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(drill.accentColor)
                        .padding(.top, 2)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    if let best = bestScore {
                        Text("\(Int(best * 100))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(drill.accentColor)
                        Text("best")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    } else {
                        Text("Start")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(drill.accentColor)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 22)

            // Stat badges row — only shown after ≥1 session
            if completionCount > 0 {
                Divider().padding(.horizontal, 20)

                HStack(spacing: 0) {
                    statBadge(value: "\(completionCount)", label: "sessions", color: .textSecondary)
                    Divider().frame(height: 28)

                    if let best = bestScore {
                        statBadge(value: "\(Int(best * 100))%", label: "best", color: drill.accentColor)
                        Divider().frame(height: 28)
                    }

                    if let last = lastScore {
                        statBadge(value: "\(Int(last * 100))%", label: "last",
                                  color: trendColor(last: last, best: bestScore))
                        if recentScores.count >= 2 {
                            Divider().frame(height: 28)
                        }
                    }

                    if recentScores.count >= 2 {
                        let delta = recentScores.last! - recentScores.first!
                        statBadge(
                            value: delta >= 0 ? "+\(Int(delta * 100))%" : "\(Int(delta * 100))%",
                            label: "trend",
                            color: delta >= 0 ? .metricGreen : .metricOrange
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 3)
    }

    private func statBadge(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private func trendColor(last: CGFloat, best: CGFloat?) -> Color {
        guard let best = best else { return .textSecondary }
        return last >= best * 0.9 ? .metricGreen : .metricOrange
    }
}

// MARK: - Sparkline

struct SparklineView: View {
    let scores: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minS = scores.min() ?? 0
            let maxS = scores.max() ?? 1
            let range = max(maxS - minS, 0.05)

            Path { path in
                for (i, score) in scores.enumerated() {
                    let x = CGFloat(i) / CGFloat(scores.count - 1) * w
                    let y = h - ((score - minS) / range) * h
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else       { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Pencil Status Banner

struct PencilStatusBanner: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isConnected ? "pencil.tip" : "pencil.tip.crop.circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isConnected ? .brandPrimary : .textSecondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(isConnected ? "Apple Pencil Active" : "Apple Pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(isConnected
                     ? "Full precision and pressure data available."
                     : "Connect Apple Pencil for full precision and pressure data.")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .lineSpacing(2)
            }

            Spacer()

            if isConnected {
                Circle()
                    .fill(Color.metricGreen)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(16)
        .background(isConnected
                    ? Color.brandPrimary.opacity(0.07)
                    : Color(UIColor.tertiarySystemFill))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isConnected ? Color.brandPrimary.opacity(0.20) : Color.clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.3), value: isConnected)
    }
}

// MARK: - Pencil Detector

struct PencilDetector: UIViewRepresentable {
    @Binding var isConnected: Bool

    func makeUIView(context: Context) -> PencilDetectorView {
        let v = PencilDetectorView()
        v.onPencilStateChanged = { connected in
            DispatchQueue.main.async { isConnected = connected }
        }
        return v
    }

    func updateUIView(_ uiView: PencilDetectorView, context: Context) {}
}

final class PencilDetectorView: UIView, UIPencilInteractionDelegate {

    var onPencilStateChanged: ((Bool) -> Void)?
    nonisolated(unsafe) private var pencilActivityTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .clear

        let interaction = UIPencilInteraction()
        interaction.delegate = self
        addInteraction(interaction)

        NotificationCenter.default.addObserver(
            self, selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) { markPencilActive() }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let touches = event?.allTouches, touches.contains(where: { $0.type == .pencil }) {
            markPencilActive()
        }
        return nil
    }

    @objc private func appBecameActive() {}

    private func markPencilActive() {
        onPencilStateChanged?(true)
        pencilActivityTimer?.invalidate()
        pencilActivityTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
            self?.onPencilStateChanged?(false)
        }
    }

    deinit {
        pencilActivityTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Button Style

struct DrillCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Steady Session Coordinator

struct SteadySessionCoordinator: View {

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss

    private let sequence = DrillType.allCases
    @State private var currentIndex: Int = 0
    @State private var isDone: Bool = false

    var currentDrill: DrillType { sequence[currentIndex] }

    var body: some View {
        if isDone {
            steadyCompleteView
        } else {
            DrillSessionView(
                type: currentDrill,
                isSteadySession: true,
                onNextPhase: {
                    if currentIndex < sequence.count - 1 {
                        currentIndex += 1
                    } else {
                        isDone = true
                    }
                }
            )
            .environmentObject(settings)
            .id(currentIndex)
        }
    }

    var steadyCompleteView: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.brandPrimary.opacity(0.12), lineWidth: 14)
                    .frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: 1.0)
                    .stroke(Color.brandPrimary,
                            style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.brandPrimary)
            }
            .padding(.bottom, 32)

            Text("Session Complete")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.textPrimary)
                .padding(.bottom, 10)

            Text("All 5 phases done.\nEvery session builds control.")
                .font(.system(size: 19))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)

            let todayScores = settings.drillSessions
                .filter { Calendar.current.isDateInToday($0.date) }
                .sorted { $0.date < $1.date }

            if !todayScores.isEmpty {
                HStack(spacing: 8) {
                    ForEach(todayScores.prefix(5)) { session in
                        VStack(spacing: 4) {
                            Text("\(session.asAvgStability)%")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.brandPrimary)
                            Text(session.drillType.title.components(separatedBy: " ").first ?? "")
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.brandPrimary.opacity(0.07))
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.top, 28)
            }

            Spacer()

            Button { dismiss() } label: {
                Text("Back to Train")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity).frame(height: 60)
                    .background(Color.brandPrimary).cornerRadius(16)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 48)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}
