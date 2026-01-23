import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]

    @State private var selectedDay: HeatmapDay?

    private let weeksToShow = 16

    var body: some View {
        ZStack {
            CalendarBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    CalendarHeader()

                    StreakSummaryCard(
                        currentStreak: currentStreak,
                        bestStreak: bestStreak,
                        activeDays: activeDaysLast30,
                        focusMinutes: focusMinutesLast30,
                        consistencyScore: consistencyScore
                    )

                    HeatmapSection(
                        days: heatmapDays,
                        onSelect: { selectedDay = $0 }
                    )

                    StreakHistoryCard(segments: recentStreakSegments)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            seedLogsIfNeeded()
        }
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day)
        }
    }

    private var heatmapDays: [HeatmapDay] {
        let calendar = heatmapCalendar
        let today = Date().startOfDay
        let totalDays = weeksToShow * 7
        let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) ?? today
        let logByDay = logs.reduce(into: [Date: DailyLog]()) { result, log in
            result[log.date.startOfDay] = log
        }

        return (0..<totalDays).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            let log = logByDay[date.startOfDay]
            return HeatmapDay(date: date, intensity: log?.intensity ?? 0, log: log)
        }
    }

    private var currentStreak: Int {
        guard let lastDay = heatmapDays.last, lastDay.isActive, let lastSegment = streakSegments.last else {
            return 0
        }
        return lastSegment.length
    }

    private var bestStreak: Int {
        streakSegments.map(\.length).max() ?? 0
    }

    private var activeDaysLast30: Int {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -29, to: Date().startOfDay) ?? Date().startOfDay
        return heatmapDays.filter { $0.date >= startDate && $0.isActive }.count
    }

    private var focusMinutesLast30: Int {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -29, to: Date().startOfDay) ?? Date().startOfDay
        return logs.filter { $0.date >= startDate }.reduce(0) { $0 + $1.focusMinutes }
    }

    private var consistencyScore: Int {
        let score = Double(activeDaysLast30) / 30.0
        return Int((score * 100).rounded())
    }

    private var recentStreakSegments: [StreakSegment] {
        Array(streakSegments.suffix(3).reversed())
    }

    private var streakSegments: [StreakSegment] {
        let calendar = Calendar.current
        var segments: [StreakSegment] = []
        var currentStart: Date?
        var currentEnd: Date?
        var currentLength = 0

        for day in heatmapDays {
            if day.isActive {
                if currentStart == nil {
                    currentStart = day.date
                }
                currentEnd = day.date
                currentLength += 1
            } else if let start = currentStart, let end = currentEnd {
                segments.append(StreakSegment(start: start, end: end, length: currentLength))
                currentStart = nil
                currentEnd = nil
                currentLength = 0
            }
        }

        if let start = currentStart, let end = currentEnd {
            segments.append(StreakSegment(start: start, end: end, length: currentLength))
        }

        return segments
    }

    private var heatmapCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private func seedLogsIfNeeded() {
        guard logs.isEmpty else { return }

        let calendar = heatmapCalendar
        let today = Date().startOfDay
        let totalDays = weeksToShow * 7
        let startDate = calendar.date(byAdding: .day, value: -(totalDays - 1), to: today) ?? today

        for offset in 0..<totalDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }
            let chance = Double.random(in: 0...1)
            let intensity = chance < 0.3 ? 0 : Double.random(in: 0.2...1)
            let completedPriorities = Int((intensity * 3).rounded())
            let completedHabits = Int((intensity * 4).rounded())
            let focusMinutes = Int((intensity * 60).rounded())

            let log = DailyLog(
                date: date,
                intensity: intensity,
                completedPriorities: completedPriorities,
                totalPriorities: 3,
                completedHabits: completedHabits,
                totalHabits: 4,
                focusMinutes: focusMinutes,
                updatedAt: date
            )
            modelContext.insert(log)
        }
    }
}

private struct CalendarBackground: View {
    var body: some View {
        LinearGradient(
            colors: [CalendarTheme.backgroundTop, CalendarTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(CalendarTheme.glow)
                .frame(width: 200, height: 200)
                .offset(x: 80, y: -90)
        }
    }
}

private struct CalendarHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Calendar")
                .font(.custom("Avenir Next", size: 32))
                .fontWeight(.bold)
                .foregroundStyle(CalendarTheme.ink)
            Text("Your streaks and effort map.")
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(CalendarTheme.inkSoft)
        }
        .padding(.top, 6)
    }
}

private struct StreakSummaryCard: View {
    let currentStreak: Int
    let bestStreak: Int
    let activeDays: Int
    let focusMinutes: Int
    let consistencyScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SummaryPill(title: "Current", value: "\(currentStreak)d")
                SummaryPill(title: "Best", value: "\(bestStreak)d")
                SummaryPill(title: "Active 30d", value: "\(activeDays)")
            }

            HStack {
                SummaryPill(title: "Focus 30d", value: "\(focusMinutes)m")
                SummaryPill(title: "Consistency", value: "\(consistencyScore)")
            }
        }
        .padding(16)
        .background(CalendarTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: CalendarTheme.shadow, radius: 8, x: 0, y: 5)
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
                .foregroundStyle(CalendarTheme.inkSoft)
            Text(value)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(CalendarTheme.ink)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(CalendarTheme.pill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct HeatmapSection: View {
    let days: [HeatmapDay]
    let onSelect: (HeatmapDay) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity heatmap")
                .font(.custom("Avenir Next", size: 20))
                .fontWeight(.semibold)
                .foregroundStyle(CalendarTheme.ink)

            HStack(alignment: .top, spacing: 12) {
                WeekdayLabels()
                HeatmapGrid(days: days, onSelect: onSelect)
            }

            HeatmapLegend()
        }
        .padding(16)
        .background(CalendarTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: CalendarTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct HeatmapGrid: View {
    let days: [HeatmapDay]
    let onSelect: (HeatmapDay) -> Void

    private let rows = Array(repeating: GridItem(.fixed(12), spacing: 6), count: 7)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 6) {
                ForEach(days) { day in
                    HeatmapCell(day: day)
                        .onTapGesture {
                            onSelect(day)
                        }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct HeatmapCell: View {
    let day: HeatmapDay

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(CalendarTheme.heatmapColor(for: day.intensity))
            .frame(width: 12, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(CalendarTheme.ink.opacity(day.isToday ? 0.6 : 0), lineWidth: 1)
            )
    }
}

private struct HeatmapLegend: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Less")
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(CalendarTheme.inkSoft)
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(CalendarTheme.heatmapColor(for: Double(index) / 4))
                        .frame(width: 12, height: 12)
                }
            }
            Text("More")
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(CalendarTheme.inkSoft)
        }
    }
}

private struct WeekdayLabels: View {
    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(labels.indices, id: \.self) { index in
                Text(index % 2 == 0 ? labels[index] : "")
                    .font(.custom("Avenir Next", size: 10))
                    .foregroundStyle(CalendarTheme.inkSoft)
                    .frame(height: 12)
            }
        }
    }
}

private struct StreakHistoryCard: View {
    let segments: [StreakSegment]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streak history")
                .font(.custom("Avenir Next", size: 20))
                .fontWeight(.semibold)
                .foregroundStyle(CalendarTheme.ink)

            if segments.isEmpty {
                Text("No streaks yet. Start with one good day.")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(CalendarTheme.inkSoft)
            } else {
                ForEach(segments) { segment in
                    HStack {
                        Text("\(CalendarDateFormatter.short.string(from: segment.start)) - \(CalendarDateFormatter.short.string(from: segment.end))")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(CalendarTheme.ink)
                        Spacer()
                        Text("\(segment.length) days")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(CalendarTheme.inkSoft)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(16)
        .background(CalendarTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: CalendarTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct DayDetailView: View {
    let day: HeatmapDay

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(CalendarDateFormatter.full.string(from: day.date))
                    .font(.custom("Avenir Next", size: 20))
                    .fontWeight(.semibold)
                    .foregroundStyle(CalendarTheme.ink)

                if let log = day.log {
                    DayDetailRow(title: "Intensity", value: "\(Int(log.intensity * 100))%")
                    DayDetailRow(
                        title: "Priorities",
                        value: "\(log.completedPriorities)/\(log.totalPriorities)"
                    )
                    DayDetailRow(
                        title: "Habits",
                        value: "\(log.completedHabits)/\(log.totalHabits)"
                    )
                    DayDetailRow(title: "Focus", value: "\(log.focusMinutes) min")
                } else {
                    Text("No activity logged.")
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(CalendarTheme.inkSoft)
                }

                Spacer()
            }
            .padding(20)
            .navigationTitle("Day details")
        }
    }
}

private struct DayDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(CalendarTheme.inkSoft)
            Spacer()
            Text(value)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(CalendarTheme.ink)
        }
        .padding(12)
        .background(CalendarTheme.pill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct HeatmapDay: Identifiable {
    let date: Date
    let intensity: Double
    let log: DailyLog?

    var id: Date { date }

    var isActive: Bool {
        intensity > 0.05
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

private struct StreakSegment: Identifiable {
    let start: Date
    let end: Date
    let length: Int

    var id: Date { start }
}

private enum CalendarDateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()
}

private enum CalendarTheme {
    static let backgroundTop = Color(red: 0.94, green: 0.96, blue: 0.99)
    static let backgroundBottom = Color(red: 0.98, green: 0.98, blue: 0.95)
    static let glow = Color(red: 0.74, green: 0.83, blue: 0.94, opacity: 0.5)
    static let card = Color(red: 0.99, green: 0.98, blue: 0.97)
    static let pill = Color(red: 0.92, green: 0.94, blue: 0.98)
    static let ink = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let inkSoft = Color(red: 0.38, green: 0.40, blue: 0.44)
    static let shadow = Color(red: 0.15, green: 0.16, blue: 0.18, opacity: 0.08)
    static let heatmapBase = Color(red: 0.78, green: 0.84, blue: 0.92)
    static let heatmapFill = Color(red: 0.27, green: 0.57, blue: 0.72)

    static func heatmapColor(for intensity: Double) -> Color {
        let clamped = min(max(intensity, 0), 1)
        if clamped <= 0 {
            return heatmapBase.opacity(0.4)
        }
        return heatmapFill.opacity(0.25 + (0.7 * clamped))
    }
}
