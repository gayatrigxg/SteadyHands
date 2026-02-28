import Foundation

// MARK: - DrawingSession
// Stores analytics from a free-draw session in ExerciseSessionView / DrawView.

struct DrawingSession: Identifiable {
    let id: UUID
    let date: Date
    let strokeCount: Int
    let avgStability: Int       // 0–100
    let avgPressure: Int        // 0–100
    let avgRhythm: Int          // 0–100
    let avgTremorStrength: Float
    let avgDominantFrequency: Float
    let avgAssistUsed: Float

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        strokeCount: Int,
        avgStability: Int,
        avgPressure: Int,
        avgRhythm: Int,
        avgTremorStrength: Float = 0,
        avgDominantFrequency: Float = 0,
        avgAssistUsed: Float = 0
    ) {
        self.id = id
        self.date = date
        self.strokeCount = strokeCount
        self.avgStability = avgStability
        self.avgPressure = avgPressure
        self.avgRhythm = avgRhythm
        self.avgTremorStrength = avgTremorStrength
        self.avgDominantFrequency = avgDominantFrequency
        self.avgAssistUsed = avgAssistUsed
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}

// MARK: - DrillSession
// Stores the result of a single DrillSessionView run (one of the 5 drill types).

struct DrillSession: Identifiable {
    let id: UUID
    let date: Date
    let drillType: DrillType
    let score: CGFloat                         // 0.0–1.0 primary score
    let breakdown: [(label: String, value: CGFloat)]
    let feedbackMessage: String
    let durationSeconds: Int

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        drillType: DrillType,
        score: CGFloat,
        breakdown: [(label: String, value: CGFloat)] = [],
        feedbackMessage: String = "",
        durationSeconds: Int = 0
    ) {
        self.id = id
        self.date = date
        self.drillType = drillType
        self.score = score
        self.breakdown = breakdown
        self.feedbackMessage = feedbackMessage
        self.durationSeconds = durationSeconds
    }

    /// Maps the drill score (0–1) to a 0–100 stability-style integer for
    /// display alongside DrawingSession stability scores.
    var asAvgStability: Int { Int(score * 100) }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
