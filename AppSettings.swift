import Foundation
import SwiftUI

// MARK: - Tremor Profile
// Result of the Baseline Scan. Stored and displayed across the app.

struct TremorProfile {
    let date: Date
    let amplitudeMM: Double          // average oscillation amplitude (mm proxy)
    let dominantFrequencyHz: Double  // estimated Hz from direction changes
    let pressureVariance: Double     // 0–1
    let horizontalBias: Double       // >0.5 = more horizontal, <0.5 = more vertical
    let fatigueIncrease: Double      // % tremor increase in second half of hold

    var amplitudeLabel: String {
        switch amplitudeMM {
        case ..<1.0:  return "Minimal"
        case ..<2.5:  return "Mild"
        case ..<5.0:  return "Moderate"
        default:      return "Elevated"
        }
    }

    var frequencyLabel: String {
        switch dominantFrequencyHz {
        case ..<4:   return "Low"
        case ..<7:   return "Mid-range"
        case ..<10:  return "High"
        default:     return "Very High"
        }
    }

    var biasLabel: String {
        horizontalBias > 0.6 ? "Horizontal" :
        horizontalBias < 0.4 ? "Vertical"   : "Mixed"
    }

    var fatigueLabel: String {
        fatigueIncrease < 10 ? "Stable" :
        fatigueIncrease < 25 ? "Mild fatigue" : "Significant fatigue"
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }

    // Suggest a filter strength based on the scan results
    var recommendedFilterStrength: Double {
        let ampFactor      = min(amplitudeMM / 5.0, 1.0)
        let freqFactor     = min(dominantFrequencyHz / 12.0, 1.0)
        let pressureFactor = pressureVariance
        let raw = (ampFactor * 0.5) + (freqFactor * 0.3) + (pressureFactor * 0.2)
        return min(0.95, max(0.15, raw))
    }
}

final class AppSettings: ObservableObject {

    // MARK: - Appearance
    @Published var darkMode: Bool = false

    // MARK: - Apple Pencil / Drawing Assist
    @Published var tremorFilterStrength: Double = 0.5
    @Published var pressureCompensation: Bool = true
    @Published var velocityDamping: Bool = true
    @Published var jitterThreshold: Double = 1.5
    @Published var adaptiveAssist: Bool = true
    @Published var strokeStabilization: Bool = true
    @Published var stabilizationAmount: Double = 0.4

    // MARK: - Legacy (kept for SteadyCanvas compatibility)
    @Published var assistLevel: CGFloat = 0.5
    @Published var smoothingEnabled: Bool = true
    @Published var shapeRecognitionEnabled: Bool = false

    // MARK: - Sessions
    @Published var sessions: [DrawingSession] = []
    @Published var drillSessions: [DrillSession] = []
    @Published var totalStrokes: Int = 0

    // MARK: - Tremor Profile (from Baseline Scan)
    @Published var tremorProfile: TremorProfile? = nil

    // MARK: - Derived

    var effectiveAssistLevel: CGFloat { CGFloat(tremorFilterStrength) }

    var avgStability: Int {
        let all = combinedStabilityScores
        guard !all.isEmpty else { return 0 }
        return all.reduce(0, +) / all.count
    }

    var avgTremor: Float {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.avgTremorStrength).reduce(0, +) / Float(sessions.count)
    }

    var avgFrequency: Float {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.avgDominantFrequency).reduce(0, +) / Float(sessions.count)
    }

    var avgAssist: Float {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map(\.avgAssistUsed).reduce(0, +) / Float(sessions.count)
    }

    var combinedStabilityScores: [Int] {
        sessions.map(\.avgStability) + drillSessions.map(\.asAvgStability)
    }

    var totalSessionCount: Int { sessions.count + drillSessions.count }

    var recentDrillSessions: [DrillSession] {
        Array(drillSessions.sorted { $0.date > $1.date }.prefix(10).reversed())
    }

    func bestScore(for type: DrillType) -> CGFloat? {
        drillSessions.filter { $0.drillType == type }.map(\.score).max()
    }

    func completionCount(for type: DrillType) -> Int {
        drillSessions.filter { $0.drillType == type }.count
    }

    // MARK: - Save

    func saveDrillSession(type: DrillType, score: MotorAnalysisEngine.DrillScore, durationSeconds: Int) {
        drillSessions.append(DrillSession(
            date: Date(),
            drillType: type,
            score: score.primary,
            breakdown: score.breakdown.map { ($0.label, $0.value) },
            feedbackMessage: score.feedbackMessage,
            durationSeconds: durationSeconds
        ))
    }

    func saveDrawSession(strokeCount: Int, stability: Int, pressure: Int, rhythm: Int,
                         tremorStrength: Float = 0, dominantFrequency: Float = 0, assistUsed: Float = 0) {
        sessions.append(DrawingSession(
            date: Date(),
            strokeCount: strokeCount,
            avgStability: stability,
            avgPressure: pressure,
            avgRhythm: rhythm,
            avgTremorStrength: tremorStrength,
            avgDominantFrequency: dominantFrequency,
            avgAssistUsed: assistUsed
        ))
        totalStrokes += strokeCount
    }

    func saveTremorProfile(_ profile: TremorProfile) {
        tremorProfile = profile
    }
}
