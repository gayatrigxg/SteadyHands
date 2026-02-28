import SwiftUI
import PencilKit

struct SteadyCanvas: UIViewRepresentable {

    @Binding var canvasView: PKCanvasView

    var smoothingEnabled: Bool
    var shapeRecognitionEnabled: Bool
    var snapManager: ShapeSnapManager
    var assistLevel: CGFloat
    var showGhostOverlay: Bool
    var showToolPicker: Bool

    var pressureCompensation: Bool = false
    var velocityDamping: Bool = false
    var jitterThreshold: CGFloat = 1.5
    var strokeStabilization: Bool = false
    var stabilizationAmount: CGFloat = 0.4

    var onStrokeAdded: (() -> Void)?
    var clearTrigger: Int = 0

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.delegate = context.coordinator
        context.coordinator.configure(
            smoothingEnabled: smoothingEnabled,
            shapeRecognitionEnabled: shapeRecognitionEnabled,
            snapManager: snapManager,
            assistLevel: assistLevel,
            showGhostOverlay: showGhostOverlay,
            pressureCompensation: pressureCompensation,
            velocityDamping: velocityDamping,
            jitterThreshold: jitterThreshold,
            strokeStabilization: strokeStabilization,
            stabilizationAmount: stabilizationAmount,
            onStrokeAdded: onStrokeAdded
        )
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        context.coordinator.configure(
            smoothingEnabled: smoothingEnabled,
            shapeRecognitionEnabled: shapeRecognitionEnabled,
            snapManager: snapManager,
            assistLevel: assistLevel,
            showGhostOverlay: showGhostOverlay,
            pressureCompensation: pressureCompensation,
            velocityDamping: velocityDamping,
            jitterThreshold: jitterThreshold,
            strokeStabilization: strokeStabilization,
            stabilizationAmount: stabilizationAmount,
            onStrokeAdded: onStrokeAdded
        )

        if context.coordinator.lastClearTrigger != clearTrigger {
            context.coordinator.lastClearTrigger = clearTrigger

            // Step 1: flag that we are clearing — delegate will ignore this change
            context.coordinator.isClearing = true

            // Step 2: detach delegate so PKCanvasView doesn't fire canvasViewDrawingDidChange
            uiView.delegate = nil

            // Step 3: wipe the drawing
            uiView.drawing = PKDrawing()

            // Step 4: reset coordinator state
            context.coordinator.isProcessing = false
            context.coordinator.lastKnownStrokeCount = 0

            // Step 5: re-attach delegate and clear flag
            uiView.delegate = context.coordinator
            context.coordinator.isClearing = false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate {

        var smoothingEnabled = true
        var shapeRecognitionEnabled = false
        var assistLevel: CGFloat = 0.5
        var showGhostOverlay = false
        var snapManager: ShapeSnapManager?
        var pressureCompensation = false
        var velocityDamping = false
        var jitterThreshold: CGFloat = 1.5
        var strokeStabilization = false
        var stabilizationAmount: CGFloat = 0.4
        var onStrokeAdded: (() -> Void)?

        var lastClearTrigger: Int = 0
        var isClearing = false
        var isProcessing = false
        var lastKnownStrokeCount = 0

        func configure(
            smoothingEnabled: Bool,
            shapeRecognitionEnabled: Bool,
            snapManager: ShapeSnapManager,
            assistLevel: CGFloat,
            showGhostOverlay: Bool,
            pressureCompensation: Bool,
            velocityDamping: Bool,
            jitterThreshold: CGFloat,
            strokeStabilization: Bool,
            stabilizationAmount: CGFloat,
            onStrokeAdded: (() -> Void)?
        ) {
            self.smoothingEnabled = smoothingEnabled
            self.shapeRecognitionEnabled = shapeRecognitionEnabled
            self.snapManager = snapManager
            self.assistLevel = assistLevel
            self.showGhostOverlay = showGhostOverlay
            self.pressureCompensation = pressureCompensation
            self.velocityDamping = velocityDamping
            self.jitterThreshold = jitterThreshold
            self.strokeStabilization = strokeStabilization
            self.stabilizationAmount = stabilizationAmount
            self.onStrokeAdded = onStrokeAdded
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Hard block — ignore ALL delegate calls during a clear
            guard !isClearing else { return }
            guard !isProcessing else { return }

            let strokes = canvasView.drawing.strokes
            guard !strokes.isEmpty else {
                lastKnownStrokeCount = 0
                return
            }

            let isNewStroke = strokes.count > lastKnownStrokeCount
            lastKnownStrokeCount = strokes.count

            isProcessing = true

            var mutableStrokes = Array(strokes)
            var lastStroke = mutableStrokes[mutableStrokes.count - 1]

            if jitterThreshold > 0 {
                lastStroke = applyJitterReduction(to: lastStroke)
            }
            if pressureCompensation {
                lastStroke = applyPressureCompensation(to: lastStroke)
            }
            if velocityDamping {
                lastStroke = applyVelocityDamping(to: lastStroke)
            }
            if strokeStabilization {
                lastStroke = applyStabilization(to: lastStroke)
            }
            if smoothingEnabled {
                lastStroke = applySmoothing(to: lastStroke)
            }

            mutableStrokes[mutableStrokes.count - 1] = lastStroke
            canvasView.drawing = PKDrawing(strokes: mutableStrokes)

            if let snap = snapManager, shapeRecognitionEnabled {
                snap.evaluate(
                    stroke: canvasView.drawing.strokes.last!,
                    atIndex: canvasView.drawing.strokes.count - 1,
                    enabled: true
                )
            }

            if isNewStroke {
                DispatchQueue.main.async { [weak self] in
                    self?.onStrokeAdded?()
                }
            }

            isProcessing = false
        }

        // MARK: - Processing Pipeline

        private func applyJitterReduction(to stroke: PKStroke) -> PKStroke {
            let path = stroke.path
            guard path.count > 2 else { return stroke }
            var filtered: [PKStrokePoint] = [path[0]]
            for i in 1..<path.count {
                let prev = filtered.last!.location
                let curr = path[i].location
                if hypot(curr.x - prev.x, curr.y - prev.y) >= jitterThreshold {
                    filtered.append(path[i])
                }
            }
            guard filtered.count > 1 else { return stroke }
            return PKStroke(ink: stroke.ink,
                            path: PKStrokePath(controlPoints: filtered, creationDate: path.creationDate))
        }

        private func applyPressureCompensation(to stroke: PKStroke) -> PKStroke {
            let path = stroke.path
            guard path.count > 1 else { return stroke }
            let forces = (0..<path.count).map { path[$0].force }
            let mean = forces.reduce(0, +) / CGFloat(forces.count)
            let target: CGFloat = 0.5
            let newPoints: [PKStrokePoint] = (0..<path.count).map { i in
                let p = path[i]
                let blended = p.force + (target - mean) * assistLevel * 0.6
                return PKStrokePoint(location: p.location, timeOffset: p.timeOffset,
                                     size: p.size, opacity: p.opacity,
                                     force: max(0.1, min(1.0, blended)),
                                     azimuth: p.azimuth, altitude: p.altitude)
            }
            return PKStroke(ink: stroke.ink,
                            path: PKStrokePath(controlPoints: newPoints, creationDate: path.creationDate))
        }

        private func applyVelocityDamping(to stroke: PKStroke) -> PKStroke {
            let path = stroke.path
            guard path.count > 3 else { return stroke }
            let maxDelta: CGFloat = max(8, 40 - (assistLevel * 30))
            var newPoints: [PKStrokePoint] = [path[0]]
            for i in 1..<path.count {
                let prev = newPoints.last!.location
                let curr = path[i].location
                let dist = hypot(curr.x - prev.x, curr.y - prev.y)
                if dist > maxDelta {
                    let ratio = maxDelta / dist
                    let clamped = CGPoint(x: prev.x + (curr.x - prev.x) * ratio,
                                         y: prev.y + (curr.y - prev.y) * ratio)
                    let p = path[i]
                    newPoints.append(PKStrokePoint(location: clamped, timeOffset: p.timeOffset,
                                                   size: p.size, opacity: p.opacity, force: p.force,
                                                   azimuth: p.azimuth, altitude: p.altitude))
                } else {
                    newPoints.append(path[i])
                }
            }
            return PKStroke(ink: stroke.ink,
                            path: PKStrokePath(controlPoints: newPoints, creationDate: path.creationDate))
        }

        private func applyStabilization(to stroke: PKStroke) -> PKStroke {
            let path = stroke.path
            guard path.count > 2 else { return stroke }
            let alpha = max(0.15, 1.0 - stabilizationAmount)
            var newPoints: [PKStrokePoint] = [path[0]]
            for i in 1..<path.count {
                let prev = newPoints[i - 1].location
                let curr = path[i].location
                let smoothed = CGPoint(x: prev.x + alpha * (curr.x - prev.x),
                                       y: prev.y + alpha * (curr.y - prev.y))
                let p = path[i]
                newPoints.append(PKStrokePoint(location: smoothed, timeOffset: p.timeOffset,
                                               size: p.size, opacity: p.opacity, force: p.force,
                                               azimuth: p.azimuth, altitude: p.altitude))
            }
            return PKStroke(ink: stroke.ink,
                            path: PKStrokePath(controlPoints: newPoints, creationDate: path.creationDate))
        }

        private func applySmoothing(to stroke: PKStroke) -> PKStroke {
            let path = stroke.path
            guard path.count > 2 else { return stroke }
            let windowSize = max(1, Int(assistLevel * 6))
            var newPoints: [PKStrokePoint] = []
            for i in 0..<path.count {
                let p = path[i]
                let start = max(0, i - windowSize)
                let end = min(path.count - 1, i + windowSize)
                var sumX: CGFloat = 0, sumY: CGFloat = 0, count = 0
                for j in start...end {
                    sumX += path[j].location.x
                    sumY += path[j].location.y
                    count += 1
                }
                newPoints.append(PKStrokePoint(
                    location: CGPoint(x: sumX / CGFloat(count), y: sumY / CGFloat(count)),
                    timeOffset: p.timeOffset, size: p.size, opacity: p.opacity,
                    force: p.force, azimuth: p.azimuth, altitude: p.altitude))
            }
            return PKStroke(ink: stroke.ink,
                            path: PKStrokePath(controlPoints: newPoints, creationDate: path.creationDate))
        }
    }
}
