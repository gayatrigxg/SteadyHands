import SwiftUI
import PencilKit

// MARK: - Museum Reveal View

struct MuseumRevealView: View {

    let drawing: PKDrawing
    let stabilityScore: Int
    let pressureScore: Int
    let rhythmScore: Int
    let strokeCount: Int
    let onSave: (String) -> Void
    let onDiscard: () -> Void

    @State private var titleText = ""
    @State private var showTitleInput = false
    @FocusState private var titleFocused: Bool
    @State private var paintingImage: UIImage? = nil

    // Entrance animation states
    @State private var wallOpacity: Double = 0
    @State private var spotlightOpacity: Double = 0
    @State private var spotlightScale: CGFloat = 0.4
    @State private var frameOpacity: Double = 0
    @State private var frameOffset: CGFloat = 50
    @State private var frameScale: CGFloat = 0.93
    @State private var plaqueOpacity: Double = 0
    @State private var plaqueOffset: CGFloat = 14
    @State private var benchOpacity: Double = 0
    @State private var buttonsOpacity: Double = 0
    @State private var buttonsOffset: CGFloat = 20

    // Hang-away transition
    @State private var isHanging = false
    @State private var hangScale: CGFloat = 1.0
    @State private var hangOpacity: Double = 1.0
    @State private var hangOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background wall
                roomBackground(geo: geo)

                VStack(spacing: 0) {
                    Spacer()

                    // Spotlight + frame
                    ZStack(alignment: .top) {
                        // Spotlight cone from top
                        RadialGradient(
                            colors: [
                                Color(red: 0.95, green: 0.78, blue: 0.42).opacity(0.30),
                                Color(red: 0.90, green: 0.65, blue: 0.25).opacity(0.10),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 200
                        )
                        .frame(width: 380, height: 300)
                        .offset(y: -50)
                        .scaleEffect(spotlightScale)
                        .opacity(spotlightOpacity)

                        // The painting in its frame
                        framedPainting(geo: geo)
                            .offset(y: frameOffset)
                            .opacity(frameOpacity)
                            .scaleEffect(frameScale)
                            .scaleEffect(hangScale)
                            .opacity(hangOpacity)
                            .offset(y: hangOffset)
                    }

                    // Plaque
                    if !showTitleInput {
                        plaqueView
                            .opacity(plaqueOpacity)
                            .offset(y: plaqueOffset)
                            .padding(.top, 20)
                    } else {
                        titleInputArea
                            .padding(.top, 20)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer()

                    // Wooden benches
                    benchesRow
                        .opacity(benchOpacity)
                        .padding(.bottom, 10)

                    // Buttons
                    buttonsArea
                        .opacity(buttonsOpacity)
                        .offset(y: buttonsOffset)
                        .padding(.horizontal, 32)
                        .padding(.bottom, max(geo.safeAreaInsets.bottom + 16, 44))
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.22), value: showTitleInput)
        .onAppear {
            renderPainting()
            runEntrance()
        }
    }

    // MARK: - Room Background

    @ViewBuilder
    private func roomBackground(geo: GeometryProxy) -> some View {
        ZStack {
            Color(red: 0.14, green: 0.12, blue: 0.10).ignoresSafeArea()

            LinearGradient(
                colors: [Color(red: 0.22, green: 0.18, blue: 0.13), Color.clear],
                startPoint: .top, endPoint: .init(x: 0.5, y: 0.5)
            ).ignoresSafeArea()

            // Wood floor
            VStack {
                Spacer()
                LinearGradient(
                    colors: [
                        Color(red: 0.44, green: 0.29, blue: 0.15),
                        Color(red: 0.33, green: 0.20, blue: 0.09)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 120)
                .ignoresSafeArea(edges: .bottom)
            }

            // Wall/floor divider
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color(red: 0.52, green: 0.40, blue: 0.24).opacity(0.45))
                    .frame(height: 1)
                    .padding(.bottom, 120)
            }
        }
        .opacity(wallOpacity)
    }

    // MARK: - Framed Painting

    @ViewBuilder
    private func framedPainting(geo: GeometryProxy) -> some View {
        let availW = min(geo.size.width - 80, geo.size.height * 0.52)
        let canvasW = availW
        let canvasH = availW * 0.70
        let borderW: CGFloat = 18

        ZStack {
            // Outer gold frame
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.88, green: 0.70, blue: 0.24),
                            Color(red: 0.68, green: 0.48, blue: 0.12),
                            Color(red: 0.93, green: 0.78, blue: 0.32),
                            Color(red: 0.62, green: 0.43, blue: 0.10),
                            Color(red: 0.88, green: 0.70, blue: 0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: canvasW + borderW * 2,
                       height: canvasH + borderW * 2)
                .shadow(color: .black.opacity(0.55), radius: 28, x: 0, y: 14)
                .shadow(color: Color(red: 0.88, green: 0.70, blue: 0.24).opacity(0.25),
                        radius: 8, x: 0, y: 0)

            // Inner dark inset
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0.10, green: 0.08, blue: 0.04))
                .frame(width: canvasW + 6, height: canvasH + 6)

            // Canvas
            ZStack {
                Color(red: 0.98, green: 0.97, blue: 0.94)
                if let img = paintingImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                } else {
                    Text("Your masterpiece")
                        .font(.system(size: 13, weight: .light))
                        .italic()
                        .foregroundColor(.black.opacity(0.18))
                }
                // Canvas vignette
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.06)],
                    center: .center,
                    startRadius: canvasW * 0.3,
                    endRadius: canvasW * 0.72
                )
            }
            .frame(width: canvasW, height: canvasH)
            .clipShape(RoundedRectangle(cornerRadius: 1))
        }
    }

    // MARK: - Plaque

    private var plaqueView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text(titleText.isEmpty ? "Untitled" : titleText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(red: 0.18, green: 0.14, blue: 0.08))
                Text(currentDate)
                    .font(.system(size: 12))
                    .foregroundColor(Color(red: 0.48, green: 0.37, blue: 0.22))
                Divider()
                    .background(Color(red: 0.72, green: 0.58, blue: 0.35).opacity(0.5))
                    .padding(.vertical, 3)
                HStack(spacing: 18) {
                    PlaqueMetric(label: "Stability", value: "\(stabilityScore)%")
                    PlaqueMetric(label: "Pressure",  value: "\(pressureScore)%")
                    PlaqueMetric(label: "Strokes",   value: "\(strokeCount)")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    Color(red: 0.95, green: 0.92, blue: 0.84)
                    LinearGradient(colors: [.white.opacity(0.35), .clear],
                                   startPoint: .top, endPoint: .bottom)
                }
            )
            .cornerRadius(3)
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(Color(red: 0.78, green: 0.64, blue: 0.40).opacity(0.55), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 6, x: 0, y: 3)
            .frame(maxWidth: 260)

            Rectangle()
                .fill(Color(red: 0.52, green: 0.40, blue: 0.22))
                .frame(width: 2, height: 14)
            Capsule()
                .fill(Color(red: 0.42, green: 0.30, blue: 0.16))
                .frame(width: 54, height: 5)
        }
    }

    private var currentDate: String {
        let f = DateFormatter(); f.dateFormat = "MMMM d, yyyy"
        return f.string(from: Date())
    }

    // MARK: - Title Input

    private var titleInputArea: some View {
        VStack(spacing: 12) {
            Text("Name your piece")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(red: 0.85, green: 0.70, blue: 0.42))

            TextField("Untitled", text: $titleText)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Color(red: 0.96, green: 0.93, blue: 0.86))
                .multilineTextAlignment(.center)
                .focused($titleFocused)
                .submitLabel(.done)
                .onSubmit { triggerHang() }
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.45), lineWidth: 1))
                .frame(maxWidth: 270)

            Button { triggerHang() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "building.columns.fill").font(.system(size: 14))
                    Text("Hang in My Museum").font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.11, green: 0.09, blue: 0.06))
                .frame(maxWidth: 270)
                .frame(height: 52)
                .background(LinearGradient(
                    colors: [Color(red: 0.92, green: 0.76, blue: 0.30),
                             Color(red: 0.76, green: 0.56, blue: 0.16)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(13)
                .shadow(color: Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.38),
                        radius: 10, x: 0, y: 4)
            }
            .disabled(isHanging)
        }
    }

    // MARK: - Benches

    private var benchesRow: some View {
        HStack(spacing: 44) { bench; bench }
    }

    private var bench: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(
                    colors: [Color(red: 0.50, green: 0.33, blue: 0.16),
                             Color(red: 0.36, green: 0.22, blue: 0.09)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 78, height: 9)
            HStack(spacing: 52) {
                benchLeg; benchLeg
            }
        }
    }

    private var benchLeg: some View {
        Rectangle()
            .fill(Color(red: 0.40, green: 0.26, blue: 0.11))
            .frame(width: 5, height: 16)
    }

    // MARK: - Buttons

    private var buttonsArea: some View {
        VStack(spacing: 11) {
            if !showTitleInput {
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
                        showTitleInput = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                        titleFocused = true
                    }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: "building.columns.fill").font(.system(size: 15))
                        Text("Hang in My Museum").font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.11, green: 0.09, blue: 0.06))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(
                        colors: [Color(red: 0.92, green: 0.76, blue: 0.30),
                                 Color(red: 0.76, green: 0.56, blue: 0.16)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(14)
                    .shadow(color: Color(red: 0.85, green: 0.68, blue: 0.22).opacity(0.40),
                            radius: 12, x: 0, y: 5)
                }

                Button { onDiscard() } label: {
                    Text("Keep Drawing")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.74, green: 0.60, blue: 0.40))
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(red: 0.74, green: 0.60, blue: 0.40).opacity(0.28), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - Hang Transition

    private func triggerHang() {
        guard !isHanging else { return }
        isHanging = true
        titleFocused = false

        // Pop up slightly
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            hangScale = 1.07
        }
        // Fly away — shrinks and floats up into the wall
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeIn(duration: 0.42)) {
                hangScale   = 0.12
                hangOpacity = 0
                hangOffset  = -90
                spotlightOpacity = 0
                plaqueOpacity    = 0
                benchOpacity     = 0
                buttonsOpacity   = 0
            }
        }
        // After animation completes — call onSave, parent switches to gallery
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            onSave(titleText.isEmpty ? "Untitled" : titleText)
        }
    }

    // MARK: - Entrance Animation

    private func runEntrance() {
        withAnimation(.easeIn(duration: 0.45)) { wallOpacity = 1 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 0.80)) {
                spotlightScale   = 1.0
                spotlightOpacity = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.70)) {
                frameOffset = 0
                frameOpacity = 1
                frameScale   = 1.0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) {
            withAnimation(.easeOut(duration: 0.45)) {
                plaqueOpacity = 1
                plaqueOffset  = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.60) {
            withAnimation(.easeOut(duration: 0.35)) { benchOpacity = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.80) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78)) {
                buttonsOpacity = 1
                buttonsOffset  = 0
            }
        }
    }

    // MARK: - Render Drawing

    private func renderPainting() {
        DispatchQueue.global(qos: .userInitiated).async {
            let bounds = drawing.bounds.isEmpty
                ? CGRect(x: 0, y: 0, width: 400, height: 280)
                : drawing.bounds.insetBy(dx: -24, dy: -24)
            let img = drawing.image(from: bounds, scale: 2.0)
            DispatchQueue.main.async { paintingImage = img }
        }
    }
}

// MARK: - Plaque Metric

private struct PlaqueMetric: View {
    let label: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.18, green: 0.14, blue: 0.08))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.50, green: 0.38, blue: 0.22))
        }
    }
}
