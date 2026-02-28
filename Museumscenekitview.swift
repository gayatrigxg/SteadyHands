import SwiftUI
import RealityKit
import PencilKit
import UIKit

// MARK: - Museum RealityKit 3D View
// Dark moody museum. Auto-tour plays on entry (camera glides painting to painting).
// Any touch stops the tour and hands free control to the user.
// Tap the "Tour" button to restart the auto-tour.

@available(iOS 17.0, *)
struct MuseumSceneKitView: View {

    let allArtworks:    [SavedArtwork]
    let focusedArtwork: SavedArtwork

    @Environment(\.dismiss) var dismiss

    // UI
    @State private var uiOpacity:        Double = 0
    @State private var plaqueOpacity:    Double = 0
    @State private var currentTitle:     String = ""
    @State private var currentDate:      String = ""
    @State private var currentStability: Int    = 0
    @State private var showControls:     Bool   = true
    @State private var controlsTimer:    Timer? = nil

    // Tour
    @State private var isAutoTouring:    Bool   = false
    @State private var tourBadgeOpacity: Double = 0

    var body: some View {
        ZStack {
            // ── 3D Scene ──────────────────────────────────────────────
            MuseumRealityView(
                allArtworks:    allArtworks,
                focusedArtwork: focusedArtwork,
                onFocusChanged: { artwork in
                    withAnimation(.easeInOut(duration: 0.30)) { plaqueOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                        currentTitle      = artwork.title
                        currentDate       = artwork.shortDate
                        currentStability  = artwork.stabilityScore
                        withAnimation(.easeIn(duration: 0.40)) { plaqueOpacity = 1 }
                    }
                },
                onUserInteraction: {
                    stopTour()
                    resetControlsTimer()
                },
                onTourStateChanged: { touring in
                    isAutoTouring = touring
                }
            )
            .ignoresSafeArea()

            // ── "Auto Tour" running badge ─────────────────────────────
            if isAutoTouring {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        // Animated dots
                        TourPulse()
                        Text("Auto Tour — tap anywhere to take control")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.96, green: 0.88, blue: 0.65))
                    }
                    .padding(.horizontal, 22).padding(.vertical, 11)
                    .background(.ultraThinMaterial)
                    .background(Color(red: 0.06, green: 0.04, blue: 0.02).opacity(0.70))
                    .clipShape(Capsule())
                    .overlay(Capsule()
                        .stroke(Color(red: 0.85, green: 0.65, blue: 0.20).opacity(0.30),
                                lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 14, x: 0, y: 5)
                    .padding(.bottom, 130)
                }
                .transition(.opacity)
            }

            // ── Top bar ───────────────────────────────────────────────
            VStack {
                HStack(alignment: .center) {
                    // Back
                    Button { dismiss() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("Gallery")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.96, green: 0.90, blue: 0.76))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        // Restart tour button
                        Button {
                            restartTour()
                            resetControlsTimer()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Tour")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(
                                isAutoTouring
                                    ? Color(red: 0.85, green: 0.65, blue: 0.20)
                                    : Color(red: 0.96, green: 0.90, blue: 0.76)
                            )
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                        }

                        // Piece count
                        HStack(spacing: 5) {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(red: 0.85, green: 0.68, blue: 0.22))
                            Text("\(allArtworks.count) \(allArtworks.count == 1 ? "piece" : "pieces")")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Color(red: 0.96, green: 0.90, blue: 0.76))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                Spacer()
            }
            .opacity(showControls ? uiOpacity : 0)

            // ── Bottom plaque ─────────────────────────────────────────
            VStack {
                Spacer()
                VStack(spacing: 5) {
                    Text(currentTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(red: 0.97, green: 0.94, blue: 0.86))
                    HStack(spacing: 8) {
                        Text(currentDate)
                        Text("·")
                        Text("Stability \(currentStability)%")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.75, green: 0.62, blue: 0.42))

                    if !isAutoTouring {
                        HStack(spacing: 16) {
                            Label("Drag to walk", systemImage: "arrow.left.and.right")
                            Label("Pinch to zoom", systemImage: "arrow.up.left.and.arrow.down.right")
                            Label("Tap painting", systemImage: "hand.tap")
                        }
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.48, green: 0.38, blue: 0.24))
                        .padding(.top, 1)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isAutoTouring)
                .padding(.horizontal, 28).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .background(Color(red: 0.05, green: 0.03, blue: 0.02).opacity(0.72))
                .cornerRadius(18)
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(red: 0.75, green: 0.58, blue: 0.20).opacity(0.25),
                            lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 6)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
                .opacity(showControls ? plaqueOpacity : 0)
            }
        }
        .onAppear {
            currentTitle      = focusedArtwork.title
            currentDate       = focusedArtwork.shortDate
            currentStability  = focusedArtwork.stabilityScore
            withAnimation(.easeIn(duration: 0.7).delay(0.4)) { uiOpacity    = 1 }
            withAnimation(.easeIn(duration: 0.6).delay(0.7)) { plaqueOpacity = 1 }
            resetControlsTimer()
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    // Called by MuseumRealityView coordinator via onUserInteraction
    private func stopTour() {
        guard isAutoTouring else { return }
        withAnimation(.easeOut(duration: 0.3)) { isAutoTouring = false }
        NotificationCenter.default.post(name: .museumStopTour, object: nil)
    }

    private func restartTour() {
        withAnimation(.easeIn(duration: 0.3)) { isAutoTouring = true }
        NotificationCenter.default.post(name: .museumStartTour, object: nil)
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        if !showControls {
            withAnimation(.easeIn(duration: 0.25)) { showControls = true }
        }
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { _ in
            DispatchQueue.main.async {
                if !self.isAutoTouring {
                    withAnimation(.easeOut(duration: 0.45)) { self.showControls = false }
                }
            }
        }
    }
}

// MARK: - Tour Pulse Indicator

@available(iOS 17.0, *)
private struct TourPulse: View {
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .fill(Color(red: 0.85, green: 0.65, blue: 0.20))
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    scale   = 1.3
                    opacity = 0.4
                }
            }
    }
}

// MARK: - Notification names

extension Notification.Name {
    static let museumStopTour  = Notification.Name("museumStopTour")
    static let museumStartTour = Notification.Name("museumStartTour")
}

// MARK: - UIViewRepresentable

@available(iOS 17.0, *)
struct MuseumRealityView: UIViewRepresentable {

    let allArtworks:       [SavedArtwork]
    let focusedArtwork:    SavedArtwork
    let onFocusChanged:    (SavedArtwork) -> Void
    let onUserInteraction: () -> Void
    let onTourStateChanged:(_ touring: Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(allArtworks:        allArtworks,
                    focusedArtwork:     focusedArtwork,
                    onFocusChanged:     onFocusChanged,
                    onUserInteraction:  onUserInteraction,
                    onTourStateChanged: onTourStateChanged)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero,
                            cameraMode: .nonAR,
                            automaticallyConfigureSession: false)
        // Deep warm-black — like entering a premier gallery at night
        arView.environment.background = .color(
            UIColor(red: 0.05, green: 0.04, blue: 0.03, alpha: 1)
        )
        arView.renderOptions = [.disableMotionBlur]

        let anchor = AnchorEntity(world: .zero)
        buildMuseum(anchor: anchor, context: context)
        arView.scene.addAnchor(anchor)

        setupCamera(arView: arView, context: context)

        // Gestures
        let pan   = UIPanGestureRecognizer(target: context.coordinator,
                                            action: #selector(Coordinator.handlePan(_:)))
        let pinch = UIPinchGestureRecognizer(target: context.coordinator,
                                              action: #selector(Coordinator.handlePinch(_:)))
        let tap   = UITapGestureRecognizer(target: context.coordinator,
                                            action: #selector(Coordinator.handleTap(_:)))
        pan.delegate   = context.coordinator
        pinch.delegate = context.coordinator
        arView.addGestureRecognizer(pan)
        arView.addGestureRecognizer(pinch)
        arView.addGestureRecognizer(tap)
        context.coordinator.arView = arView

        // Notification observers for tour start/stop
        context.coordinator.registerTourObservers()

        // Start auto-tour after a short delay for entrance feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            context.coordinator.startAutoTour()
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    // MARK: - Build Museum

    private func buildMuseum(anchor: AnchorEntity, context: Context) {
        buildRoom(anchor: anchor)
        buildLighting(anchor: anchor)
        buildSculptures(anchor: anchor)
        hangAllArtworks(anchor: anchor, context: context)
    }

    // MARK: Room — deep gallery with warm dark walls and rich detailing

    private func buildRoom(anchor: AnchorEntity) {
        let roomW: Float = 26.0
        let roomH: Float =  8.0
        let roomD: Float = 14.0

        // Near-black walls — very dark so spotlight glow pops
        var wallMat = PhysicallyBasedMaterial()
        wallMat.baseColor = .init(tint: UIColor(red: 0.03, green: 0.02, blue: 0.02, alpha: 1))
        wallMat.roughness = .init(floatLiteral: 0.96)
        wallMat.metallic  = .init(floatLiteral: 0.00)

        // Very dark floor with just a hint of reflective warmth
        var floorMat = PhysicallyBasedMaterial()
        floorMat.baseColor = .init(tint: UIColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 1))
        floorMat.roughness = .init(floatLiteral: 0.28)
        floorMat.metallic  = .init(floatLiteral: 0.14)

        // Near-black ceiling
        var ceilMat = PhysicallyBasedMaterial()
        ceilMat.baseColor = .init(tint: UIColor(red: 0.03, green: 0.02, blue: 0.02, alpha: 1))
        ceilMat.roughness = .init(floatLiteral: 0.99)
        ceilMat.metallic  = .init(floatLiteral: 0.00)

        // Rich dark gold molding
        var moldMat = PhysicallyBasedMaterial()
        moldMat.baseColor = .init(tint: UIColor(red: 0.28, green: 0.20, blue: 0.08, alpha: 1))
        moldMat.roughness = .init(floatLiteral: 0.48)
        moldMat.metallic  = .init(floatLiteral: 0.55)

        // Warm dark baseboard
        var baseMat = PhysicallyBasedMaterial()
        baseMat.baseColor = .init(tint: UIColor(red: 0.14, green: 0.10, blue: 0.06, alpha: 1))
        baseMat.roughness = .init(floatLiteral: 0.70)
        baseMat.metallic  = .init(floatLiteral: 0.10)

        // Dark olive-umber wainscoting — gallery wall texture
        var wainsMat = PhysicallyBasedMaterial()
        wainsMat.baseColor = .init(tint: UIColor(red: 0.09, green: 0.07, blue: 0.05, alpha: 1))
        wainsMat.roughness = .init(floatLiteral: 0.88)

        // Burnished bronze handrail
        var railMat = PhysicallyBasedMaterial()
        railMat.baseColor = .init(tint: UIColor(red: 0.42, green: 0.28, blue: 0.10, alpha: 1))
        railMat.roughness = .init(floatLiteral: 0.38)
        railMat.metallic  = .init(floatLiteral: 0.75)

        // Recessed ceiling coffer — slightly lighter than ceiling
        var cofferMat = PhysicallyBasedMaterial()
        cofferMat.baseColor = .init(tint: UIColor(red: 0.06, green: 0.04, blue: 0.03, alpha: 1))
        cofferMat.roughness = .init(floatLiteral: 0.95)

        // Gold coffer rim
        var cofferRimMat = PhysicallyBasedMaterial()
        cofferRimMat.baseColor = .init(tint: UIColor(red: 0.32, green: 0.22, blue: 0.08, alpha: 1))
        cofferRimMat.roughness = .init(floatLiteral: 0.42)
        cofferRimMat.metallic  = .init(floatLiteral: 0.60)

        // Floor
        addBox(anchor, SIMD3(roomW, 0.10, roomD), SIMD3(0, -0.05, 0), floorMat)
        // Floor accent strip along back wall
        var accentFloorMat = PhysicallyBasedMaterial()
        accentFloorMat.baseColor = .init(tint: UIColor(red: 0.18, green: 0.12, blue: 0.06, alpha: 1))
        accentFloorMat.roughness = .init(floatLiteral: 0.25)
        accentFloorMat.metallic  = .init(floatLiteral: 0.22)
        addBox(anchor, SIMD3(roomW, 0.002, 1.0), SIMD3(0, 0.001, -roomD/2 + 0.5), accentFloorMat)

        // Back wall
        addBox(anchor, SIMD3(roomW, roomH, 0.30), SIMD3(0, roomH/2, -roomD/2), wallMat)
        // Side walls
        addBox(anchor, SIMD3(0.30, roomH, roomD), SIMD3(-roomW/2, roomH/2, 0), wallMat)
        addBox(anchor, SIMD3(0.30, roomH, roomD), SIMD3( roomW/2, roomH/2, 0), wallMat)
        // Ceiling
        addBox(anchor, SIMD3(roomW, 0.30, roomD), SIMD3(0, roomH, 0), ceilMat)

        // Crown molding — gold-tinted, prominent
        addBox(anchor, SIMD3(roomW+0.8, 0.28, 0.30),
               SIMD3(0, roomH-0.14, -roomD/2+0.15), moldMat)
        for xSign: Float in [-1, 1] {
            addBox(anchor, SIMD3(0.30, 0.28, roomD),
                   SIMD3(xSign*(roomW/2-0.15), roomH-0.14, 0), moldMat)
        }
        // Second molding band (double profile)
        addBox(anchor, SIMD3(roomW+0.4, 0.12, 0.18),
               SIMD3(0, roomH-0.50, -roomD/2+0.09), moldMat)

        // Baseboard — tall and substantial
        addBox(anchor, SIMD3(roomW, 0.32, 0.18), SIMD3(0, 0.16, -roomD/2+0.09), baseMat)
        for xSign: Float in [-1, 1] {
            addBox(anchor, SIMD3(0.18, 0.32, roomD),
                   SIMD3(xSign*(roomW/2-0.09), 0.16, 0), baseMat)
        }

        // Wainscoting panel (lower third of back wall)
        addBox(anchor, SIMD3(roomW-0.7, 0.04, 1.60),
               SIMD3(0, 1.65, -roomD/2+0.17), wainsMat)
        // Burnished bronze picture rail
        addBox(anchor, SIMD3(roomW-0.5, 0.14, 0.18),
               SIMD3(0, 2.40, -roomD/2+0.17), railMat)

        // Ceiling coffers — deep recessed panels with gold rims
        for row in 0..<2 {
            for col in 0..<4 {
                let cx = Float(col) * 5.5 - 8.25
                let cz = Float(row) * 5.0 - 4.5
                // Recessed panel
                addBox(anchor, SIMD3(4.2, 0.08, 4.2), SIMD3(cx, roomH-0.22, cz), cofferMat)
                // Gold rim around each coffer
                addBox(anchor, SIMD3(4.6, 0.06, 0.18), SIMD3(cx, roomH-0.14, cz-2.2), cofferRimMat)
                addBox(anchor, SIMD3(4.6, 0.06, 0.18), SIMD3(cx, roomH-0.14, cz+2.2), cofferRimMat)
                addBox(anchor, SIMD3(0.18, 0.06, 4.2), SIMD3(cx-2.3, roomH-0.14, cz), cofferRimMat)
                addBox(anchor, SIMD3(0.18, 0.06, 4.2), SIMD3(cx+2.3, roomH-0.14, cz), cofferRimMat)
            }
        }

        // Rear wall decorative vertical panel strips
        var panelMat = PhysicallyBasedMaterial()
        panelMat.baseColor = .init(tint: UIColor(red: 0.12, green: 0.09, blue: 0.06, alpha: 1))
        panelMat.roughness = .init(floatLiteral: 0.80)
        for xPos: Float in [-8.0, -2.5, 2.5, 8.0] {
            addBox(anchor, SIMD3(0.06, 4.5, 0.06),
                   SIMD3(xPos, 2.5, -roomD/2+0.18), moldMat)
        }
    }

    // MARK: Sculptures — replace pillars with elegant pedestals + abstract forms

    private func buildSculptures(anchor: AnchorEntity) {

        // Shared materials
        var pedestalMat = PhysicallyBasedMaterial()
        pedestalMat.baseColor = .init(tint: UIColor(red: 0.16, green: 0.12, blue: 0.09, alpha: 1))
        pedestalMat.roughness = .init(floatLiteral: 0.55)
        pedestalMat.metallic  = .init(floatLiteral: 0.04)

        var marbMat = PhysicallyBasedMaterial()
        marbMat.baseColor = .init(tint: UIColor(red: 0.82, green: 0.80, blue: 0.76, alpha: 1))
        marbMat.roughness = .init(floatLiteral: 0.22)
        marbMat.metallic  = .init(floatLiteral: 0.02)

        var bronzeMat = PhysicallyBasedMaterial()
        bronzeMat.baseColor = .init(tint: UIColor(red: 0.48, green: 0.34, blue: 0.16, alpha: 1))
        bronzeMat.roughness = .init(floatLiteral: 0.38)
        bronzeMat.metallic  = .init(floatLiteral: 0.72)

        var darkMarbMat = PhysicallyBasedMaterial()
        darkMarbMat.baseColor = .init(tint: UIColor(red: 0.18, green: 0.14, blue: 0.12, alpha: 1))
        darkMarbMat.roughness = .init(floatLiteral: 0.18)
        darkMarbMat.metallic  = .init(floatLiteral: 0.06)

        // ── Left sculpture: abstract organic marble form ──
        let lx: Float = -9.0
        buildPedestalWithSculpture(anchor: anchor, x: lx, z: 1.5,
                                    pedestalMat: pedestalMat, sculptMat: marbMat,
                                    sculptType: .organic)
        // Spotlight on it
        addSculptureSpotlight(anchor: anchor, x: lx, z: 1.5)

        // ── Right sculpture: tall bronze abstract tower ──
        let rx: Float = 9.0
        buildPedestalWithSculpture(anchor: anchor, x: rx, z: 1.5,
                                    pedestalMat: pedestalMat, sculptMat: bronzeMat,
                                    sculptType: .tower)
        addSculptureSpotlight(anchor: anchor, x: rx, z: 1.5)

        // ── Centre-room low display stand (dark marble) ──
        buildPedestalWithSculpture(anchor: anchor, x: 0, z: 3.5,
                                    pedestalMat: darkMarbMat, sculptMat: marbMat,
                                    sculptType: .sphere)
        addSculptureSpotlight(anchor: anchor, x: 0, z: 3.5)
    }

    enum SculptType { case organic, tower, sphere }

    private func buildPedestalWithSculpture(anchor: AnchorEntity,
                                             x: Float, z: Float,
                                             pedestalMat: PhysicallyBasedMaterial,
                                             sculptMat: PhysicallyBasedMaterial,
                                             sculptType: SculptType) {
        // Pedestal base
        let pedBase = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.72, 0.08, 0.72), cornerRadius: 0.02),
            materials: [pedestalMat])
        pedBase.position = [x, 0.04, z]
        anchor.addChild(pedBase)

        // Pedestal shaft
        let pedShaft = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.48, 1.10, 0.48), cornerRadius: 0.02),
            materials: [pedestalMat])
        pedShaft.position = [x, 0.59, z]
        anchor.addChild(pedShaft)

        // Pedestal top cap
        let pedCap = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.60, 0.06, 0.60), cornerRadius: 0.02),
            materials: [pedestalMat])
        pedCap.position = [x, 1.17, z]
        anchor.addChild(pedCap)

        // Sculpture form
        switch sculptType {
        case .organic:
            // Multi-sphere organic cluster
            let radii: [(Float, Float, Float, Float)] = [
                (0.0,  0.28, 0.0,  0.28),
                (0.14, 0.48, 0.06, 0.18),
                (-0.12, 0.46, 0.08, 0.16),
                (0.0,  0.64, 0.04, 0.12),
            ]
            for (ox, oy, oz, r) in radii {
                let s = ModelEntity(mesh: .generateSphere(radius: r), materials: [sculptMat])
                s.position = [x + ox, 1.20 + oy, z + oz]
                anchor.addChild(s)
            }

        case .tower:
            // Stacked abstract boxes tapering up
            let parts: [(Float, Float, Float, Float)] = [
                (0.30, 0.12, 0.30, 0.06),
                (0.22, 0.40, 0.22, 0.26),
                (0.16, 0.22, 0.16, 0.53),
                (0.08, 0.28, 0.08, 0.75),
                (0.12, 0.10, 0.12, 0.92),
            ]
            for (pw, ph, pd, py) in parts {
                let b = ModelEntity(
                    mesh: .generateBox(size: SIMD3<Float>(pw, ph, pd), cornerRadius: 0.015),
                    materials: [sculptMat])
                b.position = [x, 1.20 + py, z]
                anchor.addChild(b)
            }

        case .sphere:
            // Single elegant sphere with flat disc base detail
            let sphere = ModelEntity(mesh: .generateSphere(radius: 0.24), materials: [sculptMat])
            sphere.position = [x, 1.44, z]
            anchor.addChild(sphere)

            var discMat = PhysicallyBasedMaterial()
            discMat.baseColor = .init(tint: UIColor(red: 0.35, green: 0.24, blue: 0.10, alpha: 1))
            discMat.roughness = .init(floatLiteral: 0.30)
            discMat.metallic  = .init(floatLiteral: 0.68)
            let disc = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(0.52, 0.04, 0.52), cornerRadius: 0.26),
                materials: [discMat])
            disc.position = [x, 1.22, z]
            anchor.addChild(disc)
        }
    }

    private func addSculptureSpotlight(anchor: AnchorEntity, x: Float, z: Float) {
        let e  = Entity()
        var sp = SpotLightComponent()
        sp.color               = .init(red: 1.0, green: 0.90, blue: 0.70, alpha: 1)
        sp.intensity           = 8000
        sp.innerAngleInDegrees = 12
        sp.outerAngleInDegrees = 30
        sp.attenuationRadius   = 5.0
        e.components.set(sp)
        e.position = SIMD3<Float>(x, 5.5, z + 0.5)
        e.orientation = simd_quatf(angle: -.pi / 2.1, axis: SIMD3<Float>(1, 0, 0))
        anchor.addChild(e)
    }

    // MARK: Lighting — near-black room, paintings are the only real light

    private func buildLighting(anchor: AnchorEntity) {
        // Barely-there ambient — just enough to hint at room geometry
        let ambientEntity = Entity()
        var ambient        = PointLightComponent()
        ambient.color            = .init(red: 0.50, green: 0.38, blue: 0.24, alpha: 1)
        ambient.intensity        = 12          // very dim
        ambient.attenuationRadius = 30
        ambientEntity.components.set(ambient)
        ambientEntity.position = [0, 7.5, 0]
        anchor.addChild(ambientEntity)

        // Tiny front fill — stops the viewer from being in pure black
        let fillEntity = Entity()
        var fill        = PointLightComponent()
        fill.color            = .init(red: 0.35, green: 0.28, blue: 0.22, alpha: 1)
        fill.intensity        = 8
        fill.attenuationRadius = 15
        fillEntity.components.set(fill)
        fillEntity.position = [0, 3.5, 5.0]
        anchor.addChild(fillEntity)
    }

    // MARK: Per-painting spotlight — tight warm cone from just above frame

    // MARK: Per-painting spotlight — dramatic tight cone, paintings glow in the dark

    private func addSpotlight(anchor: AnchorEntity, paintingX: Float,
                               paintingY: Float, wallZ: Float) {
        // Primary beam — very bright, tight, warm white
        let e  = Entity()
        var sp = SpotLightComponent()
        sp.color               = .init(red: 1.0, green: 0.93, blue: 0.68, alpha: 1)
        sp.intensity           = 40000       // dramatic — floods the canvas
        sp.innerAngleInDegrees = 7           // hot center beam
        sp.outerAngleInDegrees = 22          // crisp falloff
        sp.attenuationRadius   = 7.0
        e.components.set(sp)
        e.position = SIMD3<Float>(paintingX, paintingY + 1.9, wallZ + 0.55)
        e.orientation = simd_quatf(angle: -.pi / 2.05, axis: SIMD3<Float>(1, 0, 0))
        anchor.addChild(e)

        // Soft fill — slight offset, widens the glow halo on the wall
        let e2  = Entity()
        var sp2 = SpotLightComponent()
        sp2.color               = .init(red: 0.88, green: 0.76, blue: 0.50, alpha: 1)
        sp2.intensity           = 10000
        sp2.innerAngleInDegrees = 16
        sp2.outerAngleInDegrees = 38
        sp2.attenuationRadius   = 6.0
        e2.components.set(sp2)
        e2.position = SIMD3<Float>(paintingX + 0.5, paintingY + 1.6, wallZ + 0.75)
        e2.orientation = simd_quatf(angle: -.pi / 2.15, axis: SIMD3<Float>(1, 0, 0))
        anchor.addChild(e2)
    }

    // MARK: Artworks

    private func hangAllArtworks(anchor: AnchorEntity, context: Context) {
        let count = allArtworks.count
        guard count > 0 else { return }

        let roomW: Float     = 24.0
        let wallZ: Float     = -6.78
        let paintingY: Float =  3.50

        let maxSpread: Float = roomW - 5.0
        let spacing: Float   = count > 1 ? min(5.8, maxSpread / Float(count - 1)) : 0
        let totalW: Float    = spacing * Float(count - 1)
        let startX: Float    = -totalW / 2

        context.coordinator.spacing    = spacing
        context.coordinator.startX     = startX
        context.coordinator.paintingY  = paintingY
        context.coordinator.wallZ      = wallZ

        for (i, artwork) in allArtworks.enumerated() {
            let x = startX + Float(i) * spacing
            let painting = buildFramedPainting(artwork: artwork)
            painting.position = [x, paintingY, wallZ]
            anchor.addChild(painting)
            context.coordinator.paintingEntities
                .append((entity: painting, artwork: artwork))

            addSpotlight(anchor: anchor,
                          paintingX: x,
                          paintingY: paintingY,
                          wallZ: wallZ)

            buildNameplate(anchor: anchor,
                            at: SIMD3<Float>(x, paintingY - 1.45, wallZ + 0.06))
        }
    }

    private func buildFramedPainting(artwork: SavedArtwork) -> Entity {
        let container = Entity()
        container.name = artwork.id.uuidString

        let cW: Float = 2.60; let cH: Float = 1.90
        let cD: Float = 0.03; let fT: Float = 0.18

        // Canvas with artwork texture — warmer cream ground
        let artImage = renderDrawing(artwork, size: CGSize(width: 900, height: 660))
        var canvasMat = PhysicallyBasedMaterial()
        if let cgImage = artImage.cgImage,
           let tex = try? TextureResource.generate(
               from: cgImage, options: .init(semantic: .color)) {
            canvasMat.baseColor = .init(texture: .init(tex))
        } else {
            canvasMat.baseColor = .init(tint: UIColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1))
        }
        canvasMat.roughness = .init(floatLiteral: 0.82)
        canvasMat.metallic  = .init(floatLiteral: 0.00)

        let canvas = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(cW, cH, cD), cornerRadius: 0.004),
            materials: [canvasMat])
        canvas.name     = artwork.id.uuidString
        canvas.position = [0, 0, cD / 2]
        container.addChild(canvas)

        // Outer gold frame bars — richly metallic
        var goldMat = PhysicallyBasedMaterial()
        goldMat.baseColor = .init(tint: UIColor(red: 0.76, green: 0.56, blue: 0.14, alpha: 1))
        goldMat.roughness = .init(floatLiteral: 0.08)
        goldMat.metallic  = .init(floatLiteral: 0.99)

        // Inner darker gold liner
        var linerMat = PhysicallyBasedMaterial()
        linerMat.baseColor = .init(tint: UIColor(red: 0.45, green: 0.30, blue: 0.08, alpha: 1))
        linerMat.roughness = .init(floatLiteral: 0.28)
        linerMat.metallic  = .init(floatLiteral: 0.85)

        // Outer frame
        for (size, pos) in [
            (SIMD3<Float>(cW+fT*2, fT, 0.10), SIMD3<Float>(0,  cH/2+fT/2, 0)),
            (SIMD3<Float>(cW+fT*2, fT, 0.10), SIMD3<Float>(0, -cH/2-fT/2, 0)),
            (SIMD3<Float>(fT, cH, 0.10),       SIMD3<Float>(-cW/2-fT/2, 0, 0)),
            (SIMD3<Float>(fT, cH, 0.10),       SIMD3<Float>( cW/2+fT/2, 0, 0)),
        ] as [(SIMD3<Float>, SIMD3<Float>)] {
            let bar = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.010),
                                   materials: [goldMat])
            bar.position = pos
            container.addChild(bar)
        }

        // Inner liner (thin gold band right against the canvas)
        let lT: Float = 0.06
        for (size, pos) in [
            (SIMD3<Float>(cW+lT*2, lT, 0.06), SIMD3<Float>(0,  cH/2+lT/2, 0.01)),
            (SIMD3<Float>(cW+lT*2, lT, 0.06), SIMD3<Float>(0, -cH/2-lT/2, 0.01)),
            (SIMD3<Float>(lT, cH, 0.06),       SIMD3<Float>(-cW/2-lT/2, 0, 0.01)),
            (SIMD3<Float>(lT, cH, 0.06),       SIMD3<Float>( cW/2+lT/2, 0, 0.01)),
        ] as [(SIMD3<Float>, SIMD3<Float>)] {
            let liner = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.006),
                                     materials: [linerMat])
            liner.position = pos
            container.addChild(liner)
        }

        // Dark backing mount with subtle reveal
        var mountMat = PhysicallyBasedMaterial()
        mountMat.baseColor = .init(tint: UIColor(red: 0.06, green: 0.04, blue: 0.02, alpha: 1))
        mountMat.roughness = .init(floatLiteral: 0.90)
        let mount = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(cW+fT*2+0.12, cH+fT*2+0.12, 0.025)),
            materials: [mountMat])
        mount.position = [0, 0, -0.025]
        container.addChild(mount)

        // Hanging wire — thin, bronze
        var wireMat = PhysicallyBasedMaterial()
        wireMat.baseColor = .init(tint: UIColor(red: 0.55, green: 0.44, blue: 0.24, alpha: 1))
        wireMat.roughness = .init(floatLiteral: 0.28)
        wireMat.metallic  = .init(floatLiteral: 0.92)
        let wire = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(0.008, 0.45, 0.008)),
            materials: [wireMat])
        wire.position = [0, cH/2+fT+0.22, 0]
        container.addChild(wire)

        return container
    }

    private func buildNameplate(anchor: AnchorEntity, at pos: SIMD3<Float>) {
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(red: 0.72, green: 0.60, blue: 0.38, alpha: 1))
        mat.roughness = .init(floatLiteral: 0.58)
        mat.metallic  = .init(floatLiteral: 0.25)
        let plaque = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(1.80, 0.38, 0.05), cornerRadius: 0.020),
            materials: [mat])
        plaque.position = pos
        anchor.addChild(plaque)
    }

    // MARK: Camera

    private func setupCamera(arView: ARView, context: Context) {
        let count    = allArtworks.count
        let focusIdx = allArtworks.firstIndex(where: { $0.id == focusedArtwork.id }) ?? 0
        let spacing: Float = count > 1 ? min(5.8, 19.0 / Float(count - 1)) : 0
        let totalW:  Float = spacing * Float(count - 1)
        let startX:  Float = -totalW / 2
        let focusX:  Float = startX + Float(focusIdx) * spacing

        let cam = PerspectiveCamera()
        cam.camera.fieldOfViewInDegrees = 65
        cam.position    = [focusX, 3.5, 4.2]
        cam.orientation = simd_quatf(angle: -0.09, axis: SIMD3<Float>(1, 0, 0))

        let camAnchor = AnchorEntity(world: .zero)
        camAnchor.addChild(cam)
        arView.scene.addAnchor(camAnchor)

        context.coordinator.cameraEntity   = cam
        context.coordinator.tourStartIndex =
            allArtworks.firstIndex(where: { $0.id == focusedArtwork.id }) ?? 0
    }

    // MARK: Helpers

    @discardableResult
    private func addBox(_ anchor: AnchorEntity, _ size: SIMD3<Float>,
                         _ pos: SIMD3<Float>, _ mat: PhysicallyBasedMaterial) -> ModelEntity {
        let e = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.006), materials: [mat])
        e.position = pos
        anchor.addChild(e)
        return e
    }

    private func renderDrawing(_ artwork: SavedArtwork, size: CGSize) -> UIImage {
        let drawing = artwork.drawing
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            UIColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            guard !drawing.strokes.isEmpty else { return }
            let bounds = drawing.bounds.isEmpty
                ? CGRect(origin: .zero, size: size)
                : drawing.bounds.insetBy(dx: -20, dy: -20)
            let scale = min(size.width/bounds.width, size.height/bounds.height) * 0.84
            let sw = bounds.width * scale; let sh = bounds.height * scale
            drawing.image(from: bounds, scale: scale)
                .draw(in: CGRect(x: (size.width-sw)/2, y: (size.height-sh)/2,
                                  width: sw, height: sh))
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UIGestureRecognizerDelegate {

        var allArtworks:        [SavedArtwork]
        var focusedArtwork:     SavedArtwork
        let onFocusChanged:     (SavedArtwork) -> Void
        let onUserInteraction:  () -> Void
        let onTourStateChanged: (Bool) -> Void

        var paintingEntities: [(entity: Entity, artwork: SavedArtwork)] = []
        weak var arView:      ARView?
        var cameraEntity:     PerspectiveCamera?

        // Layout info set during build
        var spacing:    Float = 0
        var startX:     Float = 0
        var paintingY:  Float = 3.5
        var wallZ:      Float = -6.78

        // Tour state
        var isTouring:      Bool  = false
        var tourIndex:      Int   = 0
        var tourStartIndex: Int   = 0
        var tourTimer:      Timer? = nil
        var tourObservers:  [Any] = []

        // Manual gesture state
        var panStartPos:   SIMD3<Float> = .zero
        var pinchStartFOV: Float = 65

        // Camera bounds
        let minX: Float = -11.0; let maxX: Float = 11.0
        let minZ: Float =  1.0;  let maxZ: Float =  6.5

        init(allArtworks: [SavedArtwork], focusedArtwork: SavedArtwork,
             onFocusChanged:     @escaping (SavedArtwork) -> Void,
             onUserInteraction:  @escaping () -> Void,
             onTourStateChanged: @escaping (Bool) -> Void) {
            self.allArtworks        = allArtworks
            self.focusedArtwork     = focusedArtwork
            self.onFocusChanged     = onFocusChanged
            self.onUserInteraction  = onUserInteraction
            self.onTourStateChanged = onTourStateChanged
        }

        deinit { tearDownTourObservers() }

        // MARK: Tour Observers

        func registerTourObservers() {
            let stopObs = NotificationCenter.default.addObserver(
                forName: .museumStopTour, object: nil, queue: .main) { [weak self] _ in
                self?.stopAutoTour()
            }
            let startObs = NotificationCenter.default.addObserver(
                forName: .museumStartTour, object: nil, queue: .main) { [weak self] _ in
                self?.tourIndex = 0
                self?.startAutoTour()
            }
            tourObservers = [stopObs, startObs]
        }

        func tearDownTourObservers() {
            tourObservers.forEach { NotificationCenter.default.removeObserver($0) }
            tourObservers = []
        }

        // MARK: Auto Tour

        /// Starts the auto-tour from tourStartIndex, visiting each painting in sequence.
        func startAutoTour() {
            guard !paintingEntities.isEmpty else { return }
            isTouring = true
            onTourStateChanged(true)
            tourIndex = tourStartIndex
            visitNextPainting()
        }

        func stopAutoTour() {
            isTouring = false
            tourTimer?.invalidate()
            tourTimer = nil
            onTourStateChanged(false)
        }

        /// Moves camera to current tourIndex painting, waits, then advances.
        private func visitNextPainting() {
            guard isTouring,
                  tourIndex < paintingEntities.count,
                  let cam = cameraEntity else { return }

            let entry    = paintingEntities[tourIndex]
            let targetX  = entry.entity.position.x
            let viewZ:   Float = 3.6          // viewing distance from wall
            let viewY:   Float = paintingY

            // Smooth camera glide to painting
            var t = cam.transform
            t.translation = SIMD3<Float>(targetX, viewY, viewZ)
            t.rotation    = simd_quatf(angle: -0.09, axis: SIMD3<Float>(1, 0, 0))

            // Duration scales with distance — feels more natural
            let dist = abs(targetX - cam.position.x)
            let duration: TimeInterval = Double(max(1.4, min(3.5, dist * 0.38)))

            cam.move(to: t, relativeTo: nil,
                      duration: duration, timingFunction: .easeInOut)

            // Update plaque
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.6) { [weak self] in
                guard let self, self.isTouring else { return }
                self.focusedArtwork = entry.artwork
                self.onFocusChanged(entry.artwork)
            }

            // Dwell at painting, then move on
            let dwellTime: TimeInterval = 2.8
            tourTimer = Timer.scheduledTimer(
                withTimeInterval: duration + dwellTime, repeats: false
            ) { [weak self] _ in
                guard let self, self.isTouring else { return }
                self.tourIndex += 1
                if self.tourIndex >= self.paintingEntities.count {
                    // Loop back
                    self.tourIndex = 0
                }
                self.visitNextPainting()
            }
        }

        // MARK: Gestures — all stop tour first

        func gestureRecognizer(_ g: UIGestureRecognizer,
                                shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer) -> Bool { true }

        @MainActor @objc func handlePan(_ r: UIPanGestureRecognizer) {
            if isTouring {
                stopAutoTour()
                onUserInteraction()
                return
            }
            guard let cam = cameraEntity else { return }
            onUserInteraction()
            switch r.state {
            case .began:
                panStartPos = cam.position
            case .changed:
                guard let v = r.view else { return }
                let t  = r.translation(in: v)
                let dx = Float(t.x) * 0.010
                let dz = Float(t.y) * 0.013
                cam.position = SIMD3<Float>(
                    clamp(panStartPos.x - dx, minX, maxX),
                    cam.position.y,
                    clamp(panStartPos.z + dz, minZ, maxZ))
                updatePlaque()
            default: break
            }
        }

        @MainActor @objc func handlePinch(_ r: UIPinchGestureRecognizer) {
            if isTouring { stopAutoTour(); onUserInteraction(); return }
            guard let cam = cameraEntity else { return }
            onUserInteraction()
            if r.state == .began { pinchStartFOV = cam.camera.fieldOfViewInDegrees }
            if r.state == .changed || r.state == .ended {
                cam.camera.fieldOfViewInDegrees =
                    clamp(pinchStartFOV / Float(r.scale), 28, 90)
            }
        }

        @MainActor @objc func handleTap(_ r: UITapGestureRecognizer) {
            if isTouring { stopAutoTour(); onUserInteraction(); return }
            guard let av = arView, let cam = cameraEntity else { return }
            onUserInteraction()
            let hits = av.hitTest(r.location(in: av))
            for hit in hits {
                var e: Entity? = hit.entity
                while e != nil {
                    if let name = e?.name,
                       let match = paintingEntities.first(where: {
                           $0.entity.name == name || $0.artwork.id.uuidString == name
                       }) {
                        let newX = clamp(
                            cam.position.x + (match.entity.position.x - cam.position.x) * 0.80,
                            minX, maxX)
                        var t = cam.transform
                        t.translation = SIMD3<Float>(newX, cam.position.y, 3.6)
                        cam.move(to: t, relativeTo: nil, duration: 0.55,
                                  timingFunction: .easeInOut)
                        focusedArtwork = match.artwork
                        onFocusChanged(match.artwork)
                        return
                    }
                    e = e?.parent
                }
            }
        }

        private func updatePlaque() {
            guard let cam = cameraEntity else { return }
            if let nearest = paintingEntities.min(by: {
                abs($0.entity.position.x - cam.position.x) <
                abs($1.entity.position.x - cam.position.x)
            }), nearest.artwork.id != focusedArtwork.id {
                focusedArtwork = nearest.artwork
                onFocusChanged(nearest.artwork)
            }
        }

        private func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
            Swift.max(lo, Swift.min(hi, v))
        }
    }
}

// MARK: - Comparable clamp helper

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}


