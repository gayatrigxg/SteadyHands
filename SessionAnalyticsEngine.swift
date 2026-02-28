import Foundation
import PencilKit
import CoreGraphics

// MARK: - Session Analytics Engine
// Aggregates motor metrics across entire exercise session

final class SessionAnalyticsEngine {
    
    private(set) var totalTremor: CGFloat = 0
    private(set) var totalPressureVariance: CGFloat = 0
    private(set) var totalVelocityVariance: CGFloat = 0
    private(set) var totalFrequency: CGFloat = 0
    
    private(set) var strokeCount: Int = 0
    
    func process(stroke: PKStroke) {
        
        let metrics = MotorAnalysisEngine.analyze(stroke: stroke)
        
        totalTremor += metrics.tremorAmplitude
        totalPressureVariance += metrics.pressureVariance
        totalVelocityVariance += metrics.velocityVariance
        totalFrequency += metrics.tremorFrequency
        
        strokeCount += 1
    }
    
    func finalize() -> AggregatedMetrics {
        
        guard strokeCount > 0 else {
            return AggregatedMetrics(
                stabilityScore: 0,
                pressureScore: 0,
                rhythmScore: 0,
                tremorFrequencyScore: 0
            )
        }
        
        let avgTremor = totalTremor / CGFloat(strokeCount)
        let avgPressureVar = totalPressureVariance / CGFloat(strokeCount)
        let avgVelocityVar = totalVelocityVariance / CGFloat(strokeCount)
        let avgFrequency = totalFrequency / CGFloat(strokeCount)
        
        let stabilityScore = max(0, min(100, Int(100 - avgTremor * 2)))
        let pressureScore = max(0, min(100, Int((1 - avgPressureVar) * 100)))
        let rhythmScore = max(0, min(100, Int(100 - avgVelocityVar)))
        let tremorFrequencyScore = max(0, min(100, Int(100 - avgFrequency)))
        
        return AggregatedMetrics(
            stabilityScore: stabilityScore,
            pressureScore: pressureScore,
            rhythmScore: rhythmScore,
            tremorFrequencyScore: tremorFrequencyScore
        )
    }
    
    func reset() {
        totalTremor = 0
        totalPressureVariance = 0
        totalVelocityVariance = 0
        totalFrequency = 0
        strokeCount = 0
    }
}

// MARK: - Aggregated Result

struct AggregatedMetrics {
    let stabilityScore: Int
    let pressureScore: Int
    let rhythmScore: Int
    let tremorFrequencyScore: Int
}
