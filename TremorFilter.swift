import Foundation
import CoreGraphics

struct TremorFilter {
    
    // MARK: - Low Pass
    
    static func lowPass(
        previous: CGPoint,
        current: CGPoint,
        alpha: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: previous.x + alpha * (current.x - previous.x),
            y: previous.y + alpha * (current.y - previous.y)
        )
    }
    
    // MARK: - Adaptive Smoothing
    // assistLevel: 0.0 (minimal assist) → 1.0 (maximum assist)
    
    static func adaptiveSmoothing(
        points: [CGPoint],
        assistLevel: CGFloat
    ) -> [CGPoint] {
        
        guard points.count > 2 else { return points }
        
        var smoothed: [CGPoint] = []
        smoothed.append(points[0])
        
        for i in 1..<points.count {
            
            let prev = smoothed[i - 1]
            let current = points[i]
            
            let velocity = hypot(
                current.x - prev.x,
                current.y - prev.y
            )
            
            // Base smoothing depends on velocity
            let baseAlpha: CGFloat
            if velocity < 1 {
                baseAlpha = 0.15
            } else if velocity < 4 {
                baseAlpha = 0.25
            } else {
                baseAlpha = 0.40
            }
            
            // Scale smoothing by assist level
            let scaledAlpha = baseAlpha * (1 + assistLevel)
            
            let filtered = lowPass(
                previous: prev,
                current: current,
                alpha: min(0.85, scaledAlpha)
            )
            
            smoothed.append(filtered)
        }
        
        return smoothed
    }
    
    // MARK: - Jitter Reduction
    
    static func jitterReduction(
        points: [CGPoint],
        threshold: CGFloat = 1.5
    ) -> [CGPoint] {
        
        guard points.count > 2 else { return points }
        
        var filtered: [CGPoint] = [points[0]]
        
        for i in 1..<points.count {
            let prev = filtered.last!
            let current = points[i]
            
            let distance = hypot(
                current.x - prev.x,
                current.y - prev.y
            )
            
            if distance > threshold {
                filtered.append(current)
            } else {
                filtered.append(prev)
            }
        }
        
        return filtered
    }
}
