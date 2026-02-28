import SwiftUI
import PencilKit

// MARK: - Onboarding Root

struct OnboardingView: View {

    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground).ignoresSafeArea()

            switch currentPage {
            case 0:
                OnboardingPage1 { currentPage = 1 }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            case 1:
                OnboardingPage2 { hasSeenOnboarding = true }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .leading)
                    ))
            default:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentPage)
    }
}

// MARK: - Page 1: The Tremor Moment

struct OnboardingPage1: View {

    let onNext: () -> Void

    @State private var shakeyProgress: CGFloat = 0
    @State private var smoothProgress: CGFloat = 0
    @State private var hasAnimated = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {

                Spacer()

                // Line illustration
                ZStack {
                    ShakyLineShape(progress: shakeyProgress)
                        .trim(from: 0, to: shakeyProgress)
                        .stroke(
                            Color.brandPrimary.opacity(0.35),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: geo.size.width * 0.55, height: 80)

                    SmoothLineShape(progress: smoothProgress)
                        .trim(from: 0, to: smoothProgress)
                        .stroke(
                            Color.brandPrimary,
                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                        )
                        .frame(width: geo.size.width * 0.55, height: 80)
                }
                .frame(height: 100)
                .padding(.bottom, 56)

                // Headline
                VStack(spacing: 8) {
                    Text("Your hand shakes.")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Your ideas don't.")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.textPrimary)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)

                Text("We separate intention from tremor — in real time.")
                    .font(.system(size: 20))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()

                PrimaryButton(title: "Try it") { onNext() }
                    .padding(.horizontal, geo.size.width * 0.1)
                    .padding(.bottom, 52)
            }
            .frame(maxWidth: .infinity)
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                withAnimation(.linear(duration: 1.4)) { shakeyProgress = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.linear(duration: 1.0)) { smoothProgress = 1.0 }
                }
            }
        }
    }
}

// MARK: - Shaky Line Shape

struct ShakyLineShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 120
        let w = rect.width
        let midY = rect.midY
        let amp: CGFloat = 10
        path.move(to: CGPoint(x: 0, y: midY))
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = t * w
            let y = midY + sin(t * .pi * 2) * amp * 0.4
                        + sin(t * .pi * 14) * amp
                        + sin(t * .pi * 22) * amp * 0.5
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }
}

// MARK: - Smooth Line Shape

struct SmoothLineShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let midY = rect.midY
        let amp: CGFloat = 10
        path.move(to: CGPoint(x: 0, y: midY))
        path.addCurve(
            to: CGPoint(x: w, y: midY),
            control1: CGPoint(x: w * 0.25, y: midY - amp * 0.4),
            control2: CGPoint(x: w * 0.75, y: midY + amp * 0.4)
        )
        return path
    }
}

// MARK: - Page 2: How We Help

struct OnboardingPage2: View {

    let onNext: () -> Void

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("arrow.up.and.line.horizontal.and.arrow.down",
         "Pressure-aware",
         "Press firmly for stability. Lightly to keep your texture."),
        ("waveform.path.ecg",
         "Real-time smoothing",
         "Filters involuntary tremor without changing your style."),
        ("hand.tap",
         "Instant adjustment",
         "Change your support level anytime, mid-stroke.")
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {

                Spacer()

                // Headline
                VStack(spacing: 8) {
                    Text("Designed for")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("unsteady hands.")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundColor(.brandPrimary)
                    Text("Train your hand. Track your progress.")
                        .font(.system(size: 20))
                        .foregroundColor(.textSecondary)
                        .padding(.top, 6)
                }
                .multilineTextAlignment(.center)
                .padding(.bottom, 56)

                // Feature rows — no animation, constrained to readable width
                VStack(spacing: 0) {
                    ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                        HStack(spacing: 24) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.brandPrimary.opacity(0.10))
                                    .frame(width: 64, height: 64)
                                Image(systemName: feature.icon)
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.brandPrimary)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(feature.title)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                Text(feature.subtitle)
                                    .font(.system(size: 17))
                                    .foregroundColor(.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 22)

                        if index < features.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, geo.size.width * 0.1)
                .frame(maxWidth: 720)

                Spacer()

                PrimaryButton(title: "Start Training") { onNext() }
                    .padding(.horizontal, geo.size.width * 0.1)
                    .padding(.bottom, 52)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Shared: Primary Button

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(Color.brandPrimary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Shared: Trust Badge (kept for compatibility)

struct TrustBadge: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(.brandPrimary)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(UIColor.systemGroupedBackground))
        .cornerRadius(16)
    }
}
