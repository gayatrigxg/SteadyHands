import SwiftUI

extension Color {

    // MARK: - Adaptive backgrounds (light/dark aware)
    static let appBackground     = Color(UIColor.systemGroupedBackground)
    static let cardBackground    = Color(UIColor.secondarySystemGroupedBackground)

    // MARK: - Brand (single accent — iOS standard single-color approach)
    static let brandPrimary      = Color(red: 0.40, green: 0.33, blue: 0.85)

    // MARK: - Adaptive text
    static let textPrimary       = Color(UIColor.label)
    static let textSecondary     = Color(UIColor.secondaryLabel)

    // MARK: - Metrics (used sparingly, only for data)
    static let metricBlue        = Color(UIColor.systemBlue)
    static let metricOrange      = Color(UIColor.systemOrange)
    static let metricGreen       = Color(UIColor.systemGreen)
    static let metricRed         = Color(UIColor.systemRed)

    // MARK: - Soft tints
    static let softPurple        = brandPrimary.opacity(0.12)
    static let softBlue          = Color(UIColor.systemBlue).opacity(0.12)
    static let softGreen         = Color(UIColor.systemGreen).opacity(0.12)
    static let softOrange        = Color(UIColor.systemOrange).opacity(0.12)
}
