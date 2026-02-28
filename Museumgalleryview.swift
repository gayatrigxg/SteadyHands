import SwiftUI
import SceneKit
import PencilKit

// MARK: - Museum Gallery View

struct MuseumGalleryView: View {

    @EnvironmentObject var gallery: GalleryStore
    @State private var selectedArtwork: SavedArtwork? = nil
    @State private var sceneKey: UUID = UUID()

    // Hint 1 — scroll (bottom bar)
    @State private var scrollHintVisible: Bool = false
    @State private var scrollHintOpacity: Double = 0
    @State private var scrollHintOffset: CGFloat = 20

    // Hint 2 — tap to 3D (centre card)
    @State private var tapHintVisible: Bool = false
    @State private var tapHintOpacity: Double = 0
    @State private var tapHintScale: CGFloat = 0.88

    var body: some View {
        ZStack {
            if gallery.artworks.isEmpty {
                emptyGalleryView
            } else {
                MuseumRoomScene(
                    artworks: gallery.artworks,
                    onTapArtwork: { artwork in
                        dismissAllHints()
                        selectedArtwork = artwork
                    },
                    onPanBegan: {
                        dismissScrollHint()
                    }
                )
                .id(sceneKey)
                .ignoresSafeArea()
            }

            // Hint 1: Scroll left/right
            if scrollHintVisible && !gallery.artworks.isEmpty {
                VStack {
                    Spacer()
                    scrollHint
                        .opacity(scrollHintOpacity)
                        .offset(y: scrollHintOffset)
                        .padding(.bottom, 44)
                }
            }

            // Hint 2: Tap painting to see in 3D
            if tapHintVisible && !gallery.artworks.isEmpty {
                tapHintCard
                    .opacity(tapHintOpacity)
                    .scaleEffect(tapHintScale)
            }
        }
        .onAppear {
            guard !gallery.artworks.isEmpty else { return }
            showScrollHint()
            showTapHint()
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onChange(of: gallery.artworks.count) { _ in
            sceneKey = UUID()
        }
        .sheet(item: $selectedArtwork) { artwork in
            ArtworkDetailSheet(artwork: artwork, allArtworks: gallery.artworks, onDelete: {
                gallery.delete(artwork)
                selectedArtwork = nil
                sceneKey = UUID()
            })
            .environmentObject(gallery)
        }
    }

    // MARK: - Hint Lifecycle

    private func showScrollHint() {
        scrollHintVisible = true
        withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(1.0)) {
            scrollHintOpacity = 1; scrollHintOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) { dismissScrollHint() }
    }

    private func dismissScrollHint() {
        guard scrollHintOpacity > 0 else { return }
        withAnimation(.easeOut(duration: 0.45)) {
            scrollHintOpacity = 0; scrollHintOffset = 14
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { scrollHintVisible = false }
    }

    private func showTapHint() {
        tapHintVisible = true
        withAnimation(.spring(response: 0.60, dampingFraction: 0.70).delay(2.2)) {
            tapHintOpacity = 1; tapHintScale = 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) { dismissTapHint() }
    }

    private func dismissTapHint() {
        guard tapHintOpacity > 0 else { return }
        withAnimation(.easeOut(duration: 0.40)) {
            tapHintOpacity = 0; tapHintScale = 0.90
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { tapHintVisible = false }
    }

    private func dismissAllHints() { dismissScrollHint(); dismissTapHint() }

    // MARK: - Scroll Hint (bottom bar)

    private var scrollHint: some View {
        HStack(spacing: 14) {
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.7))
            HStack(spacing: 8) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 14, weight: .medium))
                Text("Swipe to explore the gallery")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(Color(red: 0.96, green: 0.90, blue: 0.76))
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.7))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(Color(red: 0.12, green: 0.10, blue: 0.07).opacity(0.55))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.30), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6)
    }

    // MARK: - Tap-to-3D Hint (centre card)

    private var tapHintCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.92, green: 0.76, blue: 0.30))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Tap any painting")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.96, green: 0.93, blue: 0.86))
                    Text("View it in 3D inside the museum")
                        .font(.system(size: 13))
                        .foregroundColor(Color(red: 0.75, green: 0.62, blue: 0.42))
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.55))
                .padding(.bottom, 14)
        }
        .background(.ultraThinMaterial)
        .background(Color(red: 0.10, green: 0.08, blue: 0.05).opacity(0.70))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 40)
        .frame(maxWidth: 380)
        .frame(maxHeight: .infinity, alignment: .center)
        .offset(y: 80)
    }

    private var emptyGalleryView: some View {
        ZStack {
            Color(red: 0.145, green: 0.130, blue: 0.115).ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.1))
                        .frame(width: 90, height: 90)
                    Image(systemName: "building.columns")
                        .font(.system(size: 38))
                        .foregroundColor(Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.5))
                }
                Text("Your gallery awaits")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(red: 0.96, green: 0.93, blue: 0.86))
                Text("Draw something and hang it\nto see your museum come to life.")
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.40))
                    .multilineTextAlignment(.center).lineSpacing(4)
            }
        }
    }
}

// MARK: - Artwork Detail Sheet
// Self-contained — no dependency on old ArtworkDetailView

struct ArtworkDetailSheet: View {
    let artwork: SavedArtwork
    let allArtworks: [SavedArtwork]
    let onDelete: () -> Void

    @Environment(\.dismiss) var dismiss
    @State private var paintingImage: UIImage? = nil
    @State private var appeared = false
    @State private var showDeleteConfirm = false
    @State private var show3D = false

    var body: some View {
        ZStack {
            Color(red: 0.145, green: 0.130, blue: 0.115).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.75, green: 0.62, blue: 0.42))
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button { show3D = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cube").font(.system(size: 14, weight: .medium))
                            Text("View in 3D").font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.12, green: 0.10, blue: 0.07))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(LinearGradient(
                            colors: [Color(red: 0.92, green: 0.76, blue: 0.30),
                                     Color(red: 0.78, green: 0.58, blue: 0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .cornerRadius(10)
                    }
                    Button { showDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.red.opacity(0.7))
                            .padding(12)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 20).padding(.top, 56).padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Spotlight + frame
                        ZStack(alignment: .top) {
                            RadialGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.78, blue: 0.42).opacity(0.22),
                                    Color.clear
                                ],
                                center: .center, startRadius: 10, endRadius: 200
                            )
                            .frame(height: 280).offset(y: -30)
                            .opacity(appeared ? 1 : 0)

                            framedPainting
                                .scaleEffect(appeared ? 1.0 : 0.94)
                                .opacity(appeared ? 1 : 0)
                        }
                        .padding(.horizontal, 32)

                        // Plaque
                        detailPlaque
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)

                        // Metrics
                        HStack(spacing: 12) {
                            DetailMetricCard(label: "Stability", value: "\(artwork.stabilityScore)%",
                                             icon: "waveform.path.ecg")
                            DetailMetricCard(label: "Pressure",  value: "\(artwork.pressureScore)%",
                                             icon: "hand.draw")
                            DetailMetricCard(label: "Strokes",   value: "\(artwork.strokeCount)",
                                             icon: "pencil.tip")
                        }
                        .opacity(appeared ? 1 : 0)
                        .padding(.horizontal, 24)

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .onAppear {
            loadImage()
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $show3D) {
            if #available(iOS 17.0, *) {
                MuseumSceneKitView(allArtworks: allArtworks, focusedArtwork: artwork)
            } else {
                // Fallback for iOS < 17 (should not occur on target devices)
                Text("3D view requires iOS 17 or later.")
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            }
        }
        .confirmationDialog("Remove this piece?", isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Remove from Gallery", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var framedPainting: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(
                    colors: [Color(red: 0.88, green: 0.70, blue: 0.24),
                             Color(red: 0.68, green: 0.48, blue: 0.12),
                             Color(red: 0.92, green: 0.76, blue: 0.30),
                             Color(red: 0.62, green: 0.43, blue: 0.10),
                             Color(red: 0.88, green: 0.70, blue: 0.24)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: .black.opacity(0.55), radius: 28, x: 0, y: 14)

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.10, green: 0.08, blue: 0.04)).padding(14)

            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.94)
                if let img = paintingImage {
                    Image(uiImage: img).resizable().scaledToFit().padding(12)
                }
                RadialGradient(colors: [Color.clear, Color.black.opacity(0.07)],
                               center: .center, startRadius: 80, endRadius: 180)
            }
            .padding(16).clipShape(RoundedRectangle(cornerRadius: 2))
        }
        .aspectRatio(1.35, contentMode: .fit)
    }

    private var detailPlaque: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(artwork.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 0.18, green: 0.14, blue: 0.08))
                Text(artwork.formattedDate)
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.50, green: 0.40, blue: 0.25))
                Text("Steady Hands Museum · Personal Collection")
                    .font(.system(size: 12, weight: .light)).italic()
                    .foregroundColor(Color(red: 0.60, green: 0.48, blue: 0.30))
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            .background(Color(red: 0.94, green: 0.91, blue: 0.84))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4)
                .stroke(Color(red: 0.78, green: 0.65, blue: 0.40).opacity(0.5), lineWidth: 1))
            .frame(maxWidth: 300)
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)

            Rectangle().fill(Color(red: 0.55, green: 0.42, blue: 0.24)).frame(width: 2, height: 20)
            Capsule().fill(Color(red: 0.45, green: 0.33, blue: 0.18)).frame(width: 70, height: 8)
        }
    }

    private func loadImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let img = artwork.thumbnail(size: CGSize(width: 600, height: 440))
            DispatchQueue.main.async { paintingImage = img }
        }
    }
}

// MARK: - Detail Metric Card

private struct DetailMetricCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.85, green: 0.68, blue: 0.22))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.96, green: 0.93, blue: 0.86))
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.40))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(Color.white.opacity(0.06)).cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(Color(red: 0.75, green: 0.58, blue: 0.20).opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Museum Room Scene

struct MuseumRoomScene: UIViewRepresentable {

    let artworks: [SavedArtwork]
    let onTapArtwork: (SavedArtwork) -> Void
    var onPanBegan: (() -> Void)? = nil

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.scene = buildScene(context: context)
        sceneView.backgroundColor = UIColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1)
        sceneView.antialiasingMode = .multisampling4X
        sceneView.allowsCameraControl = false
        sceneView.autoenablesDefaultLighting = false
        sceneView.showsStatistics = false
        context.coordinator.sceneView = sceneView

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:)))
        sceneView.addGestureRecognizer(tap)

        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:)))
        sceneView.addGestureRecognizer(pan)

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(artworks: artworks, onTapArtwork: onTapArtwork, onPanBegan: onPanBegan)
    }

    // MARK: Build Scene

    private func buildScene(context: Context) -> SCNScene {
        let scene = SCNScene()
        context.coordinator.paintingNodes = []

        buildRoom(in: scene)

        let spacing: Float = 3.8
        let wallZ: Float = -4.8
        let paintingY: Float = 1.2

        for (i, artwork) in artworks.enumerated() {
            let x = Float(i) * spacing - Float(artworks.count - 1) * spacing / 2
            let node = buildFramedPainting(artwork: artwork)
            node.position = SCNVector3(x, paintingY, wallZ)
            scene.rootNode.addChildNode(node)
            context.coordinator.paintingNodes.append((node: node, artwork: artwork))
            buildSpotlight(at: SCNVector3(x, 5.0, wallZ + 1.2),
                           pointing: SCNVector3(x, paintingY, wallZ),
                           in: scene)
        }

        // Ambient
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(red: 0.12, green: 0.09, blue: 0.06, alpha: 1)
        ambient.intensity = 180
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // Camera
        let camera = SCNCamera()
        camera.fieldOfView = 65
        camera.zNear = 0.1
        camera.zFar = 60
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.2, 1.8)
        cameraNode.eulerAngles = SCNVector3(-0.05, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
        context.coordinator.cameraNode = cameraNode

        return scene
    }

    // MARK: Room

    private func buildRoom(in scene: SCNScene) {
        let wall = UIColor(red: 0.185, green: 0.160, blue: 0.130, alpha: 1)
        addBox(scene, SCNVector3(60,8,0.3),  SCNVector3(0,3,-5),   wall)
        addBox(scene, SCNVector3(60,0.3,14), SCNVector3(0,7,-5),
               UIColor(red:0.14,green:0.11,blue:0.08,alpha:1))
        addBox(scene, SCNVector3(0.3,8,14),  SCNVector3(-30,3,-5), wall)
        addBox(scene, SCNVector3(0.3,8,14),  SCNVector3(30,3,-5),  wall)
        addBox(scene, SCNVector3(60,0.18,0.15), SCNVector3(0,-1.42,-4.85),
               UIColor(red:0.42,green:0.30,blue:0.16,alpha:1))

        let floor = SCNFloor()
        let fm = SCNMaterial()
        fm.diffuse.contents = UIColor(red:0.32,green:0.20,blue:0.11,alpha:1)
        fm.roughness.contents = NSNumber(value: 0.75)
        floor.reflectivity = 0.06
        floor.materials = [fm]
        let fn = SCNNode(geometry: floor)
        fn.position = SCNVector3(0,-1.5,0)
        scene.rootNode.addChildNode(fn)

        buildBench(SCNVector3(0,-1.1,-1.0), scene)
    }

    private func buildBench(_ pos: SCNVector3, _ scene: SCNScene) {
        let c = SCNNode(); c.position = pos
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(red:0.38,green:0.22,blue:0.10,alpha:1)
        let seat = SCNBox(width:1.8,height:0.12,length:0.55,chamferRadius:0.04)
        seat.materials = [mat]; c.addChildNode(SCNNode(geometry:seat))
        for p in [SCNVector3(-0.7,-0.25,0.18),SCNVector3(0.7,-0.25,0.18),
                  SCNVector3(-0.7,-0.25,-0.18),SCNVector3(0.7,-0.25,-0.18)] {
            let leg = SCNBox(width:0.07,height:0.5,length:0.07,chamferRadius:0.02)
            leg.materials=[mat]; let n=SCNNode(geometry:leg); n.position=p; c.addChildNode(n)
        }
        scene.rootNode.addChildNode(c)
    }

    private func addBox(_ scene: SCNScene, _ size: SCNVector3,
                        _ pos: SCNVector3, _ color: UIColor) {
        let b = SCNBox(width:CGFloat(size.x),height:CGFloat(size.y),
                       length:CGFloat(size.z),chamferRadius:0)
        let m = SCNMaterial(); m.diffuse.contents = color
        m.roughness.contents = NSNumber(value: 0.85)
        b.materials=[m]; let n=SCNNode(geometry:b); n.position=pos
        scene.rootNode.addChildNode(n)
    }

    private func buildFramedPainting(artwork: SavedArtwork) -> SCNNode {
        let container = SCNNode()
        container.name = artwork.id.uuidString
        let cW: CGFloat=2.2, cH: CGFloat=1.6, fT: CGFloat=0.14

        let canvas = SCNBox(width:cW,height:cH,length:0.04,chamferRadius:0)
        let cm = SCNMaterial()
        cm.diffuse.contents = renderDrawing(artwork)
        cm.roughness.contents = NSNumber(value: 0.75)
        canvas.materials=[cm,cm,cm,cm,cm,cm]
        let cn = SCNNode(geometry:canvas); cn.position=SCNVector3(0,0,0.02)
        container.addChildNode(cn)

        let gm = SCNMaterial()
        gm.diffuse.contents = UIColor(red:0.78,green:0.60,blue:0.16,alpha:1)
        gm.metalness.contents = NSNumber(value: 0.88)
        gm.roughness.contents = NSNumber(value: 0.22)
        gm.lightingModel = .physicallyBased

        let bars: [(SCNVector3,SCNVector3)] = [
            (SCNVector3(Float(cW+fT*2),Float(fT),0.07), SCNVector3(0,Float(cH/2+fT/2),0)),
            (SCNVector3(Float(cW+fT*2),Float(fT),0.07), SCNVector3(0,Float(-(cH/2+fT/2)),0)),
            (SCNVector3(Float(fT),Float(cH),0.07),       SCNVector3(Float(-(cW/2+fT/2)),0,0)),
            (SCNVector3(Float(fT),Float(cH),0.07),       SCNVector3(Float(cW/2+fT/2),0,0))
        ]
        for (sz,p) in bars {
            let b=SCNBox(width:CGFloat(sz.x),height:CGFloat(sz.y),
                         length:CGFloat(sz.z),chamferRadius:0.015)
            b.materials=[gm]; let n=SCNNode(geometry:b); n.position=p
            container.addChildNode(n)
        }
        return container
    }

    private func buildSpotlight(at pos: SCNVector3, pointing target: SCNVector3,
                                 in scene: SCNScene) {
        let l = SCNLight(); l.type = .spot
        l.color = UIColor(red:1.0,green:0.90,blue:0.68,alpha:1)
        l.intensity = 1200; l.spotInnerAngle = 20; l.spotOuterAngle = 45
        l.castsShadow = true; l.shadowRadius = 6
        l.shadowColor = UIColor.black.withAlphaComponent(0.65)
        l.attenuationStartDistance = 2; l.attenuationEndDistance = 12
        let n = SCNNode(); n.light=l; n.position=pos; n.look(at:target)
        scene.rootNode.addChildNode(n)
    }

    private func renderDrawing(_ artwork: SavedArtwork) -> UIImage {
        let drawing = artwork.drawing
        let size = CGSize(width: 660, height: 480)
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            UIColor(red: 0.97, green: 0.96, blue: 0.92, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Guard: nothing to draw → cream canvas, no crash
            guard !drawing.strokes.isEmpty else { return }

            // Guard: bounds must be real and non-zero
            let rawBounds = drawing.bounds
            guard rawBounds.width > 1, rawBounds.height > 1,
                  rawBounds.width.isFinite, rawBounds.height.isFinite,
                  rawBounds.origin.x.isFinite, rawBounds.origin.y.isFinite else { return }

            let bounds = rawBounds.insetBy(dx: -20, dy: -20)

            // Guard: scale must be positive and finite before calling PKDrawing.image
            let scaleRaw = min(size.width / bounds.width, size.height / bounds.height) * 0.82
            guard scaleRaw.isFinite, scaleRaw > 0 else { return }
            let scale = max(0.1, scaleRaw)

            let sW = bounds.width * scale
            let sH = bounds.height * scale
            guard sW > 0, sH > 0 else { return }

            drawing.image(from: bounds, scale: scale)
                .draw(in: CGRect(x: (size.width - sW) / 2,
                                 y: (size.height - sH) / 2,
                                 width: sW, height: sH))
        }
    }

    // MARK: Coordinator

    class Coordinator: NSObject {
        var artworks: [SavedArtwork]
        var onTapArtwork: (SavedArtwork) -> Void
        var paintingNodes: [(node: SCNNode, artwork: SavedArtwork)] = []
        weak var sceneView: SCNView?
        var cameraNode: SCNNode?
        private var panStartX: Float = 0

        var onPanBegan: (() -> Void)?

        init(artworks: [SavedArtwork], onTapArtwork: @escaping (SavedArtwork) -> Void,
             onPanBegan: (() -> Void)? = nil) {
            self.artworks = artworks
            self.onTapArtwork = onTapArtwork
            self.onPanBegan = onPanBegan
        }

        @MainActor @objc func handleTap(_ r: UITapGestureRecognizer) {
            guard let sv = sceneView else { return }
            let loc = r.location(in: sv)
            let hits = sv.hitTest(loc, options: [
                SCNHitTestOption.searchMode: SCNHitTestSearchMode.all.rawValue
            ])
            for hit in hits {
                var node: SCNNode? = hit.node
                while node != nil {
                    if let name = node?.name,
                       let match = paintingNodes.first(where: { $0.node.name == name }) {
                        let pop = SCNAction.sequence([
                            SCNAction.scale(to:1.06, duration:0.12),
                            SCNAction.scale(to:1.0,  duration:0.12)
                        ])
                        match.node.runAction(pop)
                        DispatchQueue.main.asyncAfter(deadline: .now()+0.15) {
                            self.onTapArtwork(match.artwork)
                        }
                        return
                    }
                    node = node?.parent
                }
            }
        }

        @MainActor @objc func handlePan(_ r: UIPanGestureRecognizer) {
            guard let camera = cameraNode, let sv = r.view else { return }
            let t = r.translation(in: sv)
            switch r.state {
            case .began:
                panStartX = camera.position.x
                DispatchQueue.main.async { self.onPanBegan?() }
            case .changed:
                let delta = Float(t.x) * 0.012
                let newX = panStartX - delta
                let maxX = Float(max(0, artworks.count-1)) * 3.8 / 2
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0
                camera.position.x = max(-maxX-0.5, min(maxX+0.5, newX))
                SCNTransaction.commit()
            case .ended, .cancelled:
                let spacing: Float = 3.8
                let maxX = Float(max(0, artworks.count-1)) * spacing / 2
                let clamped = max(-maxX, min(maxX, camera.position.x))
                let nearest = round(clamped/spacing)*spacing
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.4
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name:.easeInEaseOut)
                camera.position.x = nearest
                SCNTransaction.commit()
            default: break
            }
        }
    }
}
