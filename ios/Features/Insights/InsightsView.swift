import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query(sort: \HabitCheckIn.date) private var checkIns: [HabitCheckIn]
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \Milestone.createdAt, order: .reverse) private var milestones: [Milestone]
    @Query(sort: \XPBonus.createdAt, order: .reverse) private var bonuses: [XPBonus]
    @Query(sort: \FocusSession.startDate, order: .reverse) private var focusSessions: [FocusSession]

    var body: some View {
        ZStack {
            InsightsBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    InsightsHeader()

                    if logs.isEmpty {
                        EmptyInsightsCard()
                    } else {
                        SummaryCard(
                            activeDays: activeDaysLast30,
                            focusMinutes: focusMinutesLast30,
                            averageIntensity: averageIntensityLast30,
                            bestStreak: bestStreak
                        )

                        XPHighlightCard(
                            totalXP: totalXP,
                            last30XP: xpLast30,
                            progress: xpProgress
                        )

                        FocusSummaryCard(
                            totalMinutes: focusMinutesLast30,
                            activeDays: focusActiveDaysLast30,
                            currentStreak: focusCurrentStreak,
                            bestStreak: focusBestStreak
                        )

                        TrendCard(
                            title: "Consistency trend",
                            subtitle: "Active days per week",
                            chart: consistencyChart
                        )

                        TrendCard(
                            title: "Intensity trend",
                            subtitle: "Average intensity per week",
                            chart: intensityChart
                        )

                        TrendCard(
                            title: "Focus trend",
                            subtitle: "Minutes per week",
                            chart: focusChart
                        )

                        TrendCard(
                            title: "XP trend",
                            subtitle: "XP earned per week",
                            chart: xpChart
                        )

                        HabitHighlightCard(
                            habitTitle: topHabit?.title,
                            checkIns: topHabit?.checkIns ?? 0
                        )

                        BestDayCard(bestLog: bestLog)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var recentLogs: [DailyLog] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -29, to: Date().startOfDay) ?? Date().startOfDay
        return logs.filter { $0.date >= startDate }
    }

    private var activeDaysLast30: Int {
        recentLogs.filter { $0.intensity > 0.05 }.count
    }

    private var focusMinutesLast30: Int {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -29, to: Date().startOfDay) ?? Date().startOfDay
        return focusSessions.reduce(0) { total, session in
            guard session.startDate >= startDate else { return total }
            return total + session.durationMinutes
        }
    }

    private var focusActiveDaysLast30: Int {
        focusActiveDays(lastDays: 30).count
    }

    private var focusCurrentStreak: Int {
        streakLength(from: Date().startOfDay, days: focusActiveDays(lastDays: 60))
    }

    private var focusBestStreak: Int {
        bestStreak(in: focusActiveDays(lastDays: 90))
    }

    private var averageIntensityLast30: Int {
        guard !recentLogs.isEmpty else { return 0 }
        let total = recentLogs.reduce(0.0) { $0 + $1.intensity }
        return Int(((total / Double(recentLogs.count)) * 100).rounded())
    }

    private var bestLog: DailyLog? {
        recentLogs.max { $0.intensity < $1.intensity }
    }

    private var totalXP: Int {
        XPCalculator.totalXP(logs: logs, tasks: tasks, milestones: milestones, bonuses: bonuses)
    }

    private var xpProgress: XPProgress {
        XPCalculator.progress(for: totalXP)
    }

    private var xpLast30: Int {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -29, to: Date().startOfDay) ?? Date().startOfDay
        let logXP = recentLogs.reduce(0) { $0 + XPCalculator.xpForLog($1) }
        let taskXP = tasks.reduce(0) { total, task in
            guard let completedAt = task.completedAt, completedAt >= startDate else { return total }
            return total + XPCalculator.xpForTask(task)
        }
        let milestoneXP = milestones.reduce(0) { total, milestone in
            guard let completedAt = milestone.completedAt, completedAt >= startDate else { return total }
            return total + XPCalculator.xpForMilestone(milestone)
        }
        let bonusXP = bonuses.reduce(0) { total, bonus in
            guard bonus.createdAt >= startDate else { return total }
            return total + bonus.amount
        }
        return logXP + taskXP + milestoneXP + bonusXP
    }

    private var bestStreak: Int {
        var current = 0
        var best = 0
        let sorted = recentLogs.sorted { $0.date < $1.date }
        for log in sorted {
            if log.intensity > 0.05 {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }

    private var weeklyBuckets: [InsightsWeek] {
        let calendar = Calendar.current
        let end = Date().startOfDay
        let start = calendar.date(byAdding: .weekOfYear, value: -7, to: end) ?? end
        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: start)?.start else {
            return []
        }

        var weeks: [InsightsWeek] = []
        var current = startOfWeek
        while current <= end {
            let next = calendar.date(byAdding: .day, value: 7, to: current) ?? current
            let weekLogs = logs.filter { $0.date >= current && $0.date < next }
            let weekTasks = tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= current && completedAt < next
            }
            let weekMilestones = milestones.filter { milestone in
                guard let completedAt = milestone.completedAt else { return false }
                return completedAt >= current && completedAt < next
            }
            let weekFocusMinutes = focusSessions.reduce(0) { total, session in
                guard session.startDate >= current && session.startDate < next else { return total }
                return total + session.durationMinutes
            }
            let activeDays = weekLogs.filter { $0.intensity > 0.05 }.count
            let averageIntensity: Double
            if weekLogs.isEmpty {
                averageIntensity = 0
            } else {
                let total = weekLogs.reduce(0.0) { $0 + $1.intensity }
                averageIntensity = total / Double(weekLogs.count)
            }
            let weekBonus = bonuses.reduce(0) { total, bonus in
                guard bonus.createdAt >= current && bonus.createdAt < next else { return total }
                return total + bonus.amount
            }
            let weekXP = weekLogs.reduce(0) { $0 + XPCalculator.xpForLog($1) }
                + weekTasks.reduce(0) { $0 + XPCalculator.xpForTask($1) }
                + weekMilestones.reduce(0) { $0 + XPCalculator.xpForMilestone($1) }
                + weekBonus
            weeks.append(
                InsightsWeek(
                    start: current,
                    activeDays: activeDays,
                    averageIntensity: averageIntensity,
                    xpTotal: weekXP,
                    focusMinutes: weekFocusMinutes
                )
            )
            current = next
        }
        return weeks
    }

    private var consistencyChart: some View {
        Chart(weeklyBuckets) { bucket in
            BarMark(
                x: .value("Week", bucket.start),
                y: .value("Active Days", bucket.activeDays)
            )
            .foregroundStyle(InsightsTheme.primary)
            .clipShape(Capsule())
        }
        .chartYScale(domain: 0...7)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(InsightsDateFormatter.short.string(from: date))
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(InsightsTheme.inkSoft)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 3, 7]) { value in
                AxisValueLabel {
                    if let number = value.as(Int.self) {
                        Text("\(number)")
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(InsightsTheme.inkSoft)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(InsightsTheme.grid)
            }
        }
        .frame(height: 180)
    }

    private var intensityChart: some View {
        Chart(weeklyBuckets) { bucket in
            LineMark(
                x: .value("Week", bucket.start),
                y: .value("Intensity", bucket.averageIntensity * 100)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(InsightsTheme.accent)

            PointMark(
                x: .value("Week", bucket.start),
                y: .value("Intensity", bucket.averageIntensity * 100)
            )
            .foregroundStyle(InsightsTheme.accent)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(InsightsDateFormatter.short.string(from: date))
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(InsightsTheme.inkSoft)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisValueLabel {
                    if let number = value.as(Int.self) {
                        Text("\(number)%")
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(InsightsTheme.inkSoft)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(InsightsTheme.grid)
            }
        }
        .frame(height: 180)
    }

    private var xpChart: some View {
        Chart(weeklyBuckets) { bucket in
            BarMark(
                x: .value("Week", bucket.start),
                y: .value("XP", bucket.xpTotal)
            )
            .foregroundStyle(InsightsTheme.primary)
            .clipShape(Capsule())
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(InsightsDateFormatter.short.string(from: date))
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(InsightsTheme.inkSoft)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let number = value.as(Int.self) {
                        Text("\(number)")
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(InsightsTheme.inkSoft)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(InsightsTheme.grid)
            }
        }
        .frame(height: 180)
    }

    private var focusChart: some View {
        Chart(weeklyBuckets) { bucket in
            BarMark(
                x: .value("Week", bucket.start),
                y: .value("Focus Minutes", bucket.focusMinutes)
            )
            .foregroundStyle(InsightsTheme.accent)
            .clipShape(Capsule())
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(InsightsDateFormatter.short.string(from: date))
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(InsightsTheme.inkSoft)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let number = value.as(Int.self) {
                        Text("\(number)")
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(InsightsTheme.inkSoft)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(InsightsTheme.grid)
            }
        }
        .frame(height: 180)
    }

    private var topHabit: HabitHighlight? {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -29, to: Date().startOfDay) ?? Date().startOfDay
        let recentCheckIns = checkIns.filter { $0.date >= startDate && $0.progress > 0.01 }
        guard !recentCheckIns.isEmpty else { return nil }

        var counts: [UUID: Int] = [:]
        for checkIn in recentCheckIns {
            if let habitID = checkIn.habit?.id {
                counts[habitID, default: 0] += 1
            }
        }

        guard let top = counts.max(by: { $0.value < $1.value }),
              let habit = habits.first(where: { $0.id == top.key }) else {
            return nil
        }

        return HabitHighlight(title: habit.title, checkIns: top.value)
    }

    private func focusActiveDays(lastDays: Int) -> Set<Date> {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -(lastDays - 1), to: Date().startOfDay) ?? Date().startOfDay
        let days = focusSessions
            .filter { $0.startDate >= startDate }
            .map { $0.startDate.startOfDay }
        return Set(days)
    }

    private func streakLength(from start: Date, days: Set<Date>) -> Int {
        var count = 0
        var cursor = start
        let calendar = Calendar.current
        while days.contains(cursor) {
            count += 1
            guard let next = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = next
        }
        return count
    }

    private func bestStreak(in days: Set<Date>) -> Int {
        let sorted = days.sorted()
        guard !sorted.isEmpty else { return 0 }

        let calendar = Calendar.current
        var best = 1
        var current = 1

        for index in 1..<sorted.count {
            let prev = sorted[index - 1]
            let currentDay = sorted[index]
            let nextDay = calendar.date(byAdding: .day, value: 1, to: prev)
            if nextDay == currentDay {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }
}

private struct InsightsBackground: View {
    var body: some View {
        LinearGradient(
            colors: [InsightsTheme.backgroundTop, InsightsTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(InsightsTheme.glow)
                .frame(width: 220, height: 220)
                .offset(x: -80, y: -90)
        }
    }
}

private struct InsightsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Insights")
                .font(.custom("Avenir Next", size: 32))
                .fontWeight(.bold)
                .foregroundStyle(InsightsTheme.ink)
            Text("Consistency beats intensity, and the chart shows it.")
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(InsightsTheme.inkSoft)
        }
        .padding(.top, 6)
    }
}

private struct EmptyInsightsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No data yet")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(InsightsTheme.ink)
            Text("Complete a few days to unlock trends and streak insights.")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(InsightsTheme.inkSoft)
        }
        .padding(16)
        .background(InsightsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: InsightsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct SummaryCard: View {
    let activeDays: Int
    let focusMinutes: Int
    let averageIntensity: Int
    let bestStreak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 30 days")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(InsightsTheme.ink)

            HStack(spacing: 12) {
                SummaryPill(title: "Active days", value: "\(activeDays)")
                SummaryPill(title: "Focus", value: "\(focusMinutes)m")
            }

            HStack(spacing: 12) {
                SummaryPill(title: "Avg intensity", value: "\(averageIntensity)%")
                SummaryPill(title: "Best streak", value: "\(bestStreak)d")
            }
        }
        .padding(16)
        .background(InsightsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: InsightsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct SummaryPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.custom("Avenir Next", size: 10))
                .fontWeight(.semibold)
                .foregroundStyle(InsightsTheme.inkSoft)
            Text(value)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(InsightsTheme.ink)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(InsightsTheme.pill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct FocusSummaryCard: View {
    let totalMinutes: Int
    let activeDays: Int
    let currentStreak: Int
    let bestStreak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus momentum")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(InsightsTheme.ink)

            HStack(spacing: 12) {
                SummaryPill(title: "Minutes", value: "\(totalMinutes)")
                SummaryPill(title: "Active days", value: "\(activeDays)")
            }

            HStack(spacing: 12) {
                SummaryPill(title: "Current streak", value: "\(currentStreak)d")
                SummaryPill(title: "Best streak", value: "\(bestStreak)d")
            }
        }
        .padding(16)
        .background(InsightsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: InsightsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct XPHighlightCard: View {
    let totalXP: Int
    let last30XP: Int
    let progress: XPProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("XP progress")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(InsightsTheme.ink)

            HStack(spacing: 12) {
                SummaryPill(title: "Level", value: "\(progress.level)")
                SummaryPill(title: "Total XP", value: "\(totalXP)")
            }

            SummaryPill(title: "Last 30 days", value: "\(last30XP)")

            VStack(alignment: .leading, spacing: 6) {
                Text("\(progress.current)/\(progress.needed) XP to next level")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(InsightsTheme.inkSoft)
                XPProgressBar(progress: progress.ratio)
            }
        }
        .padding(16)
        .background(InsightsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: InsightsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct XPProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(InsightsTheme.pill)
                Capsule()
                    .fill(InsightsTheme.primary)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 8)
    }
}

private struct TrendCard<ChartContent: View>: View {
    let title: String
    let subtitle: String
    let chart: ChartContent

    init(title: String, subtitle: String, chart: ChartContent) {
        self.title = title
        self.subtitle = subtitle
        self.chart = chart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(InsightsTheme.ink)
            Text(subtitle)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(InsightsTheme.inkSoft)
            chart
        }
        .padding(16)
        .background(InsightsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: InsightsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct HabitHighlightCard: View {
    let habitTitle: String?
    let checkIns: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Most consistent habit")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(InsightsTheme.ink)

            if let habitTitle {
                Text(habitTitle)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(InsightsTheme.ink)

                Text("\(checkIns) check-ins in the last 30 days")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(InsightsTheme.inkSoft)
            } else {
                Text("No habit check-ins yet.")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(InsightsTheme.inkSoft)
            }
        }
        .padding(16)
        .background(InsightsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: InsightsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct BestDayCard: View {
    let bestLog: DailyLog?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Best day")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(InsightsTheme.ink)

            if let bestLog {
                Text(InsightsDateFormatter.long.string(from: bestLog.date))
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(InsightsTheme.ink)

                HStack(spacing: 12) {
                    SummaryPill(title: "Intensity", value: "\(Int((bestLog.intensity * 100).rounded()))%")
                    SummaryPill(title: "Focus", value: "\(bestLog.focusMinutes)m")
                }
            } else {
                Text("Log a few days to surface your best session.")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(InsightsTheme.inkSoft)
            }
        }
        .padding(16)
        .background(InsightsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: InsightsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct InsightsWeek: Identifiable {
    let start: Date
    let activeDays: Int
    let averageIntensity: Double
    let xpTotal: Int
    let focusMinutes: Int

    var id: Date { start }
}

private struct HabitHighlight {
    let title: String
    let checkIns: Int
}

private enum InsightsDateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let long: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
}

private enum InsightsTheme {
    static let backgroundTop = Color(red: 0.94, green: 0.96, blue: 0.98)
    static let backgroundBottom = Color(red: 0.98, green: 0.97, blue: 0.95)
    static let glow = Color(red: 0.76, green: 0.84, blue: 0.94, opacity: 0.45)
    static let card = AppPalette.card
    static let pill = Color(red: 0.92, green: 0.94, blue: 0.97)
    static let ink = AppPalette.ink
    static let inkSoft = AppPalette.inkSoft
    static let primary = Color(red: 0.26, green: 0.48, blue: 0.62)
    static let accent = Color(red: 0.88, green: 0.49, blue: 0.38)
    static let grid = Color(red: 0.82, green: 0.85, blue: 0.9, opacity: 0.4)
    static let shadow = AppPalette.shadow
}
