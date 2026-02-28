import SwiftUI
import PencilKit

// MARK: - Baseline Scan View
// 4-phase tremor analysis: Hold Still → Spiral → Straight Line → Tap Targets
// Produces a TremorProfile stored in AppSettings.

@MainActor
struct BaselineScanView: View {

    @EnvironmentObject var settings: AppSettings
    @Environment(\.dismiss) var dismiss

    // Phase control
    enum ScanPhase: Int, CaseIterable {
        case intro
        case holdStill     // Phase 1 — 10s hold, dothold-style
        case spiral        // Phase 2 — draw spiral freehand
        case straightLine  // Phase 3 — draw straight line
        case tapTargets    // Phase 4 — tap 6 targets
        case results
    }

    @State private var phase: ScanPhase = .intro
    @State private var phaseProgress: CGFloat = 0
    @State private var phaseTimer: Timer?
    @State private var countdown: Int = 3
    @State private var countdownTimer: Timer?
    @State private var showCountdown = false

    // Hold Still data
    @State private var holdPoints: [CGPoint] = []
    @State private var holdTimer: Timer?
    @State private var holdCanvasView = PKCanvasView()

    // Spiral / Line canvas
    @State private var drawCanvasView = PKCanvasView()
    @State private var drawingDone = false

    // Tap targets
    @State private var tapTargets: [CGPoint] = []
    @State private var tappedTargets: [CGPoint] = []
    @State private var currentTargetIndex = 0
    @State private var tapPoints: [CGPoint] = []   // actual tap locations
    @State private var targetPulse: Bool = false

    // Collected raw metrics
    @State private var holdAmplitude: CGFloat = 0
    @State private var holdFrequency: CGFloat = 0
    @State private var spiralAmplitude: CGFloat = 0
    @State private var spiralPressureVar: CGFloat = 0
    @State private var lineAmplitude: CGFloat = 0
    @State private var lineHorizBias: CGFloat = 0.5
    @State private var tapDeviation: CGFloat = 0

    // Computed profile
    @State private var profile: TremorProfile? = nil

    // Animation
    @State private var resultAppeared = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            switch phase {
            case .intro:        introView
            case .holdStill:    holdStillView
            case .spiral:       drawPhaseView(title: "Draw a Spiral",
                                              instruction: "Slow outward spiral from centre. Lift when done.",
                                              icon: "arrow.clockwise")
            case .straightLine: drawPhaseView(title: "Draw a Straight Line",
                                              instruction: "One slow line left to right. Lift when done.",
                                              icon: "minus")
            case .tapTargets:   tapTargetView
            case .results:      resultsView
            }

            // Countdown overlay
            if showCountdown {
                countdownOverlay
            }
        }
        .onDisappear { stopAllTimers() }
    }

    // MARK: - Intro

    private var introView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.40, green: 0.33, blue: 0.85).opacity(0.15))
                    .frame(width: 110, height: 110)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundColor(Color(red: 0.72, green: 0.55, blue: 1.0))
            }
            .padding(.bottom, 36)

            Text("Tremor Scan")
                .font(.system(size: 38, weight: .bold))
                .foregroundColor(.textPrimary)
                .padding(.bottom, 12)

            Text("4 quick tests. About 60 seconds.\nWe'll map your tremor signature.")
                .font(.system(size: 18))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 40)
                .padding(.bottom, 48)

            // Phase preview pills
            HStack(spacing: 10) {
                ForEach(["Hold", "Spiral", "Line", "Tap"], id: \.self) { label in
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.72, green: 0.55, blue: 1.0))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.40, green: 0.33, blue: 0.85).opacity(0.18))
                        .cornerRadius(20)
                        .overlay(Capsule()
                            .stroke(Color(red: 0.72, green: 0.55, blue: 1.0).opacity(0.25), lineWidth: 1))
                }
            }
            .padding(.bottom, 56)

            Spacer()

            VStack(spacing: 14) {
                Button { beginScan() } label: {
                    Text("Begin Scan")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(Color(red: 0.40, green: 0.33, blue: 0.85))
                        .cornerRadius(16)
                }

                Button { dismiss() } label: {
                    Text("Maybe later")
                        .font(.system(size: 16))
                        .foregroundColor(.textSecondary)
                }
            }
            .padding(.horizontal, 36)
            .padding(.bottom, 52)
        }
    }

    // MARK: - Hold Still Phase

    private var holdStillView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                phaseHeader(number: 1, title: "Hold Still", total: 4)

                Spacer()

                ZStack {
                    // Background rings
                    ForEach([90, 60, 36, 16] as [CGFloat], id: \.self) { r in
                        Circle()
                            .stroke(Color(red: 0.72, green: 0.55, blue: 1.0)
                                        .opacity(r == 36 ? 0.28 : 0.10),
                                    lineWidth: r == 36 ? 1.5 : 1)
                            .frame(width: r * 2, height: r * 2)
                    }

                    // Scatter canvas — dots positioned relative to ZStack centre
                    Canvas { ctx, size in
                        let cx = size.width / 2, cy = size.height / 2
                        let recent = Array(holdPoints.suffix(200))
                        guard recent.count > 1 else { return }
                        let centX = recent.map { $0.x }.reduce(0, +) / CGFloat(recent.count)
                        let centY = recent.map { $0.y }.reduce(0, +) / CGFloat(recent.count)
                        for (i, pt) in recent.enumerated() {
                            let age = CGFloat(i) / CGFloat(recent.count)
                            let dx = (pt.x - centX) * 4.5
                            let dy = (pt.y - centY) * 4.5
                            let r: CGFloat = 2.5
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: cx+dx-r, y: cy+dy-r, width: r*2, height: r*2)),
                                with: .color(Color(red: 0.72, green: 0.55, blue: 1.0).opacity(0.22 + age * 0.65))
                            )
                        }
                    }
                    .frame(width: 200, height: 200)
                    .allowsHitTesting(false)

                    // Target dot with glow
                    Circle()
                        .fill(Color(red: 0.72, green: 0.55, blue: 1.0))
                        .frame(width: 14, height: 14)
                        .shadow(color: Color(red: 0.72, green: 0.55, blue: 1.0).opacity(0.8), radius: 8)
                }
                .frame(width: 200, height: 200)

                // Live readout chip
                Group {
                    if holdAmplitude > 0 {
                        HStack(spacing: 20) {
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f mm", holdAmplitude * 0.4))
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(red: 0.72, green: 0.55, blue: 1.0))
                                Text("amplitude")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textSecondary)
                            }
                            Rectangle().fill(Color(UIColor.separator)).frame(width: 1, height: 30)
                            VStack(spacing: 2) {
                                Text(String(format: "%.1f Hz", holdFrequency * 0.5))
                                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                                    .foregroundColor(.textPrimary)
                                Text("frequency")
                                    .font(.system(size: 11))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding(.horizontal, 26).padding(.vertical, 13)
                        .background(Color(UIColor.tertiarySystemFill))
                        .cornerRadius(14)
                        .transition(.opacity.combined(with: .scale(scale: 0.93)))
                    } else {
                        Text("Scanning…")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.textSecondary)
                    }
                }
                .frame(height: 68)
                .padding(.top, 28)
                .animation(.easeInOut(duration: 0.3), value: holdAmplitude > 0)

                Spacer()

                VStack(spacing: 10) {
                    Text("Place your Apple Pencil tip on the dot and hold still")
                        .font(.system(size: 15))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    progressBar.padding(.horizontal, 36)
                }
                .padding(.bottom, 48)
            }
            .overlay(
                VStack(spacing: 0) {
                    // Reserve space for the header — touch capture must NOT cover the X button
                    Color.clear
                        .frame(height: 140)
                        .allowsHitTesting(false)
                    // Touch capture only covers the drawing area below the header
                    ScanTouchCapture(onTouchMoved: { pt in
                        holdPoints.append(pt)
                        if holdPoints.count > 10 {
                            let recent = holdPoints.suffix(30).map { $0 }
                            holdAmplitude = computeSpread(recent)
                            holdFrequency = computeFrequency(recent)
                        }
                    })
                }
            )
        }
    }

    // MARK: - Draw Phase (Spiral + Line)
    // Ghost guide shown on canvas so user knows exactly what to trace

    private func drawPhaseView(title: String, instruction: String, icon: String) -> some View {
        let isSpiral = phase == .spiral
        return VStack(spacing: 0) {
            phaseHeader(number: isSpiral ? 2 : 3, title: title, total: 4)

            ZStack {
                // Canvas background — keep warm off-white so ink is visible
                Color.cardBackground.cornerRadius(20)

                // Ghost guide drawn in Canvas (never interferes with PKCanvasView)
                Canvas { ctx, size in
                    if isSpiral {
                        drawGhostSpiral(ctx: ctx, size: size)
                    } else {
                        drawGhostLine(ctx: ctx, size: size)
                    }
                }
                .cornerRadius(20)
                .allowsHitTesting(false)

                SteadyCanvas(
                    canvasView: $drawCanvasView,
                    smoothingEnabled: false,
                    shapeRecognitionEnabled: false,
                    snapManager: ShapeSnapManager(),
                    assistLevel: 0,
                    showGhostOverlay: false,
                    showToolPicker: false,
                    onStrokeAdded: { handleDrawStroke() }
                )
                .cornerRadius(20)
                .background(Color.clear)

                // Instruction overlay — shown only before drawing starts
                if !drawingDone {
                    VStack {
                        // Top label with arrow pointing at guide
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(isSpiral
                                 ? "Trace the spiral — start at centre, go outward"
                                 : "Trace the line — draw slowly left to right")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(Color(red: 0.55, green: 0.40, blue: 0.80).opacity(0.75))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color(red: 0.55, green: 0.40, blue: 0.80).opacity(0.08))
                        .cornerRadius(20)
                        .padding(.top, 18)

                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .frame(maxHeight: .infinity)

            if drawingDone {
                Button { advanceFromDraw() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Looks good →")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.textPrimary)
                    .frame(maxWidth: .infinity).frame(height: 54)
                    .background(Color(red: 0.40, green: 0.33, blue: 0.85))
                    .cornerRadius(14)
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 48)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text("Draw directly on the canvas above")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .padding(.bottom, 48)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: drawingDone)
    }

    // Ghost spiral — Archimedean, centre to edge, dashed
    private func drawGhostSpiral(ctx: GraphicsContext, size: CGSize) {
        let cx = size.width / 2, cy = size.height / 2
        let maxR = min(size.width, size.height) * 0.40
        let turns = 3.0
        let steps = 300
        var path = Path()
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let angle = t * CGFloat(turns) * 2 * .pi - .pi / 2
            let r = t * maxR
            let x = cx + cos(angle) * r
            let y = cy + sin(angle) * r
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        ctx.stroke(path,
                   with: .color(Color(red: 0.55, green: 0.40, blue: 0.80).opacity(0.22)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [8, 6]))

        // Start dot
        ctx.fill(Path(ellipseIn: CGRect(x: cx-5, y: cy-5, width: 10, height: 10)),
                 with: .color(Color(red: 0.55, green: 0.40, blue: 0.80).opacity(0.45)))
    }

    // Ghost straight line — horizontal, centre, dashed
    private func drawGhostLine(ctx: GraphicsContext, size: CGSize) {
        let y = size.height / 2
        let padX: CGFloat = 48
        var path = Path()
        path.move(to: CGPoint(x: padX, y: y))
        path.addLine(to: CGPoint(x: size.width - padX, y: y))
        ctx.stroke(path,
                   with: .color(Color(red: 0.55, green: 0.40, blue: 0.80).opacity(0.22)),
                   style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [10, 7]))

        // Start arrow
        ctx.fill(Path(ellipseIn: CGRect(x: padX - 6, y: y - 6, width: 12, height: 12)),
                 with: .color(Color(red: 0.55, green: 0.40, blue: 0.80).opacity(0.45)))
        ctx.fill(Path(ellipseIn: CGRect(x: size.width - padX - 6, y: y - 6, width: 12, height: 12)),
                 with: .color(Color(red: 0.55, green: 0.40, blue: 0.80).opacity(0.22)))
    }

    // MARK: - Tap Target Phase

    private var tapTargetView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                phaseHeader(number: 4, title: "Tap Targets", total: 4)

                ZStack {
                    // Completed targets — faded with checkmark
                    ForEach(Array(tappedTargets.enumerated()), id: \.offset) { _, pt in
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.40, green: 0.33, blue: 0.85).opacity(0.18))
                                .frame(width: 48, height: 48)
                            Image(systemName: "checkmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color(red: 0.72, green: 0.55, blue: 1.0).opacity(0.6))
                        }
                        .position(pt)
                    }

                    // Active target — large, glowing, pulsing
                    if currentTargetIndex < tapTargets.count {
                        let pt = tapTargets[currentTargetIndex]
                        ZStack {
                            // Outer pulse ring
                            Circle()
                                .stroke(Color(red: 0.72, green: 0.55, blue: 1.0).opacity(0.25), lineWidth: 2)
                                .frame(width: 80, height: 80)
                                .scaleEffect(targetPulse ? 1.2 : 1.0)
                                .opacity(targetPulse ? 0 : 1)
                                .animation(.easeOut(duration: 1.0).repeatForever(autoreverses: false), value: targetPulse)

                            // Main circle
                            Circle()
                                .fill(Color(red: 0.72, green: 0.55, blue: 1.0).opacity(0.18))
                                .frame(width: 60, height: 60)
                            Circle()
                                .stroke(Color(red: 0.72, green: 0.55, blue: 1.0), lineWidth: 2)
                                .frame(width: 60, height: 60)
                                .shadow(color: Color(red: 0.72, green: 0.55, blue: 1.0).opacity(0.5), radius: 8)

                            // Centre dot
                            Circle()
                                .fill(Color(red: 0.72, green: 0.55, blue: 1.0))
                                .frame(width: 12, height: 12)
                                .shadow(color: Color(red: 0.72, green: 0.55, blue: 1.0).opacity(0.8), radius: 4)

                            // Tap label
                            Text("TAP")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(red: 0.72, green: 0.55, blue: 1.0).opacity(0.6))
                                .offset(y: 34)
                        }
                        .position(pt)
                        .id(currentTargetIndex)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                        .onAppear { targetPulse = true }
                    }

                    // Touch capture
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { loc in handleTap(at: loc, geo: geo) }
                }
                .frame(maxHeight: .infinity)
                .onAppear { setupTapTargets(geo: geo) }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentTargetIndex)

                // Progress indicator
                HStack(spacing: 8) {
                    ForEach(0..<(tapTargets.isEmpty ? 6 : tapTargets.count), id: \.self) { i in
                        Circle()
                            .fill(i < currentTargetIndex
                                  ? Color(red: 0.72, green: 0.55, blue: 1.0)
                                  : Color(UIColor.tertiarySystemFill))
                            .frame(width: 8, height: 8)
                            .scaleEffect(i == currentTargetIndex ? 1.3 : 1.0)
                            .animation(.spring(response: 0.3), value: currentTargetIndex)
                    }
                }
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Results

    private var resultsView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── Hero header ──────────────────────────────────────────
                VStack(spacing: 16) {
                    // Big animated icon
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.40, green: 0.33, blue: 0.85).opacity(0.14))
                            .frame(width: 88, height: 88)
                        Circle()
                            .stroke(Color(red: 0.72, green: 0.55, blue: 1.0).opacity(0.25), lineWidth: 1.5)
                            .frame(width: 88, height: 88)
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(Color(red: 0.72, green: 0.55, blue: 1.0))
                    }
                    .scaleEffect(resultAppeared ? 1 : 0.55)
                    .opacity(resultAppeared ? 1 : 0)
                    .padding(.top, 44)

                    Text("Your Drawing Profile")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                        .opacity(resultAppeared ? 1 : 0)
                        .offset(y: resultAppeared ? 0 : 14)

                    if let p = profile {
                        Text("Scanned \(p.formattedDate)")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                            .opacity(resultAppeared ? 1 : 0)
                    }
                }
                .padding(.bottom, 28)

                if let p = profile {
                    // ── 4 full-width metric cards ────────────────────────
                    VStack(spacing: 10) {
                        profileMetricRow(
                            icon: "waveform.path.ecg",
                            label: "Shake Range",
                            value: String(format: "%.1f mm", p.amplitudeMM),
                            detail: amplitudeExplainer(p.amplitudeMM),
                            color: amplitudeColor(p.amplitudeMM)
                        )
                        profileMetricRow(
                            icon: "metronome",
                            label: "Shake Speed",
                            value: String(format: "%.1f times/sec", p.dominantFrequencyHz),
                            detail: frequencyExplainer(p.dominantFrequencyHz),
                            color: .metricBlue
                        )
                        profileMetricRow(
                            icon: "arrow.left.and.right",
                            label: "Direction",
                            value: p.biasLabel,
                            detail: biasExplainer(p.horizontalBias),
                            color: Color(red: 0.20, green: 0.78, blue: 0.68)
                        )
                        profileMetricRow(
                            icon: "battery.75",
                            label: "Grip Stamina",
                            value: fatigueShortLabel(p.fatigueIncrease),
                            detail: fatigueExplainer(p.fatigueIncrease),
                            color: fatigueColor(p.fatigueIncrease)
                        )
                    }
                    .padding(.horizontal, 20)
                    .opacity(resultAppeared ? 1 : 0)
                    .offset(y: resultAppeared ? 0 : 24)

                    // ── Auto-applied confirmation ────────────────────────
                    HStack(alignment: .top, spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(red: 0.40, green: 0.80, blue: 0.55))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Draw mode set up for you")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Text("Your settings have been tuned based on this scan. Adjust anytime in Settings.")
                                .font(.system(size: 15))
                                .foregroundColor(.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.40, green: 0.80, blue: 0.55).opacity(0.09))
                    .cornerRadius(20)
                    .overlay(RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(red: 0.40, green: 0.80, blue: 0.55).opacity(0.22), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .opacity(resultAppeared ? 1 : 0)
                }

                Spacer(minLength: 48)

                // ── CTA button ───────────────────────────────────────────
                Button {
                    if let p = profile {
                        settings.saveTremorProfile(p)
                        autoApplySettings(from: p)
                    }
                    dismiss()
                } label: {
                    Text("Start Drawing")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 68)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.52, green: 0.42, blue: 0.98),
                                         Color(red: 0.36, green: 0.28, blue: 0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing)
                        )
                        .cornerRadius(20)
                        .shadow(color: Color(red: 0.40, green: 0.33, blue: 0.85).opacity(0.38),
                                radius: 18, x: 0, y: 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 56)
                .opacity(resultAppeared ? 1 : 0)
                .scaleEffect(resultAppeared ? 1 : 0.94)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.72).delay(0.15)) {
                resultAppeared = true
            }
        }
    }

    // MARK: - Settings Auto-Apply

    private func autoApplySettings(from p: TremorProfile) {
        // Filter strength — already set by saveTremorProfile, but reinforce
        settings.tremorFilterStrength = p.recommendedFilterStrength

        // Stroke stabilization — on for any detectable tremor
        settings.strokeStabilization = p.amplitudeMM > 0.8
        settings.stabilizationAmount = p.amplitudeMM > 3.0 ? 0.7 :
                                       p.amplitudeMM > 1.5 ? 0.5 : 0.3

        // Pressure compensation — on if pressure varied during spiral
        settings.pressureCompensation = p.pressureVariance > 0.08

        // Velocity damping — on for faster tremor (>5 Hz tends to cause fast jerks)
        settings.velocityDamping = p.dominantFrequencyHz > 5.0

        // Jitter threshold — scale with amplitude
        settings.jitterThreshold = p.amplitudeMM > 3.0 ? 2.5 :
                                   p.amplitudeMM > 1.5 ? 1.5 : 1.0

        // Adaptive assist — always on if any tremor detected
        settings.adaptiveAssist = p.amplitudeMM > 0.5
    }

    // MARK: - Plain-English Explainers

    private func amplitudeExplainer(_ mm: Double) -> String {
        switch mm {
        case ..<0.8: return "Barely noticeable — your lines will look clean naturally"
        case ..<2.0: return "Mild shake — filter will smooth most of it away"
        case ..<4.5: return "Moderate shake — assist will make a real difference"
        default:     return "Significant shake — strong assist applied for you"
        }
    }

    private func frequencyExplainer(_ hz: Double) -> String {
        switch hz {
        case ..<3.5: return "Slow, sweeping movement — easy to work with"
        case ..<6.0: return "Medium rhythm — the most common pattern"
        case ..<9.0: return "Fast rhythm — speed damping will help control it"
        default:     return "Very fast — multiple filters working together"
        }
    }

    private func biasExplainer(_ bias: Double) -> String {
        if bias > 0.65 { return "Your shake runs left-right — affects horizontal strokes most" }
        if bias < 0.35 { return "Your shake runs up-down — affects vertical strokes most" }
        return "Shake is roughly equal in both directions"
    }

    private func fatigueShortLabel(_ pct: Double) -> String {
        pct < 12 ? "Steady" : pct < 28 ? "Mild fatigue" : "Noticeable fatigue"
    }

    private func fatigueExplainer(_ pct: Double) -> String {
        switch pct {
        case ..<12: return "Grip stays consistent — take breaks whenever you like"
        case ..<28: return "Some fatigue sets in — short drawing sessions work best"
        default:    return "Grip tires quickly — rest every few minutes for best results"
        }
    }

    // MARK: - Shared UI Components

    private func phaseHeader(number: Int, title: String, total: Int) -> some View {
        VStack(spacing: 16) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .padding(10)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .zIndex(10)
                Spacer()
                Text("Phase \(number) of \(total)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                // Placeholder to balance
                Color.clear.frame(width: 35, height: 35)
            }
            .padding(.horizontal, 20)
            .padding(.top, 52)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.textPrimary)
        }
        .padding(.bottom, 8)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(height: 4)
                Capsule()
                    .fill(Color(red: 0.72, green: 0.55, blue: 1.0))
                    .frame(width: geo.size.width * phaseProgress, height: 4)
                    .animation(.linear(duration: 0.1), value: phaseProgress)
            }
        }
        .frame(height: 4)
    }

    private var countdownOverlay: some View {
        ZStack {
            Color(UIColor.systemBackground).opacity(0.9).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("\(countdown)")
                    .font(.system(size: 88, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text("Get ready…")
                    .font(.system(size: 18))
                    .foregroundColor(.textSecondary)
            }
        }
        .transition(.opacity)
    }

    private func profileMetricRow(icon: String, label: String, value: String,
                                   detail: String, color: Color) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.13))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(color)
            }
            // Label + value + detail stacked
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSecondary)
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.textPrimary)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
                    .padding(.top, 3)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(color.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Flow Control

    private func beginScan() {
        withAnimation(.easeInOut(duration: 0.35)) { phase = .holdStill }
        startHoldTimer()
    }

    private func startHoldTimer() {
        phaseProgress = 0
        let duration: Double = 10
        let start = Date()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { t in
            let elapsed = Date().timeIntervalSince(start)
            phaseProgress = CGFloat(elapsed / duration)
            if elapsed >= duration {
                t.invalidate()
                finishHoldPhase()
            }
        }
    }

    private func finishHoldPhase() {
        if holdPoints.count > 10 {
            let pts = Array(holdPoints)
            holdAmplitude = computeSpread(pts)
            holdFrequency = computeFrequency(pts)
        }
        holdPoints = []
        drawCanvasView = PKCanvasView()
        drawingDone = false
        withAnimation(.easeInOut(duration: 0.35)) { phase = .spiral }
    }

    private func handleDrawStroke() {
        guard let stroke = drawCanvasView.drawing.strokes.last else { return }
        let m = MotorAnalysisEngine.analyze(stroke: stroke)
        if phase == .spiral {
            spiralAmplitude = m.tremorAmplitude
            spiralPressureVar = m.pressureVariance
        } else {
            lineAmplitude = m.tremorAmplitude
            let pts = (0..<stroke.path.count).map { stroke.path[$0].location }
            if pts.count > 2 {
                let dxTotal = abs(pts.last!.x - pts.first!.x)
                let dyTotal = abs(pts.last!.y - pts.first!.y)
                let total = dxTotal + dyTotal
                lineHorizBias = total > 0 ? dxTotal / total : 0.5
            }
        }
        withAnimation { drawingDone = true }
    }

    private func advanceFromDraw() {
        drawingDone = false
        drawCanvasView = PKCanvasView()
        withAnimation(.easeInOut(duration: 0.35)) {
            if phase == .spiral { phase = .straightLine } else { phase = .tapTargets }
        }
    }

    private func setupTapTargets(geo: GeometryProxy) {
        guard tapTargets.isEmpty else { return }
        let w = geo.size.width, h = geo.size.height
        let pad: CGFloat = 80
        tapTargets = [
            CGPoint(x: w * 0.25, y: h * 0.25),
            CGPoint(x: w * 0.75, y: h * 0.25),
            CGPoint(x: w * 0.50, y: h * 0.50),
            CGPoint(x: w * 0.25, y: h * 0.75),
            CGPoint(x: w * 0.75, y: h * 0.75),
            CGPoint(x: w * 0.50, y: h * 0.30),
        ].map { CGPoint(x: max(pad, min(w - pad, $0.x)), y: max(pad, min(h - pad, $0.y))) }
    }

    private func handleTap(at location: CGPoint, geo: GeometryProxy) {
        guard currentTargetIndex < tapTargets.count else { return }
        let target = tapTargets[currentTargetIndex]
        let dist = hypot(location.x - target.x, location.y - target.y)
        tapPoints.append(location)
        tapDeviation = (tapDeviation * CGFloat(currentTargetIndex) + dist) / CGFloat(currentTargetIndex + 1)
        tappedTargets.append(target)
        currentTargetIndex += 1
        if currentTargetIndex >= tapTargets.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                buildProfile()
                withAnimation { phase = .results }
            }
        }
    }

    // MARK: - Profile Computation

    private func buildProfile() {
        // -- Amplitude --
        // holdAmplitude is average pixel spread from centroid during 10s hold.
        // Apple Pencil on iPad: coords in points. 1 pt ≈ 0.13 mm physical.
        // Mild tremor: ~4–10pt spread → 0.5–1.5 mm. Significant: 20+pt → 3+ mm.
        let rawAmplitude = holdAmplitude * 0.5 + spiralAmplitude * 0.3 + lineAmplitude * 0.2
        let amplitudeMM = max(0.1, min(12.0, Double(rawAmplitude) * 0.13))

        // -- Frequency --
        // computeFrequency() counts direction reversals over 10 seconds of hold.
        // Each full oscillation produces 2 reversals → Hz = count / (2 × duration)
        let freqHz = max(1.0, min(14.0, Double(holdFrequency) / (2.0 * 10.0)))

        // -- Pressure variance -- already 0–1 from MotorAnalysisEngine
        let pressureVar = max(0.0, min(1.0, Double(spiralPressureVar)))

        // -- Directional bias -- from straight-line draw
        let horizBias = Double(lineHorizBias)

        // -- Fatigue -- estimated from amplitude (split-half not tracked in this pass)
        // 0–3pt → ~5–15%, 3–8pt → 15–30%, 8+ pt → 30–50%
        let fatigue = max(5.0, min(50.0, Double(holdAmplitude) * 1.8 + 5.0))

        profile = TremorProfile(
            date: Date(),
            amplitudeMM: amplitudeMM,
            dominantFrequencyHz: freqHz,
            pressureVariance: pressureVar,
            horizontalBias: horizBias,
            fatigueIncrease: fatigue
        )
    }

    // MARK: - Signal Helpers

    private func computeSpread(_ pts: [CGPoint]) -> CGFloat {
        guard pts.count > 1 else { return 0 }
        let cx = pts.map { $0.x }.reduce(0, +) / CGFloat(pts.count)
        let cy = pts.map { $0.y }.reduce(0, +) / CGFloat(pts.count)
        return pts.map { hypot($0.x - cx, $0.y - cy) }.reduce(0, +) / CGFloat(pts.count)
    }

    private func computeFrequency(_ pts: [CGPoint]) -> CGFloat {
        guard pts.count > 4 else { return 0 }
        var changes = 0
        for i in 2..<pts.count {
            let dx1 = pts[i-1].x - pts[i-2].x
            let dx2 = pts[i].x   - pts[i-1].x
            if dx1 * dx2 < 0 { changes += 1 }
        }
        return CGFloat(changes)
    }

    private func stopAllTimers() {
        phaseTimer?.invalidate()
        holdTimer?.invalidate()
        countdownTimer?.invalidate()
    }

    // MARK: - Color Helpers

    private func amplitudeColor(_ mm: Double) -> Color {
        mm < 1.5 ? .metricGreen : mm < 3.5 ? Color(red: 0.95, green: 0.65, blue: 0.15) : .metricRed
    }

    private func fatigueColor(_ pct: Double) -> Color {
        pct < 10 ? .metricGreen : pct < 25 ? Color(red: 0.95, green: 0.65, blue: 0.15) : .metricRed
    }
}

// MARK: - Touch Capture View (for Hold Still phase)

struct ScanTouchCapture: UIViewRepresentable {
    let onTouchMoved: (CGPoint) -> Void

    func makeUIView(context: Context) -> TouchCaptureView {
        let v = TouchCaptureView()
        v.onTouchMoved = onTouchMoved
        v.backgroundColor = .clear
        return v
    }

    func updateUIView(_ uiView: TouchCaptureView, context: Context) {}
}

final class TouchCaptureView: UIView {
    var onTouchMoved: ((CGPoint) -> Void)?

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first {
            onTouchMoved?(t.location(in: self))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let t = touches.first { onTouchMoved?(t.location(in: self)) }
    }
}
