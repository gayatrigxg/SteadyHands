import Foundation
import CoreGraphics

// MARK: - Assist Intelligence Engine
// Adapts smoothing + support level dynamically

final class AssistIntelligenceEngine {
    
    enum TremorSeverity {
        case low
        case moderate
        case high
    }
    
    private var previousStabilityScores: [Int] = []
    
    // MARK: - Classify Tremor
    
    func classify(stabilityScore: Int) -> TremorSeverity {
        switch stabilityScore {
        case 80...100:
            return .low
        case 55..<80:
            return .moderate
        default:
            return .high
        }
    }
    
    // MARK: - Adaptive Assist
    
    func recommendedAssistLevel(
        currentAssist: Float,
        stabilityScore: Int
    ) -> Float {
        
        let severity = classify(stabilityScore: stabilityScore)
        
        switch severity {
        case .low:
            return max(0.2, currentAssist - 0.05)
            
        case .moderate:
            return currentAssist
            
        case .high:
            return min(1.0, currentAssist + 0.08)
        }
    }
    
    // MARK: - Fatigue Detection
    
    func detectFatigue(currentStability: Int) -> Bool {
        
        previousStabilityScores.append(currentStability)
        
        if previousStabilityScores.count > 6 {
            previousStabilityScores.removeFirst()
        }
        
        guard previousStabilityScores.count >= 4 else { return false }
        
        let firstHalf = previousStabilityScores.prefix(2).reduce(0, +) / 2
        let lastHalf = previousStabilityScores.suffix(2).reduce(0, +) / 2
        
        return lastHalf < firstHalf - 10
    }
}
