import SwiftUI
import PencilKit

struct ContentView: View {

    @StateObject private var settings = AppSettings()
    @EnvironmentObject var gallery: GalleryStore
    @State private var selectedTab: AppTab = .train

    enum AppTab: String, Hashable {
        case train, draw, gallery, progress, settings
    }

    var body: some View {
        NavigationSplitView {
            List {
                // App logo header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(red: 0.92, green: 0.76, blue: 0.30),
                                         Color(red: 0.75, green: 0.52, blue: 0.14)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 40, height: 40)
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Steady Hands")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text("Motor Training")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(.vertical, 6)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                Section("Practice") {
                    SidebarNavRow(tab: .train, icon: "bolt.fill",              label: "Train",   selectedTab: $selectedTab)
                    SidebarNavRow(tab: .draw,  icon: "pencil",                 label: "Draw",    selectedTab: $selectedTab)
                    SidebarNavRow(
                        tab: .gallery,
                        icon: "building.columns.fill",
                        label: "Gallery",
                        badge: gallery.artworks.isEmpty ? nil : "\(gallery.artworks.count)",
                        accentColor: Color(red: 0.85, green: 0.68, blue: 0.22),
                        selectedTab: $selectedTab
                    )
                }
                Section("You") {
                    SidebarNavRow(tab: .progress, icon: "chart.line.uptrend.xyaxis", label: "Progress", selectedTab: $selectedTab)
                    SidebarNavRow(tab: .settings, icon: "gearshape.fill",            label: "Settings",  selectedTab: $selectedTab)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.brandPrimary)

        } detail: {
            Group {
                switch selectedTab {
                case .train:
                    TrainView()
                case .draw:
                    DrawViewWrapper(
                        isActive: selectedTab == .draw,
                        onHangComplete: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedTab = .gallery
                            }
                        }
                    )
                case .gallery:
                    MuseumGalleryView()
                        .ignoresSafeArea()
                case .progress:
                    StatsView()
                case .settings:
                    SettingsView()
                }
            }
            .id(selectedTab)
            .tint(.brandPrimary)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(.hidden, for: .navigationBar)
        .tint(.brandPrimary)
        .environmentObject(settings)
        .environmentObject(gallery)
        .preferredColorScheme(settings.darkMode ? .dark : .light)
        .onAppear {
            styleToggleButton()
            // Re-run after layout so live-rendered buttons are also patched
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { styleToggleButton() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { styleToggleButton() }
        }
    }

    private func styleToggleButton() {
        let brandPurple = UIColor(red: 0.40, green: 0.33, blue: 0.85, alpha: 1.0)

        let itemAppearance = UIBarButtonItemAppearance(style: .plain)
        itemAppearance.normal.backgroundImage      = UIImage()
        itemAppearance.highlighted.backgroundImage = UIImage()
        itemAppearance.focused.backgroundImage     = UIImage()
        itemAppearance.normal.titleTextAttributes      = [.foregroundColor: UIColor.clear]
        itemAppearance.highlighted.titleTextAttributes = [.foregroundColor: UIColor.clear]

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.shadowColor          = .clear
        navAppearance.shadowImage          = UIImage()
        navAppearance.backgroundImage      = UIImage()
        navAppearance.backgroundEffect     = nil
        navAppearance.buttonAppearance     = itemAppearance
        navAppearance.doneButtonAppearance = itemAppearance
        navAppearance.backButtonAppearance = itemAppearance

        UINavigationBar.appearance().standardAppearance          = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance        = navAppearance
        UINavigationBar.appearance().compactAppearance           = navAppearance
        UINavigationBar.appearance().compactScrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor                   = brandPurple

        UIBarButtonItem.appearance().tintColor = brandPurple
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UINavigationBar.self])
            .tintColor = brandPurple

        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithTransparentBackground()
        toolbarAppearance.shadowImage      = UIImage()
        toolbarAppearance.backgroundImage  = UIImage()
        toolbarAppearance.backgroundEffect = nil
        UIToolbar.appearance().standardAppearance          = toolbarAppearance
        UIToolbar.appearance().compactAppearance           = toolbarAppearance
        UIToolbar.appearance().scrollEdgeAppearance        = toolbarAppearance
        UIToolbar.appearance().tintColor                   = brandPurple

        // Walk live hierarchy to strip the glass capsule behind the sidebar toggle
        DispatchQueue.main.async { patchSplitViewToggleButton() }
    }
}

// MARK: - Sidebar Nav Row

struct SidebarNavRow: View {
    let tab: ContentView.AppTab
    let icon: String
    let label: String
    var badge: String? = nil
    var accentColor: Color = .brandPrimary
    @Binding var selectedTab: ContentView.AppTab

    var isSelected: Bool { selectedTab == tab }

    var body: some View {
        Button { selectedTab = tab } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? accentColor : .textSecondary)
                    .frame(width: 22)
                Text(label)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .textPrimary : .textSecondary)
                Spacer()
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accentColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected
                ? RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.12))
                    .padding(.horizontal, 4)
                : nil
        )
    }
}

// MARK: - Canvas State (stable class reference)
// Holds PKCanvasView and PKToolPicker as a class so SwiftUI never
// re-creates them across renders — this is what makes Reset and Undo work.

@MainActor
final class DrawCanvasState: ObservableObject {
    let canvas = PKCanvasView()
    let picker = PKToolPicker()

    @Published var stability: Int = 0
    @Published var pressure: Int = 0
    @Published var rhythm: Int = 0
    @Published var strokeCount: Int = 0

    func reset() {
        canvas.undoManager?.registerUndo(withTarget: canvas) { [weak self] cv in
            _ = self
        }
        canvas.drawing = PKDrawing()
        canvas.undoManager?.removeAllActions()
        stability   = 0
        pressure    = 0
        rhythm      = 0
        strokeCount = 0
    }

    func showPicker() {
        picker.addObserver(canvas)
        picker.setVisible(true, forFirstResponder: canvas)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.canvas.becomeFirstResponder()
        }
    }

    func hidePicker() {
        picker.setVisible(false, forFirstResponder: canvas)
        picker.removeObserver(canvas)
        canvas.resignFirstResponder()
    }
}

// MARK: - DrawViewWrapper

struct DrawViewWrapper: View {
    var isActive: Bool
    var onHangComplete: () -> Void

    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var gallery: GalleryStore

    @StateObject private var canvasState = DrawCanvasState()
    @State private var showReveal = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header — fixed, never affected by toolbar appearing
                HStack(spacing: 20) {
                    MetricLabel(title: "Stability", value: "\(canvasState.stability)%", color: .metricBlue)
                    MetricLabel(title: "Pressure",  value: "\(canvasState.pressure)%",  color: .metricOrange)
                    MetricLabel(title: "Rhythm",    value: "\(canvasState.rhythm)%",    color: .metricGreen)
                    Spacer()

                    Button {
                        canvasState.reset()
                    } label: {
                        Text("Reset")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }

                    if canvasState.strokeCount > 0 {
                        Button {
                            canvasState.hidePicker()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                showReveal = true
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
                .animation(.spring(response: 0.38, dampingFraction: 0.74), value: canvasState.strokeCount > 0)
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 16)

                SteadyCanvasDirect(
                    canvas: canvasState.canvas,
                    settings: settings,
                    onStrokeAdded: analyzeLatestStroke
                )
                .background(Color.white)
                .cornerRadius(20)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxHeight: .infinity)
                .ignoresSafeArea(.keyboard)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .ignoresSafeArea(.keyboard)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            if isActive { canvasState.showPicker() }
        }
        .onDisappear {
            canvasState.hidePicker()
        }
        .onChange(of: isActive) { active in
            active ? canvasState.showPicker() : canvasState.hidePicker()
        }
        .fullScreenCover(isPresented: $showReveal, onDismiss: {
            if isActive { canvasState.showPicker() }
        }) {
            MuseumRevealView(
                drawing: canvasState.canvas.drawing,
                stabilityScore: canvasState.stability,
                pressureScore:  canvasState.pressure,
                rhythmScore:    canvasState.rhythm,
                strokeCount:    canvasState.strokeCount,
                onSave: { title in
                    let artwork = SavedArtwork(
                        title: title,
                        stabilityScore: canvasState.stability,
                        pressureScore:  canvasState.pressure,
                        rhythmScore:    canvasState.rhythm,
                        strokeCount:    canvasState.strokeCount,
                        drawing:        canvasState.canvas.drawing
                    )
                    gallery.save(artwork)
                    settings.saveDrawSession(
                        strokeCount: canvasState.strokeCount,
                        stability:   canvasState.stability,
                        pressure:    canvasState.pressure,
                        rhythm:      canvasState.rhythm
                    )
                    showReveal = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        canvasState.reset()
                        onHangComplete()
                    }
                },
                onDiscard: { showReveal = false }
            )
        }
    }

    private func analyzeLatestStroke() {
        let canvas = canvasState.canvas
        guard let stroke = canvas.drawing.strokes.last else { return }
        let m = MotorAnalysisEngine.analyze(stroke: stroke)
        canvasState.stability   = Int(max(0, min(1, 1.0 - m.tremorAmplitude  / 20.0))  * 100)
        canvasState.pressure    = Int(max(0, min(1, 1.0 - m.pressureVariance / 0.12))  * 100)
        canvasState.rhythm      = Int(max(0, min(1, 1.0 - m.velocityVariance / 450.0)) * 100)
        canvasState.strokeCount = canvas.drawing.strokes.count
    }
}

// MARK: - SteadyCanvasDirect

@MainActor
struct SteadyCanvasDirect: UIViewRepresentable {
    let canvas: PKCanvasView
    let settings: AppSettings
    var onStrokeAdded: (() -> Void)?

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(settings: settings, onStrokeAdded: onStrokeAdded)
    }

    @MainActor
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var settings: AppSettings
        var onStrokeAdded: (() -> Void)?
        private var isProcessing = false
        private var lastKnownStrokeCount = 0

        init(settings: AppSettings, onStrokeAdded: (() -> Void)?) {
            self.settings = settings
            self.onStrokeAdded = onStrokeAdded
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !isProcessing else { return }
            let strokes = canvasView.drawing.strokes
            guard !strokes.isEmpty else {
                lastKnownStrokeCount = 0
                return
            }
            let isNewStroke = strokes.count > lastKnownStrokeCount
            lastKnownStrokeCount = strokes.count

            isProcessing = true
            defer { isProcessing = false }

            var mutableStrokes = Array(strokes)
            var last = mutableStrokes[mutableStrokes.count - 1]

            if settings.jitterThreshold > 0        { last = applyJitter(last) }
            if settings.pressureCompensation       { last = applyPressure(last) }
            if settings.velocityDamping            { last = applyVelocity(last) }
            if settings.strokeStabilization        { last = applyStabilization(last) }
            if settings.tremorFilterStrength > 0   { last = applySmoothing(last) }

            mutableStrokes[mutableStrokes.count - 1] = last
            canvasView.drawing = PKDrawing(strokes: mutableStrokes)

            if isNewStroke {
                DispatchQueue.main.async { [weak self] in self?.onStrokeAdded?() }
            }
        }

        private func applyJitter(_ stroke: PKStroke) -> PKStroke {
            let path = stroke.path
            guard path.count > 2 else { return stroke }
            let threshold = CGFloat(settings.jitterThreshold)
            var filtered: [PKStrokePoint] = [path[0]]
            for i in 1..<path.count {
                let dist = hypot(path[i].location.x - filtered.last!.location.x,
                                 path[i].location.y - filtered.last!.location.y)
                if dist >= threshold { filtered.append(path[i]) }
            }
            guard filtered.count > 1 else { return stroke }
            return PKStroke(ink: stroke.ink, path: PKStrokePath(controlPoints: filtered, creationDate: path.creationDate))
        }

        private func applyPressure(_ stroke: PKStroke) -> PKStroke {
            let path = stroke.path
            guard path.count > 1 else { return stroke }
            let forces = (0..<path.count).map { path[$0].force }
            let mean = forces.reduce(0, +) / CGFloat(forces.count)
            let assist = settings.effectiveAssistLevel
            let pts: [PKStrokePoint] = (0..<path.count).map { i in
                let p = path[i]
                let blended = p.force + (0.5 - mean) * assist * 0.6
                return PKStrokePoint(location: p.location, timeOffset: p.timeOffset,
                                     size: p.size, opacity: p.opacity,
                                     force: max(0.1, min(1.0, blended)),
                                     azimuth: p.azimuth, altitude: p.altitude)
            }
            return PKStroke(ink: stroke.ink, path: PKStrokePath(controlPoints: pts, creationDate: path.creationDate))
        }

        private func applyVelocity(_ stroke: PKStroke) -> PKStroke {
            let path = stroke.path
            guard path.count > 3 else { return stroke }
            let maxDelta: CGFloat = max(8, 40 - settings.effectiveAssistLevel * 30)
            var pts: [PKStrokePoint] = [path[0]]
            for i in 1..<path.count {
                let prev = pts.last!.location
                let curr = path[i].location
                let dist = hypot(curr.x - prev.x, curr.y - prev.y)
                if dist > maxDelta {
                    let r = maxDelta / dist
                    let p = path[i]
                    pts.append(PKStrokePoint(
                        location: CGPoint(x: prev.x + (curr.x - prev.x) * r,
                                          y: prev.y + (curr.y - prev.y) * r),
                        timeOffset: p.timeOffset, size: p.size, opacity: p.opacity,
                        force: p.force, azimuth: p.azimuth, altitude: p.altitude))
                } else { pts.append(path[i]) }
            }
            return PKStroke(ink: stroke.ink, path: PKStrokePath(controlPoints: pts, creationDate: path.creationDate))
        }

        private func applyStabilization(_ stroke: PKStroke) -> PKStroke {
            let path = stroke.path
            guard path.count > 2 else { return stroke }
            let alpha = max(0.15, 1.0 - CGFloat(settings.stabilizationAmount))
            var pts: [PKStrokePoint] = [path[0]]
            for i in 1..<path.count {
                let prev = pts[i-1].location
                let curr = path[i].location
                let sm = CGPoint(x: prev.x + alpha*(curr.x-prev.x),
                                 y: prev.y + alpha*(curr.y-prev.y))
                let p = path[i]
                pts.append(PKStrokePoint(location: sm, timeOffset: p.timeOffset,
                                          size: p.size, opacity: p.opacity,
                                          force: p.force, azimuth: p.azimuth, altitude: p.altitude))
            }
            return PKStroke(ink: stroke.ink, path: PKStrokePath(controlPoints: pts, creationDate: path.creationDate))
        }

        private func applySmoothing(_ stroke: PKStroke) -> PKStroke {
            let path = stroke.path
            guard path.count > 2 else { return stroke }
            let window = max(1, Int(CGFloat(settings.tremorFilterStrength) * 6))
            var pts: [PKStrokePoint] = []
            for i in 0..<path.count {
                let s = max(0, i-window), e = min(path.count-1, i+window)
                var sx: CGFloat = 0, sy: CGFloat = 0, cnt = 0
                for j in s...e { sx += path[j].location.x; sy += path[j].location.y; cnt += 1 }
                let p = path[i]
                pts.append(PKStrokePoint(
                    location: CGPoint(x: sx/CGFloat(cnt), y: sy/CGFloat(cnt)),
                    timeOffset: p.timeOffset, size: p.size, opacity: p.opacity,
                    force: p.force, azimuth: p.azimuth, altitude: p.altitude))
            }
            return PKStroke(ink: stroke.ink, path: PKStrokePath(controlPoints: pts, creationDate: path.creationDate))
        }
    }
}

// MetricLabel is defined in DrawView.swift — no redeclaration here.
