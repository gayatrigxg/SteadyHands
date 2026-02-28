import Foundation
import SwiftUI

enum DrillType: CaseIterable, Identifiable {

    case tremorTrace       // Freehand line → EKG deviation analysis
    case corridorPath      // Trace curved path staying inside corridor
    case shrinkingTarget   // Hold pencil inside shrinking circle
    case pressureWave      // Live force waveform, variance scoring
    case dotHold           // Hold still 10s → scatter plot tremor signature

    var id: String { title }

    // MARK: - Display

    var title: String {
        switch self {
        case .tremorTrace:     return "Tremor Trace"
        case .corridorPath:    return "Corridor Path"
        case .shrinkingTarget: return "Shrinking Target"
        case .pressureWave:    return "Pressure Wave"
        case .dotHold:         return "Dot Hold"
        }
    }

    var subtitle: String {
        switch self {
        case .tremorTrace:     return "Draw a line, see your signature"
        case .corridorPath:    return "Stay inside the winding path"
        case .shrinkingTarget: return "Hold steady inside the circle"
        case .pressureWave:    return "Keep your pressure flat"
        case .dotHold:         return "Stay as still as possible"
        }
    }

    var motorSkillLabel: String {
        switch self {
        case .tremorTrace:     return "Baseline Measurement"
        case .corridorPath:    return "Path Tracking"
        case .shrinkingTarget: return "Adaptive Stabilization"
        case .pressureWave:    return "Grip Modulation"
        case .dotHold:         return "Tremor Signature"
        }
    }

    var whyItHelps: String {
        switch self {
        case .tremorTrace:
            return "Drawing this line shows your tremor's exact pattern. Over time you'll see it shrink — that's real, measurable progress your brain is making."
        case .corridorPath:
            return "Staying inside the path trains your hand to self-correct mid-stroke. After a few sessions, your lines in Draw mode will drift less and feel more intentional."
        case .shrinkingTarget:
            return "Each session you'll hold longer before the circle gets too small. That growing hold time is your motor control improving — it directly translates to finer detail in your drawings."
        case .pressureWave:
            return "Most tremor is made worse by grip tension. This exercise teaches your hand to press lightly and consistently — users notice smoother, more even lines within a week of daily practice."
        case .dotHold:
            return "Holding still is harder than it sounds — and that's the point. Each session your scatter pattern gets tighter. That tighter cluster is your nervous system learning to suppress tremor at rest."
        }
    }

    var instructionText: String {
        switch self {
        case .tremorTrace:
            return "Draw one slow, straight line left to right. Don't rush. Lift your pencil when done."
        case .corridorPath:
            return "Trace from the green dot to the red dot, staying inside the corridor. Go slow — accuracy beats speed."
        case .shrinkingTarget:
            return "Place your pencil inside the circle and hold steady. The longer you hold, the smaller it gets."
        case .pressureWave:
            return "Press and hold anywhere on the canvas. Try to keep the live line inside the green band."
        case .dotHold:
            return "Place your pencil tip on the dot. Hold as still as you can for 10 seconds."
        }
    }

    /// Expanded tips shown in the "What to do" card — focused on body position and technique.
    var techniqueText: String {
        switch self {
        case .tremorTrace:
            return "Rest your wrist or forearm on the surface — don't draw from your fingers alone. Let your whole arm guide the stroke. Breathe out slowly as you draw. There's no wrong result here, only data."
        case .corridorPath:
            return "Keep your elbow on the table for stability. Move from your shoulder, not your wrist. If you drift outside the corridor, don't panic — just gently steer back. Smooth and slow always beats fast and shaky."
        case .shrinkingTarget:
            return "Rest your wrist flat on the screen edge. Focus your gaze on the center of the circle, not on your hand. Relax your grip — a light touch is steadier than a tight one. Breathe normally and let your arm go still."
        case .pressureWave:
            return "Hold the pencil or your finger loosely, like a paintbrush. Press just enough to register contact. Your goal is a flat, even line — not hard, not soft. If you feel your hand tensing, take a breath and soften your grip."
        case .dotHold:
            return "Set your elbow down first, then your wrist, then the pencil tip — like stacking supports. Don't stare at your hand; look slightly past it. Micro-movements are normal. Stay relaxed — fighting the tremor makes it worse."
        }
    }

    var phaseLabel: String {
        switch self {
        case .tremorTrace:     return "Phase 1 — Motion"
        case .corridorPath:    return "Phase 2 — Tracking"
        case .shrinkingTarget: return "Phase 3 — Stabilize"
        case .pressureWave:    return "Phase 4 — Control Force"
        case .dotHold:         return "Phase 5 — Observe Tremor"
        }
    }

    var durationLabel: String { "~10 seconds" }
    var sessionDuration: Double { 10.0 }

    var systemIcon: String {
        switch self {
        case .tremorTrace:     return "waveform.path.ecg"
        case .corridorPath:    return "point.topleft.down.curvedto.point.bottomright.up"
        case .shrinkingTarget: return "scope"
        case .pressureWave:    return "chart.line.downtrend.xyaxis"
        case .dotHold:         return "record.circle"
        }
    }

    var accentColor: Color {
        switch self {
        case .tremorTrace:     return Color.brandPrimary
        case .corridorPath:    return Color(red: 0.20, green: 0.78, blue: 0.68)
        case .shrinkingTarget: return Color(red: 0.25, green: 0.55, blue: 0.95)
        case .pressureWave:    return Color(red: 0.95, green: 0.60, blue: 0.20)
        case .dotHold:         return Color(red: 0.75, green: 0.35, blue: 0.90)
        }
    }

    var assistLevel: CGFloat { 0.0 }

    var requiresPencilForce: Bool { false }

    var usesHaptics: Bool { false }
}
