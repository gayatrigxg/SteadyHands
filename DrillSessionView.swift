import SwiftUI
import PencilKit
import CoreHaptics

// MARK: - Session Phase

enum DrillPhase: Equatable {
    case intro
    case countdown(Int)
    case active
    case summary
}

// MARK: - DrillSessionView

@MainActor
struct DrillSessionView: View {

    let type: DrillType
    var isSteadySession: Bool = false
    var onNextPhase: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    @State private var phase: DrillPhase = .intro
    @State private var countdownValue: Int = 3
    @State private var countdownTimer: Timer?

    // Session timing
    @State private var sessionProgress: CGFloat = 0
    @State private var sessionTimer: Timer?
    @State private var elapsedSeconds: Int = 0

    // Canvas (TremorTrace + CorridorPath)
    @State private var canvasView = PKCanvasView()
    @State private var canvasSize: CGSize = .zero
    @State private var latestScore: MotorAnalysisEngine.DrillScore?

    // Haptics
    @State private var hapticEngine: CHHapticEngine?

    // ShrinkingTarget state
    @State private var targetRadius: CGFloat = 80
    @State private var holdStartTime: Date?
    @State private var smallestRadiusHeld: CGFloat = 80
    @State private var totalHoldTime: TimeInterval = 0
    @State private var isPencilInTarget: Bool = false
    @State private var targetCenter: CGPoint = .zero
    @State private var holdProgress: CGFloat = 0
    @State private var targetPulse: Bool = false
    @State private var exitFlash: Bool = false

    // PressureWave state
    @State private var forceSamples: [CGFloat] = []
    @State private var currentForce: CGFloat = 0
    @State private var bandNarrowProgress: CGFloat = 0  // 0→1 over 5s
    @State private var isOutOfBand: Bool = false

    // DotHold state
    @State private var touchPoints: [CGPoint] = []
    @State private var dotCenter: CGPoint = .zero
    @State private var dotCanvasSize: CGSize = .zero
    @State private var isHolding: Bool = false
    @State private var holdRingProgress: CGFloat = 0

    // CorridorPath state
    @State private var corridorUserPoints: [CGPoint] = []
    @State private var corridorCenterPoints: [CGPoint] = []
    @State private var corridorWidth: CGFloat = 52
    @State private var corridorCanvasSize: CGSize = .zero
    @State private var lastCorridorPoint: CGPoint? = nil
    @State private var corridorIsDrawing: Bool = false

    // TremorTrace
    @State private var deviationSamples: [CGFloat] = []
    @State private var tremorTraceMaxX: CGFloat = 0   // drives progress bar

    // Summary
    @State private var finalScore: MotorAnalysisEngine.DrillScore?
    @State private var summaryRingProgress: CGFloat = 0
    @State private var summaryAppeared: Bool = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            switch phase {
            case .intro:
                introView
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
            case .countdown(let n):
                countdownView(n: n)
                    .transition(.opacity)
            case .active:
                activeView
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .opacity))
            case .summary:
                summaryView
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: phase)
        .navigationBarHidden(true)
        .onDisappear { stopAllTimers(); teardownHaptics() }
    }
}

// MARK: - Intro

extension DrillSessionView {

    var introView: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {

                // ── Nav bar ───────────────────────────────────────────
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(Color(UIColor.tertiarySystemFill))
                            .clipShape(Circle())
                    }
                    Spacer()
                    if isSteadySession {
                        Text(type.phaseLabel)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(type.accentColor)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(type.accentColor.opacity(0.10))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 56)
                .padding(.bottom, 0)

                // ── Scrollable content ────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Icon + title block ────────────────────────
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(type.accentColor.opacity(0.13))
                                    .frame(width: 96, height: 96)
                                Circle()
                                    .stroke(type.accentColor.opacity(0.22), lineWidth: 1.5)
                                    .frame(width: 96, height: 96)
                                Image(systemName: type.systemIcon)
                                    .font(.system(size: 38, weight: .medium))
                                    .foregroundColor(type.accentColor)
                            }

                            Text(type.title)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.textPrimary)

                            HStack(spacing: 8) {
                                Text(type.motorSkillLabel)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(type.accentColor)
                                Text("·").foregroundColor(Color(UIColor.tertiaryLabel))
                                Text(type.durationLabel)
                                    .font(.system(size: 14))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding(.top, 24)
                        .padding(.bottom, 22)

                        // ── Animated preview card ─────────────────────
                        AnimatedInstructionCard(type: type)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)

                        // ── WHAT TO DO card ───────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(type.accentColor.opacity(0.14))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "hand.draw")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(type.accentColor)
                                }
                                Text("What to do")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.textSecondary)
                                    .textCase(.uppercase)
                                    .kerning(0.4)
                            }

                            Text(type.techniqueText)
                                .font(.system(size: 17))
                                .foregroundColor(.textPrimary)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.cardBackground)
                                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 3)
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 14)

                        // ── WHY IT HELPS card ─────────────────────────
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(type.accentColor.opacity(0.14))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(type.accentColor)
                                }
                                Text("Why this helps")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.textSecondary)
                                    .textCase(.uppercase)
                                    .kerning(0.4)
                            }

                            Text(type.whyItHelps)
                                .font(.system(size: 17))
                                .foregroundColor(.textPrimary)
                                .lineSpacing(7)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(22)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(type.accentColor.opacity(0.07))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(type.accentColor.opacity(0.18), lineWidth: 1.2)
                                )
                        )
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)

                        // ── Badges row ────────────────────────────────
                        HStack(spacing: 8) {
                            if type.requiresPencilForce {
                                Label("Pencil Force", systemImage: "pencil.tip")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(type.accentColor)
                                    .padding(.horizontal, 13).padding(.vertical, 8)
                                    .background(type.accentColor.opacity(0.10))
                                    .cornerRadius(14)
                            }
                            if let best = settings.bestScore(for: type) {
                                Label("Best: \(Int(best * 100))%", systemImage: "star.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(type.accentColor)
                                    .padding(.horizontal, 13).padding(.vertical, 8)
                                    .background(type.accentColor.opacity(0.10))
                                    .cornerRadius(14)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)

                        // ── Start button ──────────────────────────────
                        VStack(spacing: 12) {
                            Button { beginCountdown() } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Start Exercise")
                                        .font(.system(size: 19, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(type.accentColor)
                                .cornerRadius(18)
                            }
                            .padding(.horizontal, 24)

                            Button { dismiss() } label: {
                                Text("Not now")
                                    .font(.system(size: 16))
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding(.bottom, 48)
                    }
                }
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - Countdown

extension DrillSessionView {
    func countdownView(n: Int) -> some View {
        ZStack {
            Color.black.opacity(0.90).ignoresSafeArea()
            VStack(spacing: 16) {
                if n > 0 {
                    Text("\(n)")
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: n)
                } else {
                    Text("Go!")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(type.accentColor)
                        .transition(.scale.combined(with: .opacity))
                }

                Text(n > 0 ? "Get ready" : type.instructionText)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Active View

extension DrillSessionView {
    var activeView: some View {
        VStack(spacing: 0) {
            activeHeader

            Group {
                switch type {
                case .tremorTrace:     tremorTraceCanvas
                case .corridorPath:    corridorPathView
                case .shrinkingTarget: shrinkingTargetView
                case .pressureWave:    pressureWaveView
                case .dotHold:         dotHoldView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Subtle instruction reminder at bottom
            Text(type.instructionText)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
        }
    }

    var activeHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text(type.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Spacer()

                // Live score badge
                if let score = latestScore {
                    Text("\(score.primaryPercent)%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(type.accentColor)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(type.accentColor.opacity(0.12))
                        .cornerRadius(10)
                }

                Button { endSession() } label: {
                    Text("Done")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color(UIColor.tertiarySystemFill))
                        .cornerRadius(20)
                }
                .padding(.leading, 8)
            }

            // Smart progress bar — driven by interaction for canvas drills, time for timed drills
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.12)).frame(height: 5)
                    Capsule()
                        .fill(type.accentColor)
                        .frame(width: geo.size.width * smartProgress, height: 5)
                        .animation(.easeOut(duration: 0.12), value: smartProgress)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 14)
    }

    // Smart progress: canvas drills track user input; timed drills track clock
    var smartProgress: CGFloat {
        switch type {
        case .tremorTrace:
            // Progress = how far right the rightmost stroke point has gone
            guard canvasSize.width > 0 else { return 0 }
            return min(1.0, tremorTraceMaxX / (canvasSize.width - 60))
        case .corridorPath:
            // Progress = how far along corridor the user's furthest point is
            guard corridorCenterPoints.count > 1, !corridorUserPoints.isEmpty else { return 0 }
            let lastUserX = corridorUserPoints.map { $0.x }.max() ?? 0
            let startX = corridorCenterPoints.first?.x ?? 0
            let endX = corridorCenterPoints.last?.x ?? 1
            return min(1.0, (lastUserX - startX) / max(endX - startX, 1))
        case .dotHold:
            // Progress = sample count / expected samples (60fps * 10s = ~600)
            return min(1.0, CGFloat(touchPoints.count) / 500.0)
        case .shrinkingTarget, .pressureWave:
            // These genuinely need a timer
            return sessionProgress
        }
    }
}

// MARK: - Exercise 1: Tremor Trace

extension DrillSessionView {
    var tremorTraceCanvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(Color.white)

            // Horizontal guide dashes
            GeometryReader { geo in
                Canvas { ctx, size in
                    let midY = size.height / 2
                    var guide = Path()
                    guide.move(to: CGPoint(x: 40, y: midY))
                    guide.addLine(to: CGPoint(x: size.width - 40, y: midY))
                    ctx.stroke(guide, with: .color(.gray.opacity(0.18)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))

                    // Green zone band ±15pt
                    ctx.fill(Path(CGRect(x: 40, y: midY - 15,
                                        width: size.width - 80, height: 30)),
                             with: .color(Color.green.opacity(0.05)))
                }
                .allowsHitTesting(false)
            }

            // Arrow hint
            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .ultraLight))
                .foregroundColor(type.accentColor.opacity(0.18))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 44)

            SteadyCanvas(
                canvasView: $canvasView,
                smoothingEnabled: false,
                shapeRecognitionEnabled: false,
                snapManager: ShapeSnapManager(),
                assistLevel: 0.0,
                showGhostOverlay: false,
                showToolPicker: false,
                onStrokeAdded: handleTremorTraceStroke
            )
            .background(Color.clear)
        }
        .cornerRadius(24)
        .padding(.horizontal, 20)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear { canvasSize = geo.size }
            }
        )
    }

    func handleTremorTraceStroke() {
        guard let stroke = canvasView.drawing.strokes.last else { return }
        let score = MotorAnalysisEngine.scoreTremorTrace(stroke: stroke)
        deviationSamples = MotorAnalysisEngine.tremorDeviations(from: stroke)
        // Update rightmost X for smart progress bar
        let points = stroke.path
        let maxX = (0..<points.count).map { points[$0].location.x }.max() ?? 0
        tremorTraceMaxX = max(tremorTraceMaxX, maxX)
        withAnimation(.easeInOut(duration: 0.3)) { latestScore = score }
        // Auto-end when line reaches the right side
        if smartProgress >= 1.0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { endSession() }
        }
    }
}

// MARK: - Exercise 2: Corridor Path

extension DrillSessionView {

    // Generate a smooth S-curve corridor path for a given canvas size
    func generateCorridorPath(for size: CGSize) -> [CGPoint] {
        guard size.width > 0 else { return [] }
        let steps = 80
        let padX: CGFloat = 44
        let padY: CGFloat = 60
        return (0...steps).map { i in
            let t = CGFloat(i) / CGFloat(steps)
            let x = padX + t * (size.width - padX * 2)
            // Double S-curve: combines two sine waves
            let y = size.height / 2
                + sin(t * .pi * 2) * (size.height * 0.22)
                + sin(t * .pi * 4) * (size.height * 0.06)
            return CGPoint(x: x, y: max(padY, min(size.height - padY, y)))
        }
    }

    var corridorPathView: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(Color.white)

                // Corridor drawn in Canvas
                Canvas { ctx, size in
                    let pts = corridorCenterPoints.isEmpty ? generateCorridorPath(for: size) : corridorCenterPoints
                    let halfW = corridorWidth / 2

                    // Draw corridor filled zone (light)
                    if pts.count > 1 {
                        // Top border path
                        var topPath = Path()
                        var botPath = Path()
                        for (i, pt) in pts.enumerated() {
                            // Compute normal to curve at this point
                            let prev = i > 0 ? pts[i - 1] : pt
                            let next = i < pts.count - 1 ? pts[i + 1] : pt
                            let dx = next.x - prev.x
                            let dy = next.y - prev.y
                            let len = hypot(dx, dy)
                            guard len > 0 else { continue }
                            let nx = -dy / len * halfW
                            let ny = dx / len * halfW
                            let topPt = CGPoint(x: pt.x + nx, y: pt.y + ny)
                            let botPt = CGPoint(x: pt.x - nx, y: pt.y - ny)
                            if i == 0 { topPath.move(to: topPt); botPath.move(to: botPt) }
                            else { topPath.addLine(to: topPt); botPath.addLine(to: botPt) }
                        }
                        // Fill corridor
                        var corridorFill = topPath
                        // Append reversed bottom to close
                        corridorFill.addLines(botPath.reversing() .elements.compactMap {
                            if case .line(let to) = $0 { return to }
                            if case .move(let to) = $0 { return to }
                            return nil
                        })
                        ctx.fill(corridorFill, with: .color(type.accentColor.opacity(0.07)))

                        // Border strokes
                        ctx.stroke(topPath, with: .color(type.accentColor.opacity(0.25)),
                                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                        ctx.stroke(botPath, with: .color(type.accentColor.opacity(0.25)),
                                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                        // Center dashed line
                        var center = Path()
                        for (i, pt) in pts.enumerated() {
                            if i == 0 { center.move(to: pt) }
                            else { center.addLine(to: pt) }
                        }
                        ctx.stroke(center, with: .color(type.accentColor.opacity(0.12)),
                                   style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }

                    // Draw user trace colored by inside/outside
                    if corridorUserPoints.count > 1 {
                        for i in 1..<corridorUserPoints.count {
                            let pt = corridorUserPoints[i]
                            let minDist = pts.map { hypot(pt.x - $0.x, pt.y - $0.y) }.min() ?? 100
                            let inside = minDist <= halfW
                            var seg = Path()
                            seg.move(to: corridorUserPoints[i - 1])
                            seg.addLine(to: pt)
                            ctx.stroke(seg, with: .color(inside
                                ? Color.green.opacity(0.85)
                                : Color.red.opacity(0.75)),
                                       style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        }
                    }

                    // Start dot (green) and End dot (red)
                    if let first = pts.first {
                        ctx.fill(Path(ellipseIn: CGRect(x: first.x - 10, y: first.y - 10,
                                                        width: 20, height: 20)),
                                 with: .color(Color.green))
                    }
                    if let last = pts.last {
                        ctx.fill(Path(ellipseIn: CGRect(x: last.x - 10, y: last.y - 10,
                                                        width: 20, height: 20)),
                                 with: .color(Color.red))
                    }
                }
                .allowsHitTesting(false)

                // Start / End labels
                if !corridorCenterPoints.isEmpty {
                    Text("START")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .position(x: corridorCenterPoints.first!.x,
                                  y: corridorCenterPoints.first!.y - 20)
                    Text("END")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                        .position(x: corridorCenterPoints.last!.x,
                                  y: corridorCenterPoints.last!.y - 20)
                }

                // Touch area
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleCorridorDrag(at: value.location)
                            }
                            .onEnded { _ in
                                corridorIsDrawing = false
                                lastCorridorPoint = nil
                                // Score live
                                let score = MotorAnalysisEngine.scoreCorridorPath(
                                    userPoints: corridorUserPoints,
                                    corridorPoints: corridorCenterPoints,
                                    corridorWidth: corridorWidth
                                )
                                withAnimation { latestScore = score }
                            }
                    )
            }
            .onAppear {
                corridorCanvasSize = geo.size
                corridorCenterPoints = generateCorridorPath(for: geo.size)
            }
        }
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }

    func handleCorridorDrag(at point: CGPoint) {
        corridorUserPoints.append(point)
        corridorIsDrawing = true

        // Check if inside corridor for haptic feedback
        if !corridorCenterPoints.isEmpty {
            let minDist = corridorCenterPoints.map { hypot(point.x - $0.x, point.y - $0.y) }.min() ?? 100
            let isInside = minDist <= corridorWidth / 2

            // Exit haptic
            if let last = lastCorridorPoint {
                let lastDist = corridorCenterPoints.map { hypot(last.x - $0.x, last.y - $0.y) }.min() ?? 100
                let wasInside = lastDist <= corridorWidth / 2
                if wasInside && !isInside {
                    // Just left corridor
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
                }
            }
        }
        lastCorridorPoint = point

        // Auto-end when user reaches the end of the corridor
        if smartProgress >= 1.0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.phase == .active { self.endSession() }
            }
        }
    }
}

// MARK: - Exercise 3: Shrinking Target

extension DrillSessionView {

    private var shrinkLevel: Int { max(0, Int((80 - targetRadius) / 10)) }

    var shrinkingTargetView: some View {
        GeometryReader { geo in
            let center = targetCenter.x == 0
                ? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                : targetCenter

            ZStack {
                // Dark precision-instrument canvas
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.07, green: 0.07, blue: 0.10))

                // Subtle dot grid
                Canvas { ctx, size in
                    let spacing: CGFloat = 36
                    for xi in stride(from: spacing, through: size.width - spacing, by: spacing) {
                        for yi in stride(from: spacing, through: size.height - spacing, by: spacing) {
                            ctx.fill(
                                Path(ellipseIn: CGRect(x: xi - 0.75, y: yi - 0.75, width: 1.5, height: 1.5)),
                                with: .color(.white.opacity(0.06))
                            )
                        }
                    }
                }
                .allowsHitTesting(false)

                // Ambient glow when holding
                if isPencilInTarget {
                    Circle()
                        .fill(RadialGradient(
                            colors: [type.accentColor.opacity(0.20), .clear],
                            center: .center, startRadius: 0, endRadius: targetRadius + 90))
                        .frame(width: (targetRadius + 90) * 2, height: (targetRadius + 90) * 2)
                        .position(center)
                        .animation(.spring(response: 0.5), value: targetRadius)
                }

                // Ghost rings showing previous levels
                Canvas { ctx, size in
                    let c = center
                    for level in 0..<shrinkLevel {
                        let r = CGFloat(80 - level * 10)
                        let path = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r*2, height: r*2))
                        ctx.stroke(path, with: .color(type.accentColor == .brandPrimary
                            ? .purple.opacity(0.10) : type.accentColor.opacity(0.10)),
                            style: StrokeStyle(lineWidth: 1))
                    }
                }
                .allowsHitTesting(false)

                // Inner fill
                Circle()
                    .fill(isPencilInTarget
                          ? type.accentColor.opacity(0.10)
                          : (exitFlash ? Color.red.opacity(0.08) : Color.white.opacity(0.03)))
                    .frame(width: targetRadius * 2, height: targetRadius * 2)
                    .position(center)
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: targetRadius)

                // Main neon ring
                Circle()
                    .stroke(exitFlash ? Color.red : type.accentColor,
                            lineWidth: isPencilInTarget ? 2.5 : 1.5)
                    .frame(width: targetRadius * 2, height: targetRadius * 2)
                    .position(center)
                    .shadow(color: exitFlash
                            ? Color.red.opacity(0.7)
                            : type.accentColor.opacity(isPencilInTarget ? 0.7 : 0.3), radius: 8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.65), value: targetRadius)
                    .animation(.easeOut(duration: 0.12), value: exitFlash)

                // Hold progress arc outside ring
                if isPencilInTarget {
                    Circle()
                        .trim(from: 0, to: holdProgress)
                        .stroke(type.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: targetRadius * 2 + 18, height: targetRadius * 2 + 18)
                        .rotationEffect(.degrees(-90))
                        .position(center)
                        .shadow(color: type.accentColor.opacity(0.8), radius: 4)
                        .animation(.linear(duration: 0.08), value: holdProgress)
                }

                // Crosshair
                Canvas { ctx, size in
                    let c = center; let s: CGFloat = 9
                    for pts in [[CGPoint(x:c.x-s,y:c.y), CGPoint(x:c.x+s,y:c.y)],
                                [CGPoint(x:c.x,y:c.y-s), CGPoint(x:c.x,y:c.y+s)]] {
                        var p = Path(); p.move(to: pts[0]); p.addLine(to: pts[1])
                        ctx.stroke(p, with: .color(type.accentColor.opacity(0.8)),
                                   style: StrokeStyle(lineWidth: 1.5))
                    }
                }
                .allowsHitTesting(false)

                // Top HUD
                VStack {
                    HStack {
                        // Level pips
                        HStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(i < shrinkLevel ? type.accentColor : Color.white.opacity(0.14))
                                    .frame(width: 20, height: 5)
                                    .shadow(color: i < shrinkLevel ? type.accentColor.opacity(0.6) : .clear, radius: 3)
                                    .animation(.spring(response: 0.3).delay(Double(i) * 0.04), value: shrinkLevel)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("\(Int(targetRadius))pt")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(type.accentColor)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.3), value: targetRadius)
                            Text("radius")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    .padding(.horizontal, 22).padding(.top, 20)

                    Spacer()

                    if !isPencilInTarget {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.point.up.left.fill").font(.system(size: 12))
                            Text("Touch and hold inside the circle").font(.system(size: 13))
                        }
                        .foregroundColor(.white.opacity(0.30))
                        .padding(.bottom, 20)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isPencilInTarget)

                // Touch capture
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in handleTargetTouch(at: value.location, canvasSize: geo.size) }
                        .onEnded { _ in
                            isPencilInTarget = false
                            holdStartTime = nil
                            holdProgress = 0
                            targetPulse = false
                        })
            }
            .onAppear {
                targetCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                targetRadius = 80
                smallestRadiusHeld = 80
            }
        }
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }

    func handleTargetTouch(at point: CGPoint, canvasSize: CGSize) {
        let center = targetCenter.x == 0
            ? CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
            : targetCenter
        let distance = hypot(point.x - center.x, point.y - center.y)
        let inTarget = distance <= targetRadius

        if inTarget {
            if holdStartTime == nil {
                holdStartTime = Date()
                targetPulse = true
                playHaptic(.light)
            }
            isPencilInTarget = true
            exitFlash = false

            let holdDuration = Date().timeIntervalSince(holdStartTime ?? Date())
            totalHoldTime = holdDuration
            holdProgress = CGFloat(min(holdDuration / 3.0, 1.0))

            if holdDuration >= 3.0 {
                let newRadius = max(14, targetRadius - 10)
                if newRadius < targetRadius {
                    targetRadius = newRadius
                    smallestRadiusHeld = min(smallestRadiusHeld, newRadius)
                    holdStartTime = Date()
                    holdProgress = 0
                    // Success haptic: sharp double
                    playHapticSuccess()

                    // Update live score
                    let score = MotorAnalysisEngine.scoreShrinkingTarget(
                        smallestRadiusHeld: smallestRadiusHeld,
                        startingRadius: 80,
                        totalHoldTime: totalHoldTime
                    )
                    withAnimation { latestScore = score }
                }
            }
        } else {
            if isPencilInTarget {
                // Just exited
                exitFlash = true
                targetPulse = false
                playHaptic(.rigid)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exitFlash = false }
                targetRadius = min(80, targetRadius + 5)
            }
            isPencilInTarget = false
            holdStartTime = nil
            holdProgress = 0
        }
    }
}


// MARK: - Exercise 4: Pressure Wave

extension DrillSessionView {

    // Band bounds: tighten from ±0.22 to ±0.10 over 5s
    var bandHalf: CGFloat {
        let wide: CGFloat = 0.22
        let narrow: CGFloat = 0.10
        return wide - (wide - narrow) * min(bandNarrowProgress, 1.0)
    }

    var pressureWaveView: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(Color.white)

                VStack(spacing: 0) {

                    // ── Waveform area ────────────────────────────────────
                    ZStack {
                        // Waveform canvas
                        Canvas { ctx, size in
                            guard forceSamples.count > 1 else { return }
                            let samples = Array(forceSamples.suffix(120))
                            let stepX = size.width / CGFloat(max(samples.count - 1, 1))
                            let midY = size.height * 0.5
                            let halfH = size.height * 0.36
                            let bHalf = bandHalf
                            let bandTopY = midY - bHalf * halfH * 2.0
                            let bandBotY = midY + bHalf * halfH * 2.0

                            // Green band fill
                            ctx.fill(
                                Path(CGRect(x: 0, y: bandTopY, width: size.width, height: bandBotY - bandTopY)),
                                with: .color(Color.green.opacity(0.09))
                            )

                            // Band borders dashed
                            for y in [bandTopY, bandBotY] {
                                var line = Path()
                                line.move(to: CGPoint(x: 0, y: y))
                                line.addLine(to: CGPoint(x: size.width, y: y))
                                ctx.stroke(line, with: .color(Color.green.opacity(0.5)),
                                           style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                            }

                            // Centre target line
                            var mid = Path()
                            mid.move(to: CGPoint(x: 0, y: midY))
                            mid.addLine(to: CGPoint(x: size.width, y: midY))
                            ctx.stroke(mid, with: .color(Color.gray.opacity(0.18)),
                                       style: StrokeStyle(lineWidth: 1, dash: [4, 6]))

                            // Waveform segments coloured by in/out band
                            for i in 1..<samples.count {
                                let f0 = samples[i - 1], f1 = samples[i]
                                let x0 = CGFloat(i - 1) * stepX
                                let x1 = CGFloat(i) * stepX
                                // Use midY-centred formula consistent with band bounds:
                                // higher force = lower y (wave goes up), lower force = higher y
                                let y0 = size.height * (0.5 + (0.45 - f0) * 0.72)
                                let y1 = size.height * (0.5 + (0.45 - f1) * 0.72)
                                let inside = y1 >= bandTopY && y1 <= bandBotY
                                let age = 0.35 + CGFloat(i) / CGFloat(samples.count) * 0.65
                                var seg = Path()
                                seg.move(to: CGPoint(x: x0, y: y0))
                                seg.addLine(to: CGPoint(x: x1, y: y1))
                                ctx.stroke(seg,
                                           with: .color((inside ? Color.green : Color.red).opacity(age)),
                                           style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            }

                            // Live tip dot
                            if let last = samples.last {
                                let tipX = CGFloat(samples.count - 1) * stepX
                                let tipY = size.height * (0.5 + (0.45 - last) * 0.72)
                                let inside = tipY >= bandTopY && tipY <= bandBotY
                                let r: CGFloat = 7
                                ctx.fill(Path(ellipseIn: CGRect(x: tipX-r, y: tipY-r, width: r*2, height: r*2)),
                                         with: .color(inside ? Color.green : Color.red))
                                ctx.stroke(Path(ellipseIn: CGRect(x: tipX-r-4, y: tipY-r-4, width: (r+4)*2, height: (r+4)*2)),
                                           with: .color((inside ? Color.green : Color.red).opacity(0.28)),
                                           style: StrokeStyle(lineWidth: 2))
                            }
                        }
                        .allowsHitTesting(false)

                        // Empty state
                        if forceSamples.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "hand.point.up.left.fill")
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundColor(type.accentColor.opacity(0.4))
                                Text("Waiting for input…")
                                    .font(.system(size: 13))
                                    .foregroundColor(.textSecondary)
                            }
                            .transition(.opacity)
                            .animation(.easeInOut, value: forceSamples.isEmpty)
                        }
                    }
                    .frame(height: geo.size.height * 0.42)
                    .padding(.horizontal, 4)
                    .padding(.top, 16)

                    // ── Status row ───────────────────────────────────────
                    HStack(spacing: 12) {
                        // In/out pill
                        HStack(spacing: 6) {
                            Circle()
                                .fill(forceSamples.isEmpty ? Color.gray : (isOutOfBand ? Color.red : Color.green))
                                .frame(width: 8, height: 8)
                            Text(forceSamples.isEmpty
                                 ? "Not pressing"
                                 : isOutOfBand ? "Too much" : "In the zone")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(forceSamples.isEmpty ? .textSecondary : (isOutOfBand ? .red : .green))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background((forceSamples.isEmpty ? Color.gray : (isOutOfBand ? Color.red : Color.green)).opacity(0.10))
                        .cornerRadius(20)
                        .animation(.easeInOut(duration: 0.2), value: isOutOfBand)

                        Spacer()

                        // Force readout
                        if !forceSamples.isEmpty {
                            Text(String(format: "%.0f%%", currentForce * 100))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(isOutOfBand ? .red : .green)
                                .animation(.easeOut(duration: 0.08), value: currentForce)
                        }

                        // Mini vertical bar
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.10))
                                .frame(width: 14, height: 52)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isOutOfBand ? Color.red : Color.green)
                                .frame(width: 14, height: max(4, 52 * currentForce))
                                .animation(.easeOut(duration: 0.07), value: currentForce)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                    // ── Big touch zone ───────────────────────────────────
                    ZStack {
                        // Background
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isPencilInTarget
                                  ? (isOutOfBand ? Color.red.opacity(0.06) : type.accentColor.opacity(0.08))
                                  : Color(UIColor.tertiarySystemFill))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(isPencilInTarget
                                            ? (isOutOfBand ? Color.red.opacity(0.3) : type.accentColor.opacity(0.35))
                                            : Color.clear,
                                            lineWidth: 1.5)
                            )
                            .animation(.easeInOut(duration: 0.2), value: isPencilInTarget)
                            .animation(.easeInOut(duration: 0.15), value: isOutOfBand)

                        // Content
                        if isPencilInTarget {
                            VStack(spacing: 8) {
                                Image(systemName: isOutOfBand ? "exclamationmark.triangle" : "checkmark.circle.fill")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(isOutOfBand ? .red : type.accentColor)
                                Text(isOutOfBand ? "Ease off — too much pressure" : "Keep holding steady")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(isOutOfBand ? .red : type.accentColor)
                            }
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                        } else {
                            VStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(type.accentColor.opacity(0.12))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "hand.point.up.left.fill")
                                        .font(.system(size: 26, weight: .medium))
                                        .foregroundColor(type.accentColor)
                                }
                                Text("Press and hold here")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                Text("Finger or Apple Pencil")
                                    .font(.system(size: 13))
                                    .foregroundColor(.textSecondary)
                            }
                            .transition(.opacity)
                        }

                        // Full-area touch capture via PencilForceView
                        PencilForceCanvas(
                            forceSamples: $forceSamples,
                            currentForce: $currentForce,
                            isPencilDown: $isPencilInTarget,
                            onForceUpdate: handleLivePressureUpdate
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isPencilInTarget)
                }
            }
        }
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }

    func handlePressureInput(force: CGFloat) {
        currentForce = force
        forceSamples.append(force)
        if forceSamples.count > 400 { forceSamples = Array(forceSamples.suffix(300)) }
        handleLivePressureUpdate()
    }

    func handlePressureLift() {
        currentForce = 0
    }

    func handleLivePressureUpdate() {
        // Target zone: 0.3–0.6 force range (light, consistent grip)
        let targetMid: CGFloat = 0.45
        let newIsOut = abs(currentForce - targetMid) > bandHalf && currentForce > 0.05
        if newIsOut != isOutOfBand {
            withAnimation(.easeInOut(duration: 0.15)) { isOutOfBand = newIsOut }
            if newIsOut { playHaptic(.rigid) }
        }
        if forceSamples.count % 10 == 0 {
            let score = MotorAnalysisEngine.scorePressureWave(forceSamples: forceSamples)
            withAnimation { latestScore = score }
        }
        // Narrow band after 5s
        let elapsed = CGFloat(forceSamples.count) / 60.0
        if elapsed >= 5.0 {
            bandNarrowProgress = min(1.0, (elapsed - 5.0) / 5.0)
        }
    }
}


// MARK: - Exercise 5: Dot Hold

extension DrillSessionView {
    var dotHoldView: some View {
        GeometryReader { geo in
            let center = dotCenter.x == 0
                ? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                : dotCenter

            ZStack {
                // Dark scientific background — feels like an oscilloscope
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.05, green: 0.08, blue: 0.06))

                // Grid overlay
                Canvas { ctx, size in
                    let spacing: CGFloat = 44
                    for xi in stride(from: CGFloat(0), through: size.width, by: spacing) {
                        var p = Path(); p.move(to: CGPoint(x: xi, y: 0)); p.addLine(to: CGPoint(x: xi, y: size.height))
                        ctx.stroke(p, with: .color(.green.opacity(0.06)), style: StrokeStyle(lineWidth: 0.5))
                    }
                    for yi in stride(from: CGFloat(0), through: size.height, by: spacing) {
                        var p = Path(); p.move(to: CGPoint(x: 0, y: yi)); p.addLine(to: CGPoint(x: size.width, y: yi))
                        ctx.stroke(p, with: .color(.green.opacity(0.06)), style: StrokeStyle(lineWidth: 0.5))
                    }
                }
                .allowsHitTesting(false)

                // Scatter plot canvas
                Canvas { ctx, size in
                    let c = center

                    // Zone rings with labels
                    let zones: [(CGFloat, Color, String)] = [
                        (12, Color.green, ""),
                        (28, Color(red: 0.4, green: 0.9, blue: 0.4), ""),
                        (55, Color.yellow, ""),
                        (90, Color.red, "")
                    ]
                    for (r, color, _) in zones {
                        let path = Path(ellipseIn: CGRect(x: c.x-r, y: c.y-r, width: r*2, height: r*2))
                        ctx.stroke(path, with: .color(color.opacity(0.18)),
                                   style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        ctx.fill(Path(ellipseIn: CGRect(x: c.x-r, y: c.y-r, width: r*2, height: r*2)),
                                 with: .color(color.opacity(0.03)))
                    }

                    // Crosshair axes
                    for pts in [[CGPoint(x: 0, y: c.y), CGPoint(x: size.width, y: c.y)],
                                [CGPoint(x: c.x, y: 0), CGPoint(x: c.x, y: size.height)]] {
                        var p = Path(); p.move(to: pts[0]); p.addLine(to: pts[1])
                        ctx.stroke(p, with: .color(.green.opacity(0.12)), style: StrokeStyle(lineWidth: 0.5, dash: [6, 6]))
                    }

                    // Scatter dots — colour by distance, fade older ones
                    let total = touchPoints.count
                    for (i, pt) in touchPoints.enumerated() {
                        let dist = hypot(pt.x - c.x, pt.y - c.y)
                        let age = CGFloat(i) / max(CGFloat(total), 1)
                        let baseAlpha = 0.25 + age * 0.65

                        let color: Color
                        if dist < 12      { color = Color.green }
                        else if dist < 28 { color = Color(red: 0.4, green: 0.9, blue: 0.4) }
                        else if dist < 55 { color = Color.yellow }
                        else              { color = Color.red }

                        let r: CGFloat = dist < 12 ? 2.5 : 2.0
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x-r, y: pt.y-r, width: r*2, height: r*2)),
                                 with: .color(color.opacity(baseAlpha)))
                    }

                    // Centroid marker (if enough points)
                    if touchPoints.count > 10 {
                        let cx = touchPoints.map { $0.x }.reduce(0, +) / CGFloat(touchPoints.count)
                        let cy = touchPoints.map { $0.y }.reduce(0, +) / CGFloat(touchPoints.count)
                        let cr: CGFloat = 4
                        ctx.fill(Path(ellipseIn: CGRect(x: cx-cr, y: cy-cr, width: cr*2, height: cr*2)),
                                 with: .color(Color.white.opacity(0.5)))
                    }
                }
                .allowsHitTesting(false)

                // Center target dot — glows when holding
                ZStack {
                    if isHolding {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .scaleEffect(targetPulse ? 1.4 : 1.0)
                            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: targetPulse)
                    }
                    Circle()
                        .fill(isHolding ? Color.green : type.accentColor)
                        .frame(width: 14, height: 14)
                        .shadow(color: isHolding ? Color.green.opacity(0.8) : type.accentColor.opacity(0.5), radius: 6)
                    Circle()
                        .stroke(isHolding ? Color.green.opacity(0.5) : type.accentColor.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
                .position(center)
                .animation(.easeInOut(duration: 0.2), value: isHolding)

                // HUD overlay
                VStack {
                    // Top: sample count + spread radius
                    HStack {
                        // Signal quality badge
                        if touchPoints.count > 5 {
                            let spread = touchPoints.map {
                                hypot($0.x - center.x, $0.y - center.y)
                            }.max() ?? 0
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(spread < 20 ? Color.green : spread < 50 ? Color.yellow : Color.red)
                                    .frame(width: 7, height: 7)
                                    .shadow(color: spread < 20 ? Color.green.opacity(0.8) : .clear, radius: 3)
                                Text(spread < 20 ? "Very steady" : spread < 50 ? "Mild tremor" : "High tremor")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(spread < 20 ? .green : spread < 50 ? .yellow : .red)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(12)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(touchPoints.count) pts")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.4))
                            if touchPoints.count > 5 {
                                let spread = touchPoints.map {
                                    hypot($0.x - center.x, $0.y - center.y)
                                }.max() ?? 0
                                Text(String(format: "±%.1fpt", spread))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(type.accentColor)
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 18)

                    Spacer()

                    // Bottom idle hint
                    if !isHolding {
                        VStack(spacing: 6) {
                            Image(systemName: "hand.point.up.left.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.green.opacity(0.4))
                            Text("Touch and hold the dot")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.30))
                        }
                        .padding(.bottom, 24)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isHolding)

                // Touch capture
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            touchPoints.append(value.location)
                            if !isHolding {
                                isHolding = true
                                targetPulse = true
                                playHaptic(.soft)
                            }
                            if touchPoints.count % 20 == 0 {
                                let c = dotCenter.x == 0
                                    ? CGPoint(x: geo.size.width/2, y: geo.size.height/2) : dotCenter
                                let score = MotorAnalysisEngine.scoreDotHold(
                                    touchPoints: touchPoints, targetCenter: c)
                                withAnimation { latestScore = score }
                            }
                        }
                        .onEnded { _ in
                            isHolding = false
                            targetPulse = false
                        })
            }
            .onAppear {
                dotCenter = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                dotCanvasSize = geo.size
            }
        }
        .cornerRadius(24)
        .padding(.horizontal, 20)
    }
}

// MARK: - Summary

extension DrillSessionView {
    var summaryView: some View {
        ScrollView {
            VStack(spacing: 0) {

                // Score ring — larger, more impact
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.08), lineWidth: 16)
                        .frame(width: 160, height: 160)

                    Circle()
                        .trim(from: 0, to: summaryRingProgress)
                        .stroke(type.accentColor,
                                style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.2, dampingFraction: 0.72), value: summaryRingProgress)

                    VStack(spacing: 4) {
                        Text("\(finalScore?.primaryPercent ?? 0)%")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                            .contentTransition(.numericText())
                        Text(finalScore?.label ?? "")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textSecondary)
                            .textCase(.uppercase)
                            .kerning(0.5)
                    }
                }
                .padding(.top, 52)
                .padding(.bottom, 14)

                Text(summaryTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .padding(.bottom, 5)

                Text(finalScore?.feedbackMessage ?? "")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 24)

                // Exercise-specific result visualization
                resultVisualization
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                // Breakdown — big stat chips instead of tiny progress bars
                if let score = finalScore, !score.breakdown.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: score.breakdown.count > 2 ? 2 : score.breakdown.count), spacing: 12) {
                        ForEach(Array(score.breakdown.enumerated()), id: \.offset) { idx, item in
                            let pct = Int(item.value * 100)
                            let color: Color = pct >= 70 ? .metricGreen : pct >= 40 ? type.accentColor : .metricOrange
                            VStack(spacing: 6) {
                                Text("\(pct)%")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(color)
                                    .scaleEffect(summaryAppeared ? 1 : 0.6)
                                    .opacity(summaryAppeared ? 1 : 0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(idx) * 0.1), value: summaryAppeared)
                                Text(item.label)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color.cardBackground))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                // Personal best
                if let score = finalScore,
                   let best = settings.bestScore(for: type),
                   score.primary >= best {
                    HStack(spacing: 10) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                        Text("New personal best!")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.yellow.opacity(0.10))
                    .cornerRadius(20)
                    .padding(.bottom, 20)
                }

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    if isSteadySession, let next = onNextPhase {
                        Button { next() } label: {
                            HStack(spacing: 8) {
                                Text("Next Phase")
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(type.accentColor).cornerRadius(16)
                        }
                        Button { resetSession() } label: {
                            Text("Try Again")
                                .font(.system(size: 15))
                                .foregroundColor(.textSecondary)
                        }
                    } else {
                        Button { resetSession() } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Try Again")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 56)
                            .background(type.accentColor).cornerRadius(16)
                        }
                        Button { dismiss() } label: {
                            Text("Back to Exercises")
                                .font(.system(size: 15))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 44)
            }
        }
        .background(Color.appBackground)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                summaryAppeared = true
            }
        }
    }

    @ViewBuilder
    var resultVisualization: some View {
        switch type {
        case .tremorTrace:    tremorTraceResult
        case .corridorPath:   corridorPathResult
        case .dotHold:        dotHoldScatterResult
        case .pressureWave:   pressureWaveResult
        case .shrinkingTarget: shrinkingTargetResult
        }
    }

    // Tremor EKG
    var tremorTraceResult: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Tremor Signature")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)

            if deviationSamples.count > 4 {
                Canvas { context, size in
                    let midY = size.height / 2
                    let stepX = size.width / CGFloat(deviationSamples.count)
                    let scale: CGFloat = min(size.height / 60.0, 2.0)
                    var path = Path()
                    for (i, dev) in deviationSamples.enumerated() {
                        let x = CGFloat(i) * stepX
                        let y = midY + dev * scale
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(type.accentColor.opacity(0.8)),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    var baseline = Path()
                    baseline.move(to: CGPoint(x: 0, y: midY))
                    baseline.addLine(to: CGPoint(x: size.width, y: midY))
                    context.stroke(baseline, with: .color(.gray.opacity(0.2)),
                                   style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .frame(height: 80)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground))
            } else {
                Text("Draw a line to see your EKG")
                    .font(.system(size: 14)).foregroundColor(.textSecondary)
                    .frame(height: 80).frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground))
            }
        }
    }

    // Corridor replay map
    var corridorPathResult: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Path")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)

            Canvas { ctx, size in
                guard corridorCenterPoints.count > 1 else { return }
                let pad: CGFloat = 12

                // Compute bounding box of ALL points (corridor + user) so we
                // normalize into the result canvas regardless of original canvas size
                let allPts = corridorCenterPoints + corridorUserPoints
                let minX = allPts.map { $0.x }.min() ?? 0
                let maxX = allPts.map { $0.x }.max() ?? 1
                let minY = allPts.map { $0.y }.min() ?? 0
                let maxY = allPts.map { $0.y }.max() ?? 1
                let srcW = max(maxX - minX, 1)
                let srcH = max(maxY - minY, 1)
                let scaleX = (size.width  - pad * 2) / srcW
                let scaleY = (size.height - pad * 2) / srcH
                let scale  = min(scaleX, scaleY)
                // Center inside result box
                let offX = pad + (size.width  - pad*2 - srcW*scale) / 2
                let offY = pad + (size.height - pad*2 - srcH*scale) / 2

                let fit: (CGPoint) -> CGPoint = { pt in
                    CGPoint(x: (pt.x - minX) * scale + offX,
                            y: (pt.y - minY) * scale + offY)
                }

                // Corridor band (background)
                var center = Path()
                for (i, pt) in corridorCenterPoints.enumerated() {
                    let p = fit(pt)
                    if i == 0 { center.move(to: p) } else { center.addLine(to: p) }
                }
                ctx.stroke(center, with: .color(type.accentColor.opacity(0.15)),
                           style: StrokeStyle(lineWidth: max(corridorWidth * scale, 8),
                                              lineCap: .round, lineJoin: .round))
                ctx.stroke(center, with: .color(type.accentColor.opacity(0.12)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                // User trace colored green/red per segment
                if corridorUserPoints.count > 1 {
                    for i in 1..<corridorUserPoints.count {
                        let pt = corridorUserPoints[i]
                        let minDist = corridorCenterPoints
                            .map { hypot(pt.x - $0.x, pt.y - $0.y) }.min() ?? 100
                        let inside = minDist <= corridorWidth / 2
                        var seg = Path()
                        seg.move(to: fit(corridorUserPoints[i - 1]))
                        seg.addLine(to: fit(pt))
                        ctx.stroke(seg,
                                   with: .color(inside ? Color.green : Color.red),
                                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    }
                }

                // Start / end dots
                if let first = corridorCenterPoints.first {
                    ctx.fill(Path(ellipseIn: CGRect(x: fit(first).x - 5, y: fit(first).y - 5,
                                                    width: 10, height: 10)), with: .color(Color.green))
                }
                if let last = corridorCenterPoints.last {
                    ctx.fill(Path(ellipseIn: CGRect(x: fit(last).x - 5, y: fit(last).y - 5,
                                                    width: 10, height: 10)), with: .color(Color.red))
                }
            }
            .frame(height: 110)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground))
        }
    }

    // Dot hold scatter
    var dotHoldScatterResult: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tremor Scatter Map")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxDist = touchPoints.map { hypot($0.x - dotCenter.x, $0.y - dotCenter.y) }.max() ?? 1
                let scale = min(size.width / (maxDist * 4 + 1), 5.0)

                // Zone rings
                for (radius, color): (CGFloat, Color) in [(8, Color.green), (20, Color.yellow), (40, Color.red)] {
                    let r = radius * scale
                    context.stroke(Path(ellipseIn: CGRect(x: center.x-r, y: center.y-r, width: r*2, height: r*2)),
                                   with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: 1))
                }

                for pt in touchPoints {
                    let dx = (pt.x - dotCenter.x) * scale
                    let dy = (pt.y - dotCenter.y) * scale
                    let dist = hypot(dx, dy)
                    let color: Color = dist < 8*scale ? .green : dist < 20*scale ? Color(red:0.95,green:0.75,blue:0) : .red
                    let r: CGFloat = 3
                    context.fill(Path(ellipseIn: CGRect(x: center.x+dx-r, y: center.y+dy-r,
                                                        width: r*2, height: r*2)),
                                 with: .color(color.opacity(0.7)))
                }

                var ch = Path()
                ch.move(to: CGPoint(x: center.x-8, y: center.y))
                ch.addLine(to: CGPoint(x: center.x+8, y: center.y))
                var cv = Path()
                cv.move(to: CGPoint(x: center.x, y: center.y-8))
                cv.addLine(to: CGPoint(x: center.x, y: center.y+8))
                context.stroke(ch, with: .color(type.accentColor.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5))
                context.stroke(cv, with: .color(type.accentColor.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5))
            }
            .frame(height: 120)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground))

            // Stats row
            if touchPoints.count > 5 {
                let maxDist = touchPoints.map { hypot($0.x - dotCenter.x, $0.y - dotCenter.y) }.max() ?? 0
                HStack(spacing: 12) {
                    StatChip(label: "Tremor radius", value: String(format: "%.1fpt", maxDist), color: type.accentColor)
                    StatChip(label: "Samples", value: "\(touchPoints.count)", color: type.accentColor)
                }
            }
        }
    }

    // Pressure wave result
    var pressureWaveResult: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pressure Recording")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)

            if forceSamples.count > 4 {
                Canvas { context, size in
                    let samples = Array(forceSamples.suffix(180))
                    let stepX = size.width / CGFloat(max(samples.count - 1, 1))
                    let greenTop = size.height * 0.25
                    let greenBot = size.height * 0.75
                    context.fill(Path(CGRect(x: 0, y: greenTop,
                                            width: size.width, height: greenBot - greenTop)),
                                 with: .color(Color.green.opacity(0.07)))
                    for i in 1..<samples.count {
                        let x0 = CGFloat(i-1) * stepX, x1 = CGFloat(i) * stepX
                        let y0 = size.height * (1.0 - CGFloat(samples[i-1]))
                        let y1 = size.height * (1.0 - CGFloat(samples[i]))
                        let inside = y1 >= greenTop && y1 <= greenBot
                        var seg = Path()
                        seg.move(to: CGPoint(x: x0, y: y0))
                        seg.addLine(to: CGPoint(x: x1, y: y1))
                        context.stroke(seg, with: .color(inside ? Color.green : Color.red),
                                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                }
                .frame(height: 80)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "hand.point.up")
                        .font(.system(size: 22))
                        .foregroundColor(type.accentColor)
                    Text("Touch the screen next time to record your pressure pattern")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(3)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground))
            }
        }
    }

    var shrinkingTargetResult: some View {
        HStack(spacing: 12) {
            StatChip(label: "Smallest radius",
                     value: "\(Int(smallestRadiusHeld))pt",
                     color: type.accentColor)
            StatChip(label: "Total hold time",
                     value: String(format: "%.1fs", totalHoldTime),
                     color: type.accentColor)
        }
    }

    var summaryTitle: String {
        guard let s = finalScore else { return "Session Complete" }
        if s.primary > 0.72 { return "Great Work" }
        if s.primary > 0.45 { return "Keep Going" }
        return "Good Effort"
    }
}

// MARK: - Session Flow

extension DrillSessionView {

    func beginCountdown() {
        // In steady session, only the very first phase gets a countdown
        if isSteadySession && type != DrillType.allCases.first {
            startActiveSession()
            return
        }

        withAnimation { phase = .countdown(3) }
        countdownValue = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if self.countdownValue > 1 {
                    self.countdownValue -= 1
                    withAnimation { self.phase = .countdown(self.countdownValue) }
                    self.playHaptic(.light)
                } else if self.countdownValue == 1 {
                    self.countdownValue = 0
                    withAnimation { self.phase = .countdown(0) }
                    self.playHapticSuccess()
                } else {
                    self.countdownTimer?.invalidate()
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    self.startActiveSession()
                }
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    func startActiveSession() {
        withAnimation { phase = .active }
        sessionProgress = 0
        elapsedSeconds = 0
        setupHaptics()

        // Canvas-driven drills (tremor trace, corridor, dot hold) don't need a
        // countdown timer auto-ending them — user taps Done or smartProgress hits 1.0.
        // Timed drills (shrinking target, pressure wave) need the timer.
        let needsTimer = (type == .shrinkingTarget || type == .pressureWave)

        guard needsTimer else { return }

        let total = type.sessionDuration
        let interval: Double = 0.1
        var step: Double = 0

        sessionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                step += 1
                self.sessionProgress = CGFloat(step / (total / interval))

                // Band narrows at 5s for pressure wave
                if self.type == .pressureWave {
                    self.bandNarrowProgress = CGFloat(step / (5.0 / interval))
                }

                if Int(step) % 10 == 0 { self.elapsedSeconds += 1 }

                // Warning haptic 3s before end
                if Int(step) == Int((total - 3.0) / interval) {
                    self.playHaptic(.medium)
                }

                if self.sessionProgress >= 1.0 {
                    self.sessionTimer?.invalidate()
                    self.endSession()
                }
            }
        }
        RunLoop.main.add(sessionTimer!, forMode: .common)
    }

    func endSession() {
        stopAllTimers()
        playHapticSuccess()

        let score: MotorAnalysisEngine.DrillScore
        switch type {
        case .tremorTrace:
            if let stroke = canvasView.drawing.strokes.last {
                score = MotorAnalysisEngine.scoreTremorTrace(stroke: stroke)
                deviationSamples = MotorAnalysisEngine.tremorDeviations(from: stroke)
            } else {
                score = latestScore ?? MotorAnalysisEngine.zeroScore("Tremor Index")
            }

        case .corridorPath:
            score = MotorAnalysisEngine.scoreCorridorPath(
                userPoints: corridorUserPoints,
                corridorPoints: corridorCenterPoints,
                corridorWidth: corridorWidth
            )

        case .shrinkingTarget:
            score = MotorAnalysisEngine.scoreShrinkingTarget(
                smallestRadiusHeld: smallestRadiusHeld,
                startingRadius: 80,
                totalHoldTime: totalHoldTime
            )

        case .pressureWave:
            score = MotorAnalysisEngine.scorePressureWave(forceSamples: forceSamples)

        case .dotHold:
            score = MotorAnalysisEngine.scoreDotHold(
                touchPoints: touchPoints,
                targetCenter: dotCenter.x == 0
                    ? CGPoint(x: dotCanvasSize.width/2, y: dotCanvasSize.height/2)
                    : dotCenter
            )
        }

        finalScore = score
        settings.saveDrillSession(type: type, score: score, durationSeconds: elapsedSeconds)

        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { phase = .summary }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            withAnimation { summaryRingProgress = min(score.primary, 1.0) }
        }
    }

    func resetSession() {
        stopAllTimers()
        canvasView.drawing = PKDrawing()
        latestScore = nil
        finalScore = nil
        sessionProgress = 0
        elapsedSeconds = 0
        summaryRingProgress = 0
        summaryAppeared = false
        deviationSamples = []
        tremorTraceMaxX = 0
        forceSamples = []
        currentForce = 0
        bandNarrowProgress = 0
        isOutOfBand = false
        touchPoints = []
        isHolding = false
        holdRingProgress = 0
        targetRadius = 80
        smallestRadiusHeld = 80
        totalHoldTime = 0
        isPencilInTarget = false
        holdProgress = 0
        targetPulse = false
        exitFlash = false
        corridorUserPoints = []
        corridorIsDrawing = false
        lastCorridorPoint = nil
        withAnimation { phase = .intro }
    }

    func stopAllTimers() {
        countdownTimer?.invalidate()
        sessionTimer?.invalidate()
    }
}

// MARK: - Haptics

extension DrillSessionView {

    enum HapticStyle { case light, medium, rigid, soft }

    func setupHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch { }
    }

    func teardownHaptics() {
        hapticEngine?.stop()
        hapticEngine = nil
    }

    func playHaptic(_ style: HapticStyle) {
        // CoreHaptics if available, UIKit fallback
        if let engine = hapticEngine, CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            let intensity: Float
            let sharpness: Float
            switch style {
            case .light:  intensity = 0.45; sharpness = 0.3
            case .medium: intensity = 0.65; sharpness = 0.5
            case .rigid:  intensity = 0.8;  sharpness = 0.9
            case .soft:   intensity = 0.3;  sharpness = 0.1
            }
            let i = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let s = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [i, s], relativeTime: 0)
            if let pattern = try? CHHapticPattern(events: [event], parameters: []),
               let player = try? engine.makePlayer(with: pattern) {
                try? player.start(atTime: 0)
            }
        } else {
            switch style {
            case .light:  UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .rigid:  UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            case .soft:   UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
    }

    func playHapticSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Animated Instruction Card

struct AnimatedInstructionCard: View {
    let type: DrillType

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.animation) { tl in
                let t = CGFloat(tl.date.timeIntervalSinceReferenceDate)
                let phase = CGFloat((t / 2.5).truncatingRemainder(dividingBy: 1.0))

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.systemBackground))
                        .frame(height: 90)

                    demoContent(phase: phase)
                        .frame(height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            Text(type.instructionText)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(type.accentColor.opacity(0.05)))
    }

    @ViewBuilder
    func demoContent(phase: CGFloat) -> some View {
        switch type {
        case .tremorTrace:    TremorTraceDemoView(phase: phase, color: type.accentColor)
        case .corridorPath:   CorridorPathDemoView(phase: phase, color: type.accentColor)
        case .shrinkingTarget: ShrinkingTargetDemoView(phase: phase, color: type.accentColor)
        case .pressureWave:   PressureWaveDemoView(phase: phase, color: type.accentColor)
        case .dotHold:        DotHoldDemoView(phase: phase, color: type.accentColor)
        }
    }
}

// MARK: - Demo Views

struct TremorTraceDemoView: View {
    let phase: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let midY = size.height / 2
            let x0: CGFloat = 16, w = size.width - 32

            // Dashed guide — the target
            var guide = Path()
            guide.move(to: CGPoint(x: x0, y: midY))
            guide.addLine(to: CGPoint(x: x0 + w, y: midY))
            ctx.stroke(guide, with: .color(.gray.opacity(0.22)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))

            // Draw a perfectly straight line progressing left-to-right
            // This shows users exactly what to do: draw straight across
            let endX = x0 + phase * w
            if endX > x0 {
                var line = Path()
                line.move(to: CGPoint(x: x0, y: midY))
                line.addLine(to: CGPoint(x: endX, y: midY))
                ctx.stroke(line, with: .color(color),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Moving pencil tip dot at the front
                ctx.fill(Path(ellipseIn: CGRect(x: endX - 5, y: midY - 5, width: 10, height: 10)),
                         with: .color(color))
            }
        }
    }
}

struct CorridorPathDemoView: View {
    let phase: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            // Draw an S-curve corridor
            let steps = 40
            let halfW: CGFloat = 14
            var centerPts: [CGPoint] = []
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let x = 16 + t * (size.width - 32)
                let y = size.height/2 + sin(t * .pi * 2) * size.height * 0.28
                centerPts.append(CGPoint(x: x, y: y))
            }
            // Corridor band
            var top = Path(), bot = Path()
            for (i, pt) in centerPts.enumerated() {
                let prev = i > 0 ? centerPts[i-1] : pt
                let next = i < centerPts.count-1 ? centerPts[i+1] : pt
                let dx = next.x - prev.x, dy = next.y - prev.y
                let len = hypot(dx, dy)
                guard len > 0 else { continue }
                let nx = -dy/len*halfW, ny = dx/len*halfW
                let tPt = CGPoint(x: pt.x+nx, y: pt.y+ny)
                let bPt = CGPoint(x: pt.x-nx, y: pt.y-ny)
                if i == 0 { top.move(to: tPt); bot.move(to: bPt) }
                else { top.addLine(to: tPt); bot.addLine(to: bPt) }
            }
            ctx.stroke(top, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            ctx.stroke(bot, with: .color(color.opacity(0.3)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))

            // Animated pencil moving along
            let idx = min(Int(phase * CGFloat(centerPts.count)), centerPts.count - 1)
            let pencilPt = centerPts[idx]

            // Trace so far (colored green if inside, red if phase > 0.7 for demo)
            var trace = Path()
            for i in 0..<idx {
                if i == 0 { trace.move(to: centerPts[i]) } else { trace.addLine(to: centerPts[i]) }
            }
            ctx.stroke(trace, with: .color(Color.green.opacity(0.85)),
                       style: StrokeStyle(lineWidth: 3, lineCap: .round))

            // Pencil dot
            ctx.fill(Path(ellipseIn: CGRect(x: pencilPt.x-5, y: pencilPt.y-5, width: 10, height: 10)),
                     with: .color(color))
        }
    }
}

struct ShrinkingTargetDemoView: View {
    let phase: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            let radius: CGFloat = 36 - phase * 24
            Circle()
                .stroke(color.opacity(0.35), lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .fill(color.opacity(phase * 0.10))
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .trim(from: 0, to: phase)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: radius * 2 + 8, height: radius * 2 + 8)
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
    }
}

struct PressureWaveDemoView: View {
    let phase: CGFloat
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let bandTop = size.height * 0.3, bandBot = size.height * 0.7
            ctx.fill(Path(CGRect(x: 0, y: bandTop, width: size.width, height: bandBot - bandTop)),
                     with: .color(Color.green.opacity(0.09)))
            var tl = Path(); tl.move(to: CGPoint(x:0,y:bandTop)); tl.addLine(to: CGPoint(x:size.width,y:bandTop))
            var bl = Path(); bl.move(to: CGPoint(x:0,y:bandBot)); bl.addLine(to: CGPoint(x:size.width,y:bandBot))
            ctx.stroke(tl, with: .color(Color.green.opacity(0.4)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            ctx.stroke(bl, with: .color(Color.green.opacity(0.4)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            let steps = 60
            var wave = Path()
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps)
                let x = t * size.width
                let mid = (bandTop + bandBot) / 2
                let amp = (bandBot - bandTop) * 0.32
                let y = mid + sin(t * .pi * 4 - phase * .pi * 2) * amp
                if i == 0 { wave.move(to: CGPoint(x: x, y: y)) } else { wave.addLine(to: CGPoint(x: x, y: y)) }
            }
            ctx.stroke(wave, with: .color(color), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }
    }
}

struct DotHoldDemoView: View {
    let phase: CGFloat
    let color: Color
    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = CGFloat(i) * .pi / 4
                let p = (phase + CGFloat(i) * 0.125).truncatingRemainder(dividingBy: 1.0)
                let spread: CGFloat = p * 22
                let opacity = Double(1.0 - p) * 0.65
                Circle()
                    .fill(color.opacity(opacity))
                    .frame(width: 5, height: 5)
                    .offset(x: cos(angle) * spread, y: sin(angle) * spread)
            }
            Circle().fill(color).frame(width: 14, height: 14)
                .shadow(color: color.opacity(0.3), radius: 4)
        }
    }
}

// MARK: - Stat Chip

struct StatChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cardBackground))
    }
}

// MARK: - PencilForceCanvas
// UIViewRepresentable that reads live force from BOTH Apple Pencil AND finger.
// Pencil: uses real force data. Finger: simulates steady force with small noise.

struct PencilForceCanvas: UIViewRepresentable {
    @Binding var forceSamples: [CGFloat]
    @Binding var currentForce: CGFloat
    @Binding var isPencilDown: Bool
    var onForceUpdate: (() -> Void)?

    func makeUIView(context: Context) -> PencilForceView {
        let v = PencilForceView()
        v.backgroundColor = UIColor.clear
        v.isUserInteractionEnabled = true
        v.onForce = { force in
            DispatchQueue.main.async {
                self.currentForce = force
                self.isPencilDown = true
                self.forceSamples.append(force)
                if self.forceSamples.count > 400 {
                    self.forceSamples = Array(self.forceSamples.suffix(300))
                }
                self.onForceUpdate?()
            }
        }
        v.onLifted = {
            DispatchQueue.main.async {
                self.isPencilDown = false
                self.currentForce = 0
            }
        }
        return v
    }

    func updateUIView(_ uiView: PencilForceView, context: Context) {
        uiView.onForce = { force in
            DispatchQueue.main.async {
                self.currentForce = force
                self.isPencilDown = true
                self.forceSamples.append(force)
                if self.forceSamples.count > 400 {
                    self.forceSamples = Array(self.forceSamples.suffix(300))
                }
                self.onForceUpdate?()
            }
        }
        uiView.onLifted = {
            DispatchQueue.main.async {
                self.isPencilDown = false
                self.currentForce = 0
            }
        }
    }
}

final class PencilForceView: UIView {
    var onForce: ((CGFloat) -> Void)?
    var onLifted: (() -> Void)?

    private var fingerBaseForce: CGFloat = 0.42
    private var fingerSampleTimer: Timer?

    override var canBecomeFirstResponder: Bool { true }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches, phase: .began)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouches(touches, phase: .moved)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        stopFingerTimer()
        onLifted?()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        stopFingerTimer()
        onLifted?()
    }

    private func handleTouches(_ touches: Set<UITouch>, phase: UITouch.Phase) {
        if let pencilTouch = touches.first(where: { $0.type == .pencil }) {
            stopFingerTimer()
            // maximumPossibleForce is typically ~4.0 on iPad Pro. Use 4.0 as a safe floor
            // and clamp to [0,1] to prevent spurious "too much pressure" glitches.
            let maxF = max(pencilTouch.maximumPossibleForce, 4.0)
            let normalised = max(0.0, min(1.0, pencilTouch.force / maxF))
            onForce?(normalised)
            return
        }
        // Finger fallback: start a 60fps timer emitting simulated steady pressure with micro-noise
        if phase == .began {
            fingerBaseForce = CGFloat.random(in: 0.36...0.52)
            startFingerTimer()
        }
    }

    private func startFingerTimer() {
        guard fingerSampleTimer == nil else { return }
        fingerSampleTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let noise = CGFloat.random(in: -0.045...0.045)
            let f = max(0.05, min(0.95, self.fingerBaseForce + noise))
            self.onForce?(f)
        }
    }

    private func stopFingerTimer() {
        fingerSampleTimer?.invalidate()
        fingerSampleTimer = nil
    }

    deinit { stopFingerTimer() }
}

// MARK: - Path reversing helper

extension Path {
    func reversing() -> Path {
        // Returns a path that can be iterated for fill closing
        var result = Path()
        var points: [CGPoint] = []
        forEach { element in
            switch element {
            case .move(let to): points.append(to)
            case .line(let to): points.append(to)
            case .curve(let to, _, _): points.append(to)
            case .quadCurve(let to, _): points.append(to)
            case .closeSubpath: break
            }
        }
        for (i, pt) in points.reversed().enumerated() {
            if i == 0 { result.move(to: pt) } else { result.addLine(to: pt) }
        }
        return result
    }

    var elements: [Path.Element] {
        var result: [Path.Element] = []
        forEach { result.append($0) }
        return result
    }
}
