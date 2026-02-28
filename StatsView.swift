import SwiftUI

// MARK: - StatsView

struct StatsView: View {

    @EnvironmentObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Your hand control journey")
                        .font(.system(size: 19))
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Onboarding nudge — only shown until first session
                if settings.totalSessionCount == 0 {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.brandPrimary.opacity(0.12))
                                .frame(width: 48, height: 48)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.brandPrimary)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start a drill to see your progress")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Text("Head to the Train tab and complete any session. Your tremor insights will fill in here.")
                                .font(.system(size: 15))
                                .foregroundColor(.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(3)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.brandPrimary.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.brandPrimary.opacity(0.18), lineWidth: 1.5)
                    )
                    .cornerRadius(18)
                }

                summaryRow
                weeklyStreakCard
                tremorInsightsSection
                drillBreakdownSection
                scoreTrendSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        HStack(spacing: 12) {
            SummaryTile(
                value: "\(settings.totalSessionCount)",
                label: "Sessions",
                icon: "checkmark.circle.fill",
                color: .brandPrimary
            )
            SummaryTile(
                value: "\(completedDrillTypes)/5",
                label: "Drills Tried",
                icon: "scope",
                color: .metricBlue
            )
            SummaryTile(
                value: currentStreak > 0 ? "\(currentStreak)d" : "—",
                label: "Streak",
                icon: "flame.fill",
                color: currentStreak > 0 ? .metricOrange : .textSecondary
            )
        }
    }

    // MARK: - Weekly Streak

    private var weeklyStreakCard: some View {
        let calendar = Calendar.current
        let today = Date()
        let weekDays = (0..<7).map { calendar.date(byAdding: .day, value: -(6 - $0), to: today)! }
        let practicedDates = Set(settings.drillSessions.map { calendar.startOfDay(for: $0.date) })
        let practiced = practicedDates.intersection(weekDays.map { calendar.startOfDay(for: $0) }).count
        let dayLabels = ["M","T","W","T","F","S","S"]
        let labelMap: [Int:Int] = [2:0,3:1,4:2,5:3,6:4,7:5,1:6]

        return VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(.textPrimary)

            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { i in
                    let date = weekDays[i]
                    let wasPracticed = practicedDates.contains(calendar.startOfDay(for: date))
                    let isToday = calendar.isDateInToday(date)
                    let weekday = calendar.component(.weekday, from: date)
                    let labelIndex = labelMap[weekday] ?? i

                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(wasPracticed ? Color.brandPrimary : Color(UIColor.systemFill))
                                .frame(width: 44, height: 44)
                            if wasPracticed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            if isToday && !wasPracticed {
                                Circle()
                                    .stroke(Color.brandPrimary.opacity(0.5), lineWidth: 2)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        Text(dayLabels[labelIndex])
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isToday ? .brandPrimary : .textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Text(practiced == 0
                 ? "No sessions yet this week. Consistency is the therapy."
                 : "Practiced \(practiced) of 7 days this week. Keep going.")
                .font(.system(size: 16))
                .foregroundColor(.textSecondary)
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(18)
    }

    // MARK: - Tremor Insights

    private var tremorInsightsSection: some View {
        let recent = settings.recentDrillSessions
        let allScores = recent.map(\.score)
        let avgScore  = allScores.isEmpty ? 0.0 : allScores.reduce(0,+) / CGFloat(allScores.count)
        let bestScore = allScores.max() ?? 0
        let trend     = scoreTrend(from: recent)
        let trendReady = recent.count >= 4

        let completedDrills = DrillType.allCases.filter { settings.completionCount(for: $0) > 0 }
        let bestDrill  = completedDrills.max { (settings.bestScore(for: $0) ?? 0) < (settings.bestScore(for: $1) ?? 0) }
        let worstDrill = completedDrills.min { (settings.bestScore(for: $0) ?? 0) < (settings.bestScore(for: $1) ?? 0) }
        let pressureScore = settings.bestScore(for: .pressureWave)
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let recentCount = settings.drillSessions.filter { $0.date >= sevenDaysAgo }.count

        // Build card data array so we can lay them in a 2-col grid
        var cards: [InsightCardData] = [
            InsightCardData(
                icon: "waveform.path.ecg",
                iconColor: scoreColor(avgScore),
                label: "Avg Control",
                note: "all drills",
                value: recent.isEmpty ? "—" : "\(Int(avgScore * 100))%",
                valueColor: scoreColor(avgScore)
            ),
            InsightCardData(
                icon: "star.fill",
                iconColor: .brandPrimary,
                label: "Peak Session",
                note: "best ever",
                value: recent.isEmpty ? "—" : "\(Int(bestScore * 100))%",
                valueColor: .brandPrimary
            ),
            InsightCardData(
                icon: trendReady ? (trend >= 0 ? "arrow.up.right" : "arrow.down.right") : "minus",
                iconColor: trendReady ? (trend >= 0 ? .metricGreen : .metricOrange) : .textSecondary,
                label: "Trend",
                note: trendReady ? (trend >= 0 ? "improving" : "keep going") : "4+ sessions",
                value: trendReady ? (trend >= 0 ? "+\(trend)%" : "\(trend)%") : "—",
                valueColor: trendReady ? (trend >= 0 ? .metricGreen : .metricOrange) : .textSecondary
            ),
            InsightCardData(
                icon: "hand.point.down.fill",
                iconColor: pressureScore != nil ? scoreColor(pressureScore!) : .textSecondary,
                label: "Grip Control",
                note: pressureScore != nil ? "pressure wave" : "try it",
                value: pressureScore != nil ? "\(Int(pressureScore! * 100))%" : "—",
                valueColor: pressureScore != nil ? scoreColor(pressureScore!) : .textSecondary
            ),
        ]

        if let best = bestDrill, let worst = worstDrill, best.id != worst.id {
            cards.append(InsightCardData(
                icon: "hand.thumbsup.fill",
                iconColor: best.accentColor,
                label: "Strongest",
                note: best.title,
                value: "\(Int((settings.bestScore(for: best) ?? 0) * 100))%",
                valueColor: best.accentColor
            ))
            cards.append(InsightCardData(
                icon: "scope",
                iconColor: worst.accentColor,
                label: "Focus Area",
                note: worst.title,
                value: "\(Int((settings.bestScore(for: worst) ?? 0) * 100))%",
                valueColor: worst.accentColor
            ))
        }

        // Pair cards into rows of 2
        let rows = stride(from: 0, to: cards.count, by: 2).map { i -> [InsightCardData] in
            i + 1 < cards.count ? [cards[i], cards[i+1]] : [cards[i]]
        }

        return VStack(alignment: .leading, spacing: 14) {
            Text("Tremor Insights")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.textPrimary)

            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 12) {
                    ForEach(rows[rowIndex].indices, id: \.self) { colIndex in
                        InsightSquareCard(data: rows[rowIndex][colIndex])
                    }
                    // If odd card, add invisible spacer to keep grid
                    if rows[rowIndex].count == 1 {
                        Color.clear
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            ConsistencyCard(sessionCount: recentCount)
        }
    }

    // MARK: - Drill Breakdown

    private var drillBreakdownSection: some View {
        // Show all drills always — 0% until completed
        let allDrills = DrillType.allCases

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("By Drill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Best score per exercise")
                        .font(.system(size: 15))
                        .foregroundColor(.textSecondary)
                }

                VStack(spacing: 0) {
                    ForEach(Array(allDrills.enumerated()), id: \.element.id) { index, drill in
                        DrillProgressRow(drill: drill)
                        if index < allDrills.count - 1 {
                            Divider().padding(.leading, 76)
                        }
                    }
                }
                .background(Color.cardBackground)
                .cornerRadius(18)
            }
        )
    }

    // MARK: - Score Trend (per-drill selector)

    @State private var selectedTrendDrill: DrillType = DrillType.allCases.first!

    private var scoreTrendSection: some View {
        let drillsWithData = DrillType.allCases.filter { drill in settings.drillSessions.filter { s in s.drillType == drill }.count >= 2 }

        // Show placeholder card when no trend data yet
        if drillsWithData.isEmpty {
            return AnyView(
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Score Trend")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text("How you're improving on each drill over time")
                            .font(.system(size: 15))
                            .foregroundColor(.textSecondary)
                    }
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 36))
                            .foregroundColor(.brandPrimary.opacity(0.3))
                        Text("Complete 2+ sessions on any drill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("Your progress chart will appear here")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(Color.cardBackground)
                    .cornerRadius(18)
                }
            )
        }
        let _ = drillsWithData // suppress unused warning

        // If selectedTrendDrill has no data, pick first available
        let drill = drillsWithData.contains(selectedTrendDrill) ? selectedTrendDrill : drillsWithData[0]
        let sessions = settings.drillSessions
            .filter { $0.drillType == drill }
            .sorted { $0.date < $1.date }

        let scores = sessions.map { $0.score }
        let latest = scores.last ?? 0
        let first  = scores.first ?? 0
        let delta  = Int((latest - first) * 100)

        return AnyView(
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score Trend")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("How you're improving on each drill over time")
                        .font(.system(size: 15))
                        .foregroundColor(.textSecondary)
                }

                // Drill picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(drillsWithData) { d in
                            Button {
                                selectedTrendDrill = d
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: d.systemIcon)
                                        .font(.system(size: 13, weight: .medium))
                                    Text(d.title)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(drill.id == d.id ? .white : .textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(drill.id == d.id ? drill.accentColor : Color(UIColor.systemFill))
                                .cornerRadius(20)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                }

                // Chart card
                VStack(spacing: 16) {

                    // Delta summary
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(drill.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Text("\(sessions.count) session\(sessions.count == 1 ? "" : "s") recorded")
                                .font(.system(size: 14))
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                        if sessions.count >= 2 {
                            HStack(spacing: 4) {
                                Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 13, weight: .bold))
                                Text(delta >= 0 ? "+\(delta)% since first" : "\(delta)% since first")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(delta >= 0 ? .metricGreen : .metricOrange)
                        }
                    }

                    // Chart with Y-axis
                    HStack(alignment: .top, spacing: 8) {
                        // Y labels
                        VStack(alignment: .trailing, spacing: 0) {
                            Text("100%").font(.system(size: 12)).foregroundColor(.textSecondary)
                            Spacer()
                            Text("50%").font(.system(size: 12)).foregroundColor(.textSecondary)
                            Spacer()
                            Text("0%").font(.system(size: 12)).foregroundColor(.textSecondary)
                        }
                        .frame(width: 38, height: 150)

                        // Canvas
                        Canvas { context, size in
                            guard scores.count > 1 else { return }
                            let stepX = size.width / CGFloat(scores.count - 1)
                            let pad: CGFloat = 10
                            let accentUI = UIColor(drill.accentColor)

                            func pt(_ i: Int) -> CGPoint {
                                CGPoint(
                                    x: CGFloat(i) * stepX,
                                    y: pad + (1 - scores[i]) * (size.height - pad * 2)
                                )
                            }

                            // Grid lines
                            for frac: CGFloat in [0, 0.5, 1.0] {
                                let y = pad + (1 - frac) * (size.height - pad * 2)
                                var g = Path()
                                g.move(to: CGPoint(x: 0, y: y))
                                g.addLine(to: CGPoint(x: size.width, y: y))
                                context.stroke(g, with: .color(Color(UIColor.systemFill)),
                                               style: StrokeStyle(lineWidth: 1))
                            }

                            // Fill
                            var fill = Path()
                            fill.move(to: CGPoint(x: 0, y: size.height))
                            fill.addLine(to: pt(0))
                            for i in 1..<scores.count { fill.addLine(to: pt(i)) }
                            fill.addLine(to: CGPoint(x: CGFloat(scores.count - 1) * stepX, y: size.height))
                            fill.closeSubpath()
                            context.fill(fill, with: .color(drill.accentColor.opacity(0.10)))

                            // Line
                            var line = Path()
                            line.move(to: pt(0))
                            for i in 1..<scores.count { line.addLine(to: pt(i)) }
                            context.stroke(line, with: .color(drill.accentColor),
                                           style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                            // Dots + score labels
                            for i in 0..<scores.count {
                                let p = pt(i)
                                context.fill(Path(ellipseIn: CGRect(x: p.x-5, y: p.y-5, width: 10, height: 10)),
                                             with: .color(drill.accentColor))
                                context.fill(Path(ellipseIn: CGRect(x: p.x-2.5, y: p.y-2.5, width: 5, height: 5)),
                                             with: .color(.white))

                                // Score label above dot
                                let label = "\(Int(scores[i] * 100))%"
                                context.draw(
                                    Text(label)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(drill.accentColor),
                                    at: CGPoint(x: p.x, y: p.y - 14),
                                    anchor: .center
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                    }

                    // X axis — session dates
                    HStack(spacing: 0) {
                        Spacer().frame(width: 46)
                        ForEach(sessions) { session in
                            Text(session.drillType.title.prefix(3) + ".")
                                .font(.system(size: 11))
                                .foregroundColor(.textSecondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(20)
                .background(Color.cardBackground)
                .cornerRadius(18)
            }
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 40) {
            Spacer(minLength: 60)
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.brandPrimary.opacity(0.10))
                        .frame(width: 100, height: 100)
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.brandPrimary)
                }
                VStack(spacing: 10) {
                    Text("Start your first session")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text("Complete any drill on the Train tab.\nYour tremor insights and progress will appear here.")
                        .font(.system(size: 17))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                }
            }
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var completedDrillTypes: Int {
        DrillType.allCases.filter { settings.completionCount(for: $0) > 0 }.count
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var check = Date()
        let practiced = Set(settings.drillSessions.map { calendar.startOfDay(for: $0.date) })
        while practiced.contains(calendar.startOfDay(for: check)) {
            streak += 1
            check = calendar.date(byAdding: .day, value: -1, to: check)!
        }
        return streak
    }

    private func scoreTrend(from sessions: [DrillSession]) -> Int {
        guard sessions.count >= 4 else { return 0 }
        let half = sessions.count / 2
        let first = sessions.prefix(half).map(\.score).reduce(0, +) / CGFloat(half)
        let last  = sessions.suffix(half).map(\.score).reduce(0, +) / CGFloat(half)
        return Int((last - first) * 100)
    }

    private func scoreColor(_ v: CGFloat) -> Color {
        v > 0.72 ? .metricGreen : v > 0.45 ? .brandPrimary : .metricOrange
    }
}

// MARK: - Summary Tile

struct SummaryTile: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.textPrimary)
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.cardBackground)
        .cornerRadius(18)
    }
}

// MARK: - Insight Square Card

struct InsightCardData {
    let icon: String
    let iconColor: Color
    let label: String
    let note: String
    let value: String
    let valueColor: Color
}

struct InsightSquareCard: View {
    let data: InsightCardData

    var body: some View {
        VStack(spacing: 0) {
            // Icon — centered, medium, no background
            Image(systemName: data.icon)
                .font(.system(size: 40, weight: .medium))
                .foregroundColor(data.iconColor)
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 14)

            // Thin divider line under icon
            Rectangle()
                .fill(data.iconColor.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, 20)

            // Label + value below
            VStack(spacing: 6) {
                Text(data.value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(data.valueColor)
                Text(data.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(data.note)
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(18)
    }
}

// MARK: - Consistency Card

struct ConsistencyCard: View {
    let sessionCount: Int

    private var message: String {
        switch sessionCount {
        case 0: return "No sessions this week. Even 1 drill a day builds lasting control."
        case 1...2: return "Good start. Aim for 4–5 sessions this week — rhythm reduces tremor."
        case 3...4: return "Solid consistency. Research shows regular training measurably reduces tremor amplitude."
        default: return "Excellent week. High-frequency practice is the most effective tremor therapy."
        }
    }

    private var iconName: String {
        sessionCount >= 5 ? "flame.fill" : sessionCount >= 3 ? "bolt.fill" : "calendar"
    }

    private var iconColor: Color {
        sessionCount >= 5 ? .metricOrange : sessionCount >= 3 ? .brandPrimary : .textSecondary
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 26))
                .foregroundColor(iconColor)
            VStack(alignment: .leading, spacing: 4) {
                Text("This Week: \(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(18)
    }
}

// MARK: - Drill Progress Row

struct DrillProgressRow: View {
    let drill: DrillType
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        let count = settings.completionCount(for: drill)
        let best  = settings.bestScore(for: drill) ?? 0

        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(drill.accentColor.opacity(0.12))
                    .frame(width: 54, height: 54)
                Image(systemName: drill.systemIcon)
                    .font(.system(size: 22))
                    .foregroundColor(drill.accentColor)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(drill.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Spacer()
                    Text("\(Int(best * 100))%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(drill.accentColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(UIColor.systemFill)).frame(height: 7)
                        Capsule()
                            .fill(drill.accentColor)
                            .frame(width: geo.size.width * best, height: 7)
                            .animation(.spring(response: 0.8, dampingFraction: 0.75), value: best)
                    }
                }
                .frame(height: 7)

                Text(count == 0 ? "Not started yet" : "\(count) session\(count == 1 ? "" : "s") completed")
                    .font(.system(size: 13))
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

// MARK: - Empty State Hint (kept for compatibility)
struct EmptyStateHintCard: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(.brandPrimary).frame(width: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.textPrimary)
                Text(subtitle).font(.system(size: 14)).foregroundColor(.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(18).frame(maxWidth: .infinity).background(Color.cardBackground).cornerRadius(16)
    }
}
