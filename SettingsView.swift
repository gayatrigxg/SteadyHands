import SwiftUI

struct SettingsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {

                // MARK: Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Settings")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Customize your experience")
                        .font(.system(size: 19))
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 16)

                // MARK: Appearance
                SettingsSectionBlock(title: "Appearance") {
                    SettingsToggleRow(
                        title: "Dark Mode",
                        subtitle: "Switch between light and dark themes",
                        isOn: $settings.darkMode
                    )
                }

                // MARK: Tremor Filter
                SettingsSectionBlock(title: "Tremor Filter") {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Filter Strength")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Text(tremorFilterLabel)
                                .font(.system(size: 16))
                                .foregroundColor(.brandPrimary)
                        }

                        Slider(value: $settings.tremorFilterStrength, in: 0...1, step: 0.05)
                            .tint(.brandPrimary)

                        HStack {
                            Text("Off")
                            Spacer()
                            Text("Soft")
                            Spacer()
                            Text("Strong")
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.textSecondary)
                    }
                }

                // MARK: Stroke Stabilization
                SettingsSectionBlock(title: "Stroke Stabilization") {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsToggleRow(
                            title: "Stroke Stabilization",
                            subtitle: "Smooths path lag — reduces shaky lines",
                            isOn: $settings.strokeStabilization
                        )

                        if settings.strokeStabilization {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Amount")
                                        .font(.system(size: 17))
                                        .foregroundColor(.textSecondary)
                                    Spacer()
                                    Text("\(Int(settings.stabilizationAmount * 100))%")
                                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.textPrimary)
                                }
                                Slider(value: $settings.stabilizationAmount, in: 0...0.9, step: 0.05)
                                    .tint(.brandPrimary)
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: settings.strokeStabilization)
                }

                // MARK: Input Controls
                SettingsSectionBlock(title: "Input Controls") {
                    VStack(spacing: 0) {
                        SettingsToggleRow(
                            title: "Pressure Compensation",
                            subtitle: "Normalizes grip force — consistent line width even with tremor pressure spikes",
                            isOn: $settings.pressureCompensation
                        )

                        NativeDivider()

                        SettingsToggleRow(
                            title: "Velocity Damping",
                            subtitle: "Clamps stroke speed — prevents fast erratic movements",
                            isOn: $settings.velocityDamping
                        )

                        NativeDivider()

                        SettingsToggleRow(
                            title: "Adaptive Assist",
                            subtitle: "Automatically increases filter strength mid-stroke when tremor is detected",
                            isOn: $settings.adaptiveAssist
                        )
                    }
                }

                // MARK: Micro-Jitter
                SettingsSectionBlock(title: "Micro-Jitter Threshold") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Ignores movements smaller than \(String(format: "%.1f", settings.jitterThreshold))pt — eliminates fine tremor noise")
                            .font(.system(size: 16))
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Slider(value: $settings.jitterThreshold, in: 0...5, step: 0.5)
                            .tint(.brandPrimary)

                        HStack {
                            Text("0pt  (off)")
                            Spacer()
                            Text("5pt  (strong)")
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.textSecondary)
                    }
                }

                // MARK: Active Profile Summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Assist Profile")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .textCase(.uppercase)
                        .kerning(0.4)

                    HStack(spacing: 10) {
                        ProfilePill(label: "Filter",
                                    value: "\(Int(settings.tremorFilterStrength * 100))%",
                                    active: settings.tremorFilterStrength > 0)
                        ProfilePill(label: "Stabilize",
                                    value: settings.strokeStabilization ? "\(Int(settings.stabilizationAmount * 100))%" : "Off",
                                    active: settings.strokeStabilization)
                        ProfilePill(label: "Pressure",
                                    value: settings.pressureCompensation ? "On" : "Off",
                                    active: settings.pressureCompensation)
                        ProfilePill(label: "Velocity",
                                    value: settings.velocityDamping ? "On" : "Off",
                                    active: settings.velocityDamping)
                        ProfilePill(label: "Jitter",
                                    value: settings.jitterThreshold > 0 ? "\(String(format: "%.1f", settings.jitterThreshold))pt" : "Off",
                                    active: settings.jitterThreshold > 0)
                    }
                }

                // MARK: Medical Disclaimer
                Text("This app is a creative training tool and does not diagnose or treat medical conditions. Drawing assist features support motor-training exercises for creative expression only.")
                    .font(.system(size: 15))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 22)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    private var tremorFilterLabel: String {
        switch settings.tremorFilterStrength {
        case 0:            return "Off — raw Apple Pencil input"
        case 0.01..<0.35:  return "Light — subtle smoothing only"
        case 0.35..<0.65:  return "Soft Assist — smoothing and micro hints"
        case 0.65..<0.85:  return "Strong Assist — significant tremor reduction"
        default:           return "Maximum — full guided smoothing"
        }
    }
}

// MARK: - Section Block (title + card)

struct SettingsSectionBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
                .kerning(0.4)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(Color.cardBackground)
            .cornerRadius(18)
        }
    }
}

// MARK: - Legacy container (kept for compatibility)

struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(Color.cardBackground)
            .cornerRadius(18)
    }
}

// MARK: - Section Header (standalone, kept for compatibility)

struct SettingsSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.textSecondary)
            .textCase(.uppercase)
            .kerning(0.4)
            .padding(.leading, 2)
    }
}

// MARK: - Divider

struct NativeDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 16)
    }
}

// MARK: - Toggle Row

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.brandPrimary)
                .scaleEffect(1.1)
        }
    }
}

// MARK: - Profile Pill

struct ProfilePill: View {
    let label: String
    let value: String
    let active: Bool

    var body: some View {
        VStack(spacing: 7) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(active ? .brandPrimary : .textSecondary)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(active ? Color.brandPrimary.opacity(0.09) : Color(UIColor.tertiarySystemFill))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(active ? Color.brandPrimary.opacity(0.25) : Color.clear, lineWidth: 1.5)
        )
    }
}
