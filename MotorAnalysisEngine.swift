import Foundation
import PencilKit
import CoreGraphics

// MARK: - Motor Analysis Engine
// Pure signal analysis. No UI. No side effects.

struct MotorAnalysisEngine {

    struct Metrics {
        let tremorAmplitude: CGFloat
        let tremorFrequency: CGFloat
        let pressureVariance: CGFloat
        let velocityVariance: CGFloat
    }

    struct DrillScore {
        let primary: CGFloat
        let label: String
        let breakdown: [ScoreItem]
        let feedbackMessage: String
        var primaryPercent: Int { Int(primary * 100) }
    }

    struct ScoreItem {
        let label: String
        let value: CGFloat
    }

    // MARK: - Core Analysis

    static func analyze(stroke: PKStroke) -> Metrics {
        let path = stroke.path
        let count = path.count
        guard count > 5 else {
            return Metrics(tremorAmplitude: 0, tremorFrequency: 0,
                           pressureVariance: 0, velocityVariance: 0)
        }
        let points = extractPoints(from: path)
        return Metrics(
            tremorAmplitude:  computeTremorAmplitude(points: points),
            tremorFrequency:  estimateTremorFrequency(points: points),
            pressureVariance: computePressureVariance(path: path),
            velocityVariance: computeVelocityVariance(path: path)
        )
    }
}

// MARK: - Drill Scoring

extension MotorAnalysisEngine {

    // MARK: 1. Tremor Trace
    static func scoreTremorTrace(stroke: PKStroke) -> DrillScore {
        let points = extractPoints(from: stroke.path)
        guard points.count > 4 else { return zeroScore("Tremor Index") }

        let meanY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        let deviations = points.map { abs($0.y - meanY) }
        let avgDeviation = deviations.reduce(0, +) / CGFloat(deviations.count)
        let amplitudeScore = max(0, 1.0 - (avgDeviation / 20.0))

        let metrics = analyze(stroke: stroke)
        let rawFreq = min(metrics.tremorFrequency, 30)
        let smoothnessScore = 1.0 - (rawFreq / 30.0)

        let rawVV = min(metrics.velocityVariance, 500)
        let velocityScore = 1.0 - (rawVV / 500.0)

        let combined = (amplitudeScore * 0.5) + (smoothnessScore * 0.3) + (velocityScore * 0.2)

        return DrillScore(
            primary: combined,
            label: "Tremor Index",
            breakdown: [
                ScoreItem(label: "Amplitude Control", value: amplitudeScore),
                ScoreItem(label: "Path Smoothness",   value: smoothnessScore),
                ScoreItem(label: "Speed Consistency", value: velocityScore)
            ],
            feedbackMessage: feedbackForScore(combined,
                low: "Try slowing down — let your arm rest on the surface",
                high: "Strong baseline control")
        )
    }

    static func tremorDeviations(from stroke: PKStroke) -> [CGFloat] {
        let points = extractPoints(from: stroke.path)
        guard points.count > 2 else { return [] }
        let meanY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        return points.map { $0.y - meanY }
    }

    // MARK: 2. Corridor Path
    // corridorPoints: the ideal center path points
    // userPoints: the user's drawn points
    // corridorWidth: how wide the corridor is in points
    static func scoreCorridorPath(
        userPoints: [CGPoint],
        corridorPoints: [CGPoint],
        corridorWidth: CGFloat
    ) -> DrillScore {
        guard userPoints.count > 5, corridorPoints.count > 2 else {
            return zeroScore("Path Score")
        }

        // For each user point, find distance to nearest corridor center point
        var inBandCount = 0
        var totalDeviation: CGFloat = 0

        for pt in userPoints {
            let minDist = corridorPoints.map { hypot(pt.x - $0.x, pt.y - $0.y) }.min() ?? corridorWidth
            if minDist <= corridorWidth / 2 {
                inBandCount += 1
            }
            totalDeviation += minDist
        }

        let accuracyScore = CGFloat(inBandCount) / CGFloat(userPoints.count)
        let avgDeviation = totalDeviation / CGFloat(userPoints.count)
        let smoothnessScore = max(0, 1.0 - (avgDeviation / (corridorWidth * 1.5)))

        // Completion: did they get from start to end?
        let startDist = hypot(userPoints.first!.x - corridorPoints.first!.x,
                              userPoints.first!.y - corridorPoints.first!.y)
        let endDist = hypot(userPoints.last!.x - corridorPoints.last!.x,
                            userPoints.last!.y - corridorPoints.last!.y)
        let completionScore: CGFloat = (startDist < 60 && endDist < 60) ? 1.0 :
                                       (endDist < 60) ? 0.85 : min(1.0, CGFloat(userPoints.count) / 50.0)

        let combined = (accuracyScore * 0.5) + (smoothnessScore * 0.3) + (completionScore * 0.2)

        return DrillScore(
            primary: min(1.0, combined),
            label: "Path Score",
            breakdown: [
                ScoreItem(label: "Inside Corridor", value: accuracyScore),
                ScoreItem(label: "Path Smoothness", value: smoothnessScore),
                ScoreItem(label: "Completion",      value: completionScore)
            ],
            feedbackMessage: feedbackForScore(combined,
                low: "Go slower — let your arm guide the movement",
                high: "Clean path control")
        )
    }

    // MARK: 3. Shrinking Target
    static func scoreShrinkingTarget(smallestRadiusHeld: CGFloat, startingRadius: CGFloat, totalHoldTime: TimeInterval) -> DrillScore {
        guard startingRadius > 0 else { return zeroScore("Precision Score") }

        let shrinkRatio = smallestRadiusHeld / startingRadius
        let precisionScore = max(0, 1.0 - shrinkRatio)
        let holdScore = CGFloat(min(totalHoldTime / 10.0, 1.0))
        let combined = (precisionScore * 0.7) + (holdScore * 0.3)

        return DrillScore(
            primary: combined,
            label: "Precision Score",
            breakdown: [
                ScoreItem(label: "Target Precision", value: precisionScore),
                ScoreItem(label: "Hold Duration",    value: holdScore)
            ],
            feedbackMessage: feedbackForScore(combined,
                low: "Rest your wrist on the surface — use your arm for stability",
                high: "Impressive fine motor control")
        )
    }

    // MARK: 4. Pressure Wave
    static func scorePressureWave(forceSamples: [CGFloat]) -> DrillScore {
        guard forceSamples.count > 5 else { return zeroScore("Pressure Stability") }

        let mean = forceSamples.reduce(0, +) / CGFloat(forceSamples.count)
        let variance = forceSamples.map { pow($0 - mean, 2) }.reduce(0, +) / CGFloat(forceSamples.count)
        let stdDev = sqrt(variance)

        let maxF = forceSamples.max() ?? 0
        let minF = forceSamples.min() ?? 0
        let range = maxF - minF

        let varianceScore = max(0, 1.0 - (stdDev / 0.15))
        let rangeScore = max(0, 1.0 - (range / 0.5))
        let levelScore: CGFloat = (mean > 0.15 && mean < 0.7) ? 1.0 : max(0, 1.0 - abs(mean - 0.35) * 2)

        let combined = (varianceScore * 0.5) + (rangeScore * 0.3) + (levelScore * 0.2)

        return DrillScore(
            primary: combined,
            label: "Pressure Stability",
            breakdown: [
                ScoreItem(label: "Variance Control", value: varianceScore),
                ScoreItem(label: "Spike Control",    value: rangeScore),
                ScoreItem(label: "Pressure Level",   value: levelScore)
            ],
            feedbackMessage: feedbackForScore(combined,
                low: "Relax your grip — press as lightly as you can while still drawing",
                high: "Excellent pressure control")
        )
    }

    // MARK: 5. Dot Hold
    static func scoreDotHold(touchPoints: [CGPoint], targetCenter: CGPoint) -> DrillScore {
        guard touchPoints.count > 5 else { return zeroScore("Stillness Score") }

        let distances = touchPoints.map { hypot($0.x - targetCenter.x, $0.y - targetCenter.y) }
        let avgDist = distances.reduce(0, +) / CGFloat(distances.count)

        let centroidX = touchPoints.map { $0.x }.reduce(0, +) / CGFloat(touchPoints.count)
        let centroidY = touchPoints.map { $0.y }.reduce(0, +) / CGFloat(touchPoints.count)
        let spreadDistances = touchPoints.map { hypot($0.x - centroidX, $0.y - centroidY) }
        let spreadRadius = spreadDistances.max() ?? 0

        let centeringScore = max(0, 1.0 - (avgDist / 25.0))
        let stabilityScore = max(0, 1.0 - (spreadRadius / 30.0))
        let contactScore = CGFloat(min(touchPoints.count, 200)) / 200.0

        let combined = (stabilityScore * 0.5) + (centeringScore * 0.3) + (contactScore * 0.2)

        return DrillScore(
            primary: combined,
            label: "Stillness Score",
            breakdown: [
                ScoreItem(label: "Tremor Spread",    value: stabilityScore),
                ScoreItem(label: "Target Centering", value: centeringScore),
                ScoreItem(label: "Hold Sustained",   value: contactScore)
            ],
            feedbackMessage: feedbackForScore(combined,
                low: "Rest your wrist flat — let the pencil be an extension of your arm",
                high: "Excellent stillness control")
        )
    }

    // MARK: - Legacy (kept for DrawView compatibility)
    static func scoreSlowCurve(stroke: PKStroke, canvasSize: CGSize) -> DrillScore { scoreTremorTrace(stroke: stroke) }
    static func scoreMicroCircles(stroke: PKStroke) -> DrillScore { scoreTremorTrace(stroke: stroke) }
    static func scorePressureControl(stroke: PKStroke) -> DrillScore {
        let path = stroke.path
        guard path.count > 3 else { return zeroScore("Pressure Stability") }
        let forces = (0..<path.count).map { path[$0].force }
        return scorePressureWave(forceSamples: forces)
    }
    static func scoreSteadyLine(stroke: PKStroke) -> DrillScore { scoreTremorTrace(stroke: stroke) }
    static func scoreBeatSync(beatTimestamps: [TimeInterval], beatTargets: [TimeInterval]) -> DrillScore {
        zeroScore("Timing Score")
    }
}

// MARK: - Helpers

extension MotorAnalysisEngine {

    static func zeroScore(_ label: String) -> DrillScore {
        DrillScore(primary: 0, label: label, breakdown: [], feedbackMessage: "Complete the exercise to get a reading")
    }

    static func feedbackForScore(_ score: CGFloat, low: String, high: String) -> String {
        if score < 0.35 { return low }
        if score > 0.72 { return high }
        return "Keep going — you're improving"
    }

    static func centroid(of points: [CGPoint]) -> CGPoint {
        let x = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let y = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        return CGPoint(x: x, y: y)
    }

    static func generateSCurvePoints(in size: CGSize, count: Int) -> [CGPoint] {
        guard count > 0 else { return [] }
        let padding: CGFloat = 60
        let rect = CGRect(x: padding, y: padding,
                          width: size.width - padding * 2,
                          height: size.height - padding * 2)
        return (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(count - 1)
            return cubicBezier(t: t,
                p0: CGPoint(x: rect.minX, y: rect.midY),
                p1: CGPoint(x: rect.midX * 0.6, y: rect.minY),
                p2: CGPoint(x: rect.midX * 1.4, y: rect.maxY),
                p3: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }

    static func cubicBezier(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u*u*u*p0.x + 3*u*u*t*p1.x + 3*u*t*t*p2.x + t*t*t*p3.x,
            y: u*u*u*p0.y + 3*u*u*t*p1.y + 3*u*t*t*p2.y + t*t*t*p3.y
        )
    }

    static func extractPoints(from path: PKStrokePath) -> [CGPoint] {
        (0..<path.count).map { path[$0].location }
    }

    static func computeTremorAmplitude(points: [CGPoint]) -> CGFloat {
        guard points.count > 5 else { return 0 }
        var total: CGFloat = 0; var samples = 0
        for i in 2..<(points.count - 2) {
            total += perpendicularDistance(point: points[i],
                lineStart: points[i - 2], lineEnd: points[i + 2])
            samples += 1
        }
        return samples > 0 ? total / CGFloat(samples) : 0
    }

    static func estimateTremorFrequency(points: [CGPoint]) -> CGFloat {
        guard points.count > 4 else { return 0 }
        var changes = 0
        for i in 2..<points.count {
            let dx1 = points[i-1].x - points[i-2].x
            let dx2 = points[i].x   - points[i-1].x
            if dx1 * dx2 < 0 { changes += 1 }
        }
        return CGFloat(changes)
    }

    static func computePressureVariance(path: PKStrokePath) -> CGFloat {
        let forces = (0..<path.count).map { path[$0].force }
        guard forces.count > 1 else { return 0 }
        let mean = forces.reduce(0, +) / CGFloat(forces.count)
        return forces.map { pow($0 - mean, 2) }.reduce(0, +) / CGFloat(forces.count)
    }

    static func computeVelocityVariance(path: PKStrokePath) -> CGFloat {
        guard path.count > 3 else { return 0 }
        var velocities: [CGFloat] = []
        for i in 1..<path.count {
            let p1 = path[i-1], p2 = path[i]
            let dt = CGFloat(p2.timeOffset - p1.timeOffset)
            guard dt > 0 else { continue }
            velocities.append(hypot(p2.location.x - p1.location.x,
                                    p2.location.y - p1.location.y) / dt)
        }
        guard velocities.count > 1 else { return 0 }
        let mean = velocities.reduce(0, +) / CGFloat(velocities.count)
        return velocities.map { pow($0 - mean, 2) }.reduce(0, +) / CGFloat(velocities.count)
    }

    static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lenSq = dx*dx + dy*dy
        guard lenSq > 0 else { return hypot(point.x - lineStart.x, point.y - lineStart.y) }
        let t = max(0, min(1, ((point.x - lineStart.x)*dx + (point.y - lineStart.y)*dy) / lenSq))
        return hypot(point.x - (lineStart.x + t*dx), point.y - (lineStart.y + t*dy))
    }
}
