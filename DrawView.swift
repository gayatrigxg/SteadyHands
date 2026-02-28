import SwiftUI
import PencilKit

// MARK: - DrawView

struct DrawView: View {

    var isActive: Bool

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gallery: GalleryStore

    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()
    @State private var clearTrigger: Int = 0

    @State private var stability: Int = 0
    @State private var pressure: Int = 0
    @State private var rhythm: Int = 0
    @State private var strokeCount: Int = 0

    @State private var showMuseumReveal = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                HStack(spacing: 20) {
                    MetricLabel(title: "Stability", value: "\(stability)%", color: .metricBlue)
                    MetricLabel(title: "Pressure",  value: "\(pressure)%",  color: .metricOrange)
                    MetricLabel(title: "Rhythm",    value: "\(rhythm)%",    color: .metricGreen)
                    Spacer()

                    Button { resetCanvas() } label: {
                        Text("Reset")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }

                    if strokeCount > 0 {
                        Button {
                            hidePicker()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showMuseumReveal = true
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "building.columns.fill")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Hang It")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(LinearGradient(
                                colors: [Color(red: 0.92, green: 0.76, blue: 0.30),
                                         Color(red: 0.76, green: 0.56, blue: 0.16)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(10)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.74), value: strokeCount > 0)
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 16)

                CanvasWithIdleOverlay(
                    canvasView: $canvasView,
                    showIdle: strokeCount == 0,
                    smoothingEnabled: settings.tremorFilterStrength > 0,
                    assistLevel: settings.effectiveAssistLevel,
                    pressureCompensation: settings.pressureCompensation,
                    velocityDamping: settings.velocityDamping,
                    jitterThreshold: CGFloat(settings.jitterThreshold),
                    strokeStabilization: settings.strokeStabilization,
                    stabilizationAmount: CGFloat(settings.stabilizationAmount),
                    onStrokeAdded: analyzeLatestStroke,
                    clearTrigger: clearTrigger
                )
                .background(Color.white)
                .cornerRadius(20)
                .padding(24)

                Spacer()
            }
        }
        .preferredColorScheme(settings.darkMode ? .dark : .light)
        .onAppear { showPicker() }
        .onDisappear { hidePicker() }
        .onChange(of: isActive) { active in active ? showPicker() : hidePicker() }
        .fullScreenCover(isPresented: $showMuseumReveal, onDismiss: {
            if isActive { showPicker() }
        }) {
            MuseumRevealView(
                drawing: canvasView.drawing,
                stabilityScore: stability,
                pressureScore: pressure,
                rhythmScore: rhythm,
                strokeCount: strokeCount,
                onSave: { title in
                    let artwork = SavedArtwork(
                        title: title,
                        stabilityScore: stability,
                        pressureScore: pressure,
                        rhythmScore: rhythm,
                        strokeCount: strokeCount,
                        drawing: canvasView.drawing
                    )
                    gallery.save(artwork)
                    settings.saveDrawSession(
                        strokeCount: strokeCount,
                        stability: stability,
                        pressure: pressure,
                        rhythm: rhythm
                    )
                    showMuseumReveal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { resetCanvas() }
                },
                onDiscard: { showMuseumReveal = false }
            )
        }
    }

    private func resetCanvas() {
        stability = 0; pressure = 0; rhythm = 0; strokeCount = 0
        clearTrigger += 1
    }

    private func showPicker() {
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
    }

    private func hidePicker() {
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        toolPicker.removeObserver(canvasView)
        canvasView.resignFirstResponder()
    }

    private func analyzeLatestStroke() {
        guard let stroke = canvasView.drawing.strokes.last else { return }
        let m = MotorAnalysisEngine.analyze(stroke: stroke)
        stability   = Int(max(0, min(1, 1.0 - m.tremorAmplitude  / 20.0))  * 100)
        pressure    = Int(max(0, min(1, 1.0 - m.pressureVariance / 0.12))  * 100)
        rhythm      = Int(max(0, min(1, 1.0 - m.velocityVariance / 450.0)) * 100)
        strokeCount = canvasView.drawing.strokes.count
    }
}

// MARK: - CanvasWithIdleOverlay (UIViewRepresentable)

struct CanvasWithIdleOverlay: UIViewRepresentable {

    @Binding var canvasView: PKCanvasView
    var showIdle: Bool

    var smoothingEnabled: Bool
    var assistLevel: CGFloat
    var pressureCompensation: Bool
    var velocityDamping: Bool
    var jitterThreshold: CGFloat
    var strokeStabilization: Bool
    var stabilizationAmount: CGFloat
    var onStrokeAdded: (() -> Void)?
    var clearTrigger: Int

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.clipsToBounds = true

        // Add PKCanvasView filling container
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.delegate = context.coordinator
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: container.topAnchor),
            canvasView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            canvasView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        // Build pure-UIKit idle overlay and add it on top
        let idleView = IdleOverlayUIView()
        idleView.translatesAutoresizingMaskIntoConstraints = false
        idleView.isUserInteractionEnabled = false
        container.addSubview(idleView)
        NSLayoutConstraint.activate([
            idleView.topAnchor.constraint(equalTo: container.topAnchor),
            idleView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            idleView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            idleView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        idleView.startAnimating()

        context.coordinator.idleView = idleView
        context.coordinator.configure(
            smoothingEnabled: smoothingEnabled, assistLevel: assistLevel,
            pressureCompensation: pressureCompensation, velocityDamping: velocityDamping,
            jitterThreshold: jitterThreshold, strokeStabilization: strokeStabilization,
            stabilizationAmount: stabilizationAmount, onStrokeAdded: onStrokeAdded
        )
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.configure(
            smoothingEnabled: smoothingEnabled, assistLevel: assistLevel,
            pressureCompensation: pressureCompensation, velocityDamping: velocityDamping,
            jitterThreshold: jitterThreshold, strokeStabilization: strokeStabilization,
            stabilizationAmount: stabilizationAmount, onStrokeAdded: onStrokeAdded
        )

        UIView.animate(withDuration: 0.35) {
            context.coordinator.idleView?.alpha = showIdle ? 1 : 0
        }

        if context.coordinator.lastClearTrigger != clearTrigger {
            context.coordinator.lastClearTrigger = clearTrigger
            context.coordinator.isClearing = true
            canvasView.delegate = nil
            canvasView.drawing = PKDrawing()
            context.coordinator.isProcessing = false
            context.coordinator.lastKnownStrokeCount = 0
            canvasView.delegate = context.coordinator
            context.coordinator.isClearing = false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var smoothingEnabled = true
        var assistLevel: CGFloat = 0.5
        var pressureCompensation = false
        var velocityDamping = false
        var jitterThreshold: CGFloat = 1.5
        var strokeStabilization = false
        var stabilizationAmount: CGFloat = 0.4
        var onStrokeAdded: (() -> Void)?

        var idleView: IdleOverlayUIView?
        var lastClearTrigger = 0
        var isClearing = false
        var isProcessing = false
        var lastKnownStrokeCount = 0

        func configure(smoothingEnabled: Bool, assistLevel: CGFloat,
                       pressureCompensation: Bool, velocityDamping: Bool,
                       jitterThreshold: CGFloat, strokeStabilization: Bool,
                       stabilizationAmount: CGFloat, onStrokeAdded: (() -> Void)?) {
            self.smoothingEnabled = smoothingEnabled; self.assistLevel = assistLevel
            self.pressureCompensation = pressureCompensation; self.velocityDamping = velocityDamping
            self.jitterThreshold = jitterThreshold; self.strokeStabilization = strokeStabilization
            self.stabilizationAmount = stabilizationAmount; self.onStrokeAdded = onStrokeAdded
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isClearing, !isProcessing else { return }
            let strokes = canvasView.drawing.strokes
            guard !strokes.isEmpty else { lastKnownStrokeCount = 0; return }
            let isNewStroke = strokes.count > lastKnownStrokeCount
            lastKnownStrokeCount = strokes.count
            isProcessing = true

            var s = Array(strokes)
            var last = s[s.count - 1]
            if jitterThreshold > 0      { last = applyJitter(last) }
            if pressureCompensation     { last = applyPressure(last) }
            if velocityDamping          { last = applyVelocity(last) }
            if strokeStabilization      { last = applyStabilization(last) }
            if smoothingEnabled         { last = applySmoothing(last) }
            s[s.count - 1] = last
            canvasView.drawing = PKDrawing(strokes: s)

            if isNewStroke {
                DispatchQueue.main.async { [weak self] in self?.onStrokeAdded?() }
            }
            isProcessing = false
        }

        private func applyJitter(_ stroke: PKStroke) -> PKStroke {
            let path = stroke.path; guard path.count > 2 else { return stroke }
            var f: [PKStrokePoint] = [path[0]]
            for i in 1..<path.count {
                let p = path[i], prev = f.last!.location
                if hypot(p.location.x - prev.x, p.location.y - prev.y) >= jitterThreshold { f.append(p) }
            }
            guard f.count > 1 else { return stroke }
            return PKStroke(ink: stroke.ink, path: PKStrokePath(controlPoints: f, creationDate: path.creationDate))
        }

        private func applyPressure(_ stroke: PKStroke) -> PKStroke {
            let path = stroke.path; guard path.count > 1 else { return stroke }
            let mean = (0..<path.count).map { path[$0].force }.reduce(0,+) / CGFloat(path.count)
            let pts: [PKStrokePoint] = (0..<path.count).map { i in
                let p = path[i]
                let f = max(0.1, min(1.0, p.force + (0.5 - mean) * assistLevel * 0.6))
                return PKStrokePoint(location: p.location, timeOffset: p.timeOffset, size: p.size, opacity: p.opacity, force: f, azimuth: p.azimuth, altitude: p.altitude)
            }
            return PKStroke(ink: stroke.ink, path: PKStrokePath(controlPoints: pts, creationDate: path.creationDate))
        }

        private func applyVelocity(_ stroke: PKStroke) -> PKStroke {
            let path = stroke.path; guard path.count > 3 else { return stroke }
            let maxD: CGFloat = max(8, 40 - assistLevel * 30)
            var pts: [PKStrokePoint] = [path[0]]
            for i in 1..<path.count {
                let prev = pts.last!.location, curr = path[i].location
                let dist = hypot(curr.x - prev.x, curr.y - prev.y)
                let p = path[i]
                if dist > maxD {
                    let r = maxD / dist
                    pts.append(PKStrokePoint(location: CGPoint(x: prev.x + (curr.x-prev.x)*r, y: prev.y + (curr.y-prev.y)*r), timeOffset: p.timeOffset, size: p.size, opacity: p.opacity, force: p.force, azimuth: p.azimuth, altitude: p.altitude))
                } else { pts.append(p) }
            }
            return PKStroke(ink: stroke.ink, path: PKStrokePath(controlPoints: pts, creationDate: path.creationDate))
        }

        private func applyStabilization(_ stroke: PKStroke) -> PKStroke {
            let path = stroke.path; guard path.count > 2 else { return stroke }
            let alpha = max(0.15, 1.0 - stabilizationAmount)
            var pts: [PKStrokePoint] = [path[0]]
            for i in 1..<path.count {
                let prev = pts[i-1].location, curr = path[i].location, p = path[i]
                let s = CGPoint(x: prev.x + alpha*(curr.x-prev.x), y: prev.y + alpha*(curr.y-prev.y))
                pts.append(PKStrokePoint(location: s, timeOffset: p.timeOffset, size: p.size, opacity: p.opacity, force: p.force, azimuth: p.azimuth, altitude: p.altitude))
            }
            return PKStroke(ink: stroke.ink, path: PKStrokePath(controlPoints: pts, creationDate: path.creationDate))
        }

        private func applySmoothing(_ stroke: PKStroke) -> PKStroke {
            let path = stroke.path; guard path.count > 2 else { return stroke }
            let w = max(1, Int(assistLevel * 6))
            var pts: [PKStrokePoint] = []
            for i in 0..<path.count {
                let p = path[i]
                let s = max(0, i-w), e = min(path.count-1, i+w)
                var sx: CGFloat = 0, sy: CGFloat = 0, c = 0
                for j in s...e { sx += path[j].location.x; sy += path[j].location.y; c += 1 }
                pts.append(PKStrokePoint(location: CGPoint(x: sx/CGFloat(c), y: sy/CGFloat(c)), timeOffset: p.timeOffset, size: p.size, opacity: p.opacity, force: p.force, azimuth: p.azimuth, altitude: p.altitude))
            }
            return PKStroke(ink: stroke.ink, path: PKStrokePath(controlPoints: pts, creationDate: path.creationDate))
        }
    }
}

// MARK: - IdleOverlayUIView
// 100% UIKit — no SwiftUI, no hosting controller.
// Uses CAShapeLayer + CABasicAnimation to draw the shaky→smooth loop.

final class IdleOverlayUIView: UIView {

    // Card
    private let card = UIView()

    // Line layers
    private let shakyLayer = CAShapeLayer()
    private let smoothLayer = CAShapeLayer()

    // Labels
    private let beforeLabel = UILabel()
    private let afterLabel  = UILabel()
    private let hintLabel   = UILabel()

    // Icon image views
    private let beforeIcon = UIImageView()
    private let afterIcon  = UIImageView()

    // Label stacks
    private let beforeStack = UIStackView()
    private let afterStack  = UIStackView()

    // Track animation loop
    private var isLooping = false
    private let accent = UIColor(red: 0.40, green: 0.33, blue: 0.85, alpha: 1)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    // MARK: Setup

    private func setup() {
        backgroundColor = .clear

        // Card
        card.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        card.layer.cornerRadius = 24
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.10
        card.layer.shadowRadius = 20
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        // Shaky line layer
        shakyLayer.fillColor = UIColor.clear.cgColor
        shakyLayer.strokeColor = accent.withAlphaComponent(0.30).cgColor
        shakyLayer.lineWidth = 3
        shakyLayer.lineCap = .round
        shakyLayer.lineJoin = .round
        card.layer.addSublayer(shakyLayer)

        // Smooth line layer
        smoothLayer.fillColor = UIColor.clear.cgColor
        smoothLayer.strokeColor = accent.cgColor
        smoothLayer.lineWidth = 3.5
        smoothLayer.lineCap = .round
        smoothLayer.strokeEnd = 0
        card.layer.addSublayer(smoothLayer)

        // Before label stack
        beforeIcon.image = UIImage(systemName: "waveform.path.ecg")
        beforeIcon.tintColor = accent.withAlphaComponent(0.5)
        beforeIcon.contentMode = .scaleAspectFit
        beforeIcon.translatesAutoresizingMaskIntoConstraints = false
        beforeIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true

        beforeLabel.text = "Your tremor, as drawn"
        beforeLabel.font = .systemFont(ofSize: 14)
        beforeLabel.textColor = .secondaryLabel

        beforeStack.axis = .horizontal
        beforeStack.spacing = 6
        beforeStack.alignment = .center
        beforeStack.addArrangedSubview(beforeIcon)
        beforeStack.addArrangedSubview(beforeLabel)
        beforeStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(beforeStack)

        // After label stack
        afterIcon.image = UIImage(systemName: "sparkles")
        afterIcon.tintColor = accent
        afterIcon.contentMode = .scaleAspectFit
        afterIcon.translatesAutoresizingMaskIntoConstraints = false
        afterIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true

        afterLabel.text = "Filtered in real time"
        afterLabel.font = .boldSystemFont(ofSize: 14)
        afterLabel.textColor = accent

        afterStack.axis = .horizontal
        afterStack.spacing = 6
        afterStack.alignment = .center
        afterStack.addArrangedSubview(afterIcon)
        afterStack.addArrangedSubview(afterLabel)
        afterStack.translatesAutoresizingMaskIntoConstraints = false
        afterStack.alpha = 0
        card.addSubview(afterStack)

        // Hint
        hintLabel.text = "Start drawing to begin"
        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = .tertiaryLabel
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(hintLabel)

        // Card constraints — centered, fixed width
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 300),

            beforeStack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            beforeStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 100),

            afterStack.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            afterStack.topAnchor.constraint(equalTo: beforeStack.topAnchor),

            hintLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: beforeStack.bottomAnchor, constant: 16),
            hintLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -28)
        ])
    }

    // MARK: Layout — draw lines after bounds are known

    override func layoutSubviews() {
        super.layoutSubviews()
        guard card.bounds.width > 0 else { return }

        let lineW: CGFloat = 240
        let lineH: CGFloat = 56
        let lineX: CGFloat = (card.bounds.width - lineW) / 2
        let lineY: CGFloat = 28

        // Shaky path
        let shaky = UIBezierPath()
        let steps = 100
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = lineX + t * lineW
            let midY = lineY + lineH / 2
            let amp: CGFloat = 10
            let y = midY
                + sin(t * .pi * 2.2) * amp * 0.35
                + sin(t * .pi * 11)  * amp
                + sin(t * .pi * 19)  * amp * 0.45
            if i == 0 { shaky.move(to: CGPoint(x: x, y: y)) }
            else { shaky.addLine(to: CGPoint(x: x, y: y)) }
        }
        shakyLayer.path = shaky.cgPath
        shakyLayer.frame = card.bounds

        // Smooth path
        let smooth = UIBezierPath()
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = lineX + t * lineW
            let midY = lineY + lineH / 2
            let y = midY + sin(t * .pi) * 2.5
            if i == 0 { smooth.move(to: CGPoint(x: x, y: y)) }
            else { smooth.addLine(to: CGPoint(x: x, y: y)) }
        }
        smoothLayer.path = smooth.cgPath
        smoothLayer.frame = card.bounds

        if !isLooping { startAnimating() }
    }

    // MARK: Animation loop

    func startAnimating() {
        isLooping = true
        runLoop()
    }

    private func runLoop() {
        guard isLooping else { return }

        // Reset
        smoothLayer.strokeEnd = 0
        beforeStack.alpha = 1
        afterStack.alpha  = 0
        shakyLayer.opacity = 1

        // 1. Draw shaky line (strokeEnd 0→1 over 1.1s)
        let drawShaky = CABasicAnimation(keyPath: "strokeEnd")
        drawShaky.fromValue = 0
        drawShaky.toValue   = 1
        drawShaky.duration  = 1.1
        drawShaky.fillMode  = .forwards
        drawShaky.isRemovedOnCompletion = false
        shakyLayer.add(drawShaky, forKey: "drawShaky")

        // 2. After 1.6s: draw smooth line, swap labels
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            guard let self, self.isLooping else { return }

            let drawSmooth = CABasicAnimation(keyPath: "strokeEnd")
            drawSmooth.fromValue = 0
            drawSmooth.toValue   = 1
            drawSmooth.duration  = 0.9
            drawSmooth.fillMode  = .forwards
            drawSmooth.isRemovedOnCompletion = false
            self.smoothLayer.add(drawSmooth, forKey: "drawSmooth")
            self.smoothLayer.strokeEnd = 1

            // Fade out shaky, swap label
            UIView.animate(withDuration: 0.4) {
                self.shakyLayer.opacity = 0.15
                self.beforeStack.alpha  = 0
                self.afterStack.alpha   = 1
            }
        }

        // 3. After 3.8s: reset and loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) { [weak self] in
            guard let self, self.isLooping else { return }
            self.shakyLayer.removeAllAnimations()
            self.smoothLayer.removeAllAnimations()
            self.runLoop()
        }
    }

    func stopAnimating() {
        isLooping = false
        shakyLayer.removeAllAnimations()
        smoothLayer.removeAllAnimations()
    }
}

// MARK: - Metric Label

struct MetricLabel: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(title):")
                .font(.system(size: 14)).foregroundColor(.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.textPrimary)
        }
    }
}
