import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query(sort: \FocusSession.startDate, order: .reverse) private var focusSessions: [FocusSession]

    @State private var selectedDay: HeatmapDay?
    @State private var showFocusDiary = false

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

                    FocusDiaryCard(
                        days: FocusDiaryData.days(from: focusSessions, count: 14),
                        onOpen: { showFocusDiary = true }
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
        .sheet(item: $selectedDay) { day in
            DayDetailView(day: day)
        }
        .sheet(isPresented: $showFocusDiary) {
            FocusDiaryView(sessions: focusSessions)
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

    
}

private struct FocusDiaryCard: View {
    let days: [FocusDiaryDay]
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Focus diary")
                        .font(.custom("Avenir Next", size: 20))
                        .fontWeight(.semibold)
                        .foregroundStyle(CalendarTheme.ink)
                    Text("Hours focused each day")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(CalendarTheme.inkSoft)
                }
                Spacer()
                Button(action: onOpen) {
                    Text("View")
                        .font(.custom("Avenir Next", size: 12))
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(CalendarTheme.heatmapFill)
                        .clipShape(Capsule())
                }
            }

            FocusDiaryChart(
                days: days,
                selectedDate: nil,
                onSelect: nil
            )
            .frame(height: 72)
        }
        .padding(16)
        .background(CalendarTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: CalendarTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct FocusDiaryView: View {
    @Environment(\.dismiss) private var dismiss
    let sessions: [FocusSession]

    @State private var selectedDate = Date().startOfDay

    private var days: [FocusDiaryDay] {
        FocusDiaryData.days(from: sessions, count: 14)
    }

    private var selectedSessions: [FocusSession] {
        FocusDiaryData.sessions(on: selectedDate, from: sessions)
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    FocusDiaryHeader()

                    FocusDiaryChart(
                        days: days,
                        selectedDate: selectedDate,
                        onSelect: { date in
                        selectedDate = date
                        }
                    )
                    .frame(height: 140)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                    FocusDaySummary(date: selectedDate, minutes: totalMinutes)

                    FocusSessionList(sessions: selectedSessions)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle("Focus diary")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let last = days.last {
                    selectedDate = last.date
                }
            }
        }
    }

    private var totalMinutes: Int {
        selectedSessions.reduce(0) { $0 + $1.durationMinutes }
    }
}

private struct FocusDiaryHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hours focused")
                .font(.custom("Avenir Next", size: 22))
                .fontWeight(.bold)
                .foregroundStyle(CalendarTheme.ink)
            Text("Tap a day to see the sessions and what you worked on.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(CalendarTheme.inkSoft)
        }
        .padding(.top, 4)
    }
}

private struct FocusDiaryChart: View {
    let days: [FocusDiaryDay]
    let selectedDate: Date?
    let onSelect: ((Date) -> Void)?

    let barWidth: CGFloat = 18
    let labelWidth: CGFloat = 24
    let maxBarHeight: CGFloat = 80
    let labelProvider: (Date) -> String = FocusDiaryData.shortWeekday

    private var maxMinutes: Int {
        max(days.map(\.minutes).max() ?? 0, 10)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(days) { day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(barColor(for: day))
                            .frame(width: barWidth, height: barHeight(for: day))
                            .onTapGesture {
                                onSelect?(day.date)
                            }
                        Text(labelProvider(day.date))
                            .font(.custom("Avenir Next", size: 10))
                            .foregroundStyle(CalendarTheme.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(width: labelWidth)
                    }
                }
            }
            .frame(width: totalWidth, alignment: .leading)
        }
    }

    private func barHeight(for day: FocusDiaryDay) -> CGFloat {
        let ratio = Double(day.minutes) / Double(maxMinutes)
        return max(6, maxBarHeight * ratio)
    }

    private func barColor(for day: FocusDiaryDay) -> Color {
        if let selectedDate, Calendar.current.isDate(day.date, inSameDayAs: selectedDate) {
            return CalendarTheme.heatmapFill
        }
        return day.minutes == 0 ? CalendarTheme.heatmapBase.opacity(0.4) : CalendarTheme.heatmapFill.opacity(0.6)
    }

    private var totalWidth: CGFloat {
        guard !days.isEmpty else { return 0 }
        let spacing: CGFloat = 6
        return CGFloat(days.count) * labelWidth + CGFloat(days.count - 1) * spacing
    }
}

private struct FocusDaySummary: View {
    let date: Date
    let minutes: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(CalendarDateFormatter.full.string(from: date))
                    .font(.custom("Avenir Next", size: 14))
                    .fontWeight(.semibold)
                    .foregroundStyle(CalendarTheme.ink)
                Text("Total focus time")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(CalendarTheme.inkSoft)
            }
            Spacer()
            Text(FocusDiaryData.durationLabel(minutes))
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.bold)
                .foregroundStyle(CalendarTheme.ink)
        }
        .padding(12)
        .background(CalendarTheme.pill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FocusSessionList: View {
    let sessions: [FocusSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sessions")
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.semibold)
                .foregroundStyle(CalendarTheme.ink)

            if sessions.isEmpty {
                Text("No focus sessions for this day.")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(CalendarTheme.inkSoft)
            } else {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(session.task?.title ?? "Unassigned focus")
                                .font(.custom("Avenir Next", size: 14))
                                .fontWeight(.semibold)
                                .foregroundStyle(CalendarTheme.ink)
                            Spacer()
                            Text(FocusDiaryData.timeLabel(session.startDate))
                                .font(.custom("Avenir Next", size: 12))
                                .foregroundStyle(CalendarTheme.inkSoft)
                        }

                        Text("\(FocusDiaryData.durationLabel(session.durationMinutes)) • \(FocusDiaryData.shortDateTime(session.startDate))")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(CalendarTheme.inkSoft)

                        if !session.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(session.note)
                                .font(.custom("Avenir Next", size: 12))
                                .foregroundStyle(CalendarTheme.ink)
                        }
                    }
                    .padding(12)
                    .background(CalendarTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: CalendarTheme.shadow, radius: 4, x: 0, y: 2)
                }
            }
        }
    }
}

private struct FocusDiaryDay: Identifiable {
    let date: Date
    let minutes: Int

    var id: Date { date }
}

private enum FocusDiaryData {
    static func days(from sessions: [FocusSession], count: Int) -> [FocusDiaryDay] {
        guard count > 0 else { return [] }
        let calendar = Calendar.current
        let today = Date().startOfDay
        let startDate = calendar.date(byAdding: .day, value: -(count - 1), to: today) ?? today
        let grouped = Dictionary(grouping: sessions) { $0.startDate.startOfDay }

        return (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { return nil }
            let minutes = grouped[date.startOfDay]?.reduce(0) { $0 + $1.durationMinutes } ?? 0
            return FocusDiaryDay(date: date, minutes: minutes)
        }
    }

    static func sessions(on date: Date, from sessions: [FocusSession]) -> [FocusSession] {
        sessions.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
    }

    static func durationLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            let hours = Double(minutes) / 60.0
            return String(format: "%.1fh", hours)
        }
        return "\(minutes)m"
    }

    static func shortWeekday(from date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    static func compactWeekday(from date: Date) -> String {
        compactWeekdayFormatter.string(from: date)
    }

    static func timeLabel(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func shortDateTime(_ date: Date) -> String {
        shortDateTimeFormatter.string(from: date)
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EE"
        return formatter
    }()

    private static let compactWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEEEE"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let shortDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
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
                WeekdayLabels(topPadding: HeatmapTimeline.weekdayTopPadding)
                HeatmapTimeline(days: days, onSelect: onSelect)
            }

            HeatmapLegend()
        }
        .padding(16)
        .background(CalendarTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: CalendarTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct HeatmapTimeline: View {
    let days: [HeatmapDay]
    let onSelect: (HeatmapDay) -> Void

    static let cellSize: CGFloat = 12
    static let spacing: CGFloat = 6
    static let labelHeight: CGFloat = 12
    static let labelSpacing: CGFloat = 6
    static let verticalPadding: CGFloat = 4

    static var weekdayTopPadding: CGFloat {
        labelHeight + labelSpacing + verticalPadding
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Self.labelSpacing) {
                MonthLabelsRow(
                    days: days,
                    cellSize: Self.cellSize,
                    spacing: Self.spacing,
                    height: Self.labelHeight
                )
                HeatmapGrid(
                    days: days,
                    onSelect: onSelect,
                    cellSize: Self.cellSize,
                    spacing: Self.spacing
                )
            }
            .padding(.vertical, Self.verticalPadding)
        }
    }
}

private struct MonthLabelsRow: View {
    let days: [HeatmapDay]
    let cellSize: CGFloat
    let spacing: CGFloat
    let height: CGFloat

    var body: some View {
        let weekStarts = weekStartDates
        let markers = monthMarkers(for: weekStarts)
        let width = totalWidth(for: weekStarts.count)

        ZStack(alignment: .leading) {
            ForEach(markers) { marker in
                Text(marker.label)
                    .font(.custom("Avenir Next", size: 10))
                    .foregroundStyle(CalendarTheme.inkSoft)
                    .offset(x: marker.x)
            }
        }
        .frame(width: width, height: height, alignment: .leading)
    }

    private var weekStartDates: [Date] {
        stride(from: 0, to: days.count, by: 7).compactMap { index in
            guard days.indices.contains(index) else { return nil }
            return days[index].date
        }
    }

    private func monthMarkers(for weeks: [Date]) -> [MonthMarker] {
        let calendar = Calendar.current
        var markers: [MonthMarker] = []
        var lastMonth = -1

        for (index, date) in weeks.enumerated() {
            let month = calendar.component(.month, from: date)
            if index == 0 || month != lastMonth {
                let label = MonthLabelsRow.formatter.string(from: date)
                markers.append(
                    MonthMarker(
                        id: index,
                        label: label,
                        x: columnOffset(for: index)
                    )
                )
                lastMonth = month
            }
        }
        return markers
    }

    private func columnOffset(for index: Int) -> CGFloat {
        CGFloat(index) * (cellSize + spacing)
    }

    private func totalWidth(for columns: Int) -> CGFloat {
        guard columns > 0 else { return 0 }
        return CGFloat(columns) * cellSize + CGFloat(columns - 1) * spacing
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter
    }()
}

private struct MonthMarker: Identifiable {
    let id: Int
    let label: String
    let x: CGFloat
}

private struct HeatmapGrid: View {
    let days: [HeatmapDay]
    let onSelect: (HeatmapDay) -> Void
    let cellSize: CGFloat
    let spacing: CGFloat

    private var rows: [GridItem] {
        Array(repeating: GridItem(.fixed(cellSize), spacing: spacing), count: 7)
    }

    var body: some View {
        LazyHGrid(rows: rows, spacing: spacing) {
            ForEach(days) { day in
                HeatmapCell(day: day, size: cellSize)
                    .onTapGesture {
                        onSelect(day)
                    }
            }
        }
    }
}

private struct HeatmapCell: View {
    let day: HeatmapDay
    let size: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(CalendarTheme.heatmapColor(for: day.intensity))
            .frame(width: size, height: size)
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
    let topPadding: CGFloat
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
        .padding(.top, topPadding)
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
    @Environment(\.modelContext) private var modelContext
    let day: HeatmapDay

    @State private var log: DailyLog?
    @State private var habitCheckIns: [HabitCheckIn] = []
    @State private var completedTasks: [TaskItem] = []
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(CalendarDateFormatter.full.string(from: day.date))
                        .font(.custom("Avenir Next", size: 20))
                        .fontWeight(.semibold)
                        .foregroundStyle(CalendarTheme.ink)

                    if let log {
                        VStack(alignment: .leading, spacing: 12) {
                            DayDetailRow(title: "Intensity", value: "\(Int(log.intensity * 100))%")
                            Slider(value: Binding(
                                get: { log.intensity },
                                set: { newValue in
                                    log.intensity = newValue
                                    log.updatedAt = Date()
                                }
                            ), in: 0...1)

                            Stepper("Priorities: \(log.completedPriorities)/\(log.totalPriorities)", value: Binding(
                                get: { log.completedPriorities },
                                set: { newValue in
                                    log.completedPriorities = max(0, min(newValue, log.totalPriorities))
                                    log.updatedAt = Date()
                                }
                            ), in: 0...max(0, log.totalPriorities))

                            Stepper("Habits: \(log.completedHabits)/\(log.totalHabits)", value: Binding(
                                get: { log.completedHabits },
                                set: { newValue in
                                    log.completedHabits = max(0, min(newValue, log.totalHabits))
                                    log.updatedAt = Date()
                                }
                            ), in: 0...max(0, log.totalHabits))

                            Stepper("Focus minutes: \(log.focusMinutes)", value: Binding(
                                get: { log.focusMinutes },
                                set: { newValue in
                                    log.focusMinutes = max(0, newValue)
                                    log.updatedAt = Date()
                                }
                            ), in: 0...300, step: 5)
                        }
                        .padding(12)
                        .background(CalendarTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: CalendarTheme.shadow, radius: 6, x: 0, y: 4)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Notes")
                                .font(.custom("Avenir Next", size: 16))
                                .fontWeight(.semibold)
                                .foregroundStyle(CalendarTheme.ink)

                            TextEditor(text: Binding(
                                get: { log.note },
                                set: { newValue in
                                    log.note = newValue
                                    log.updatedAt = Date()
                                }
                            ))
                            .frame(minHeight: 120)
                            .padding(8)
                            .background(CalendarTheme.pill)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(12)
                        .background(CalendarTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: CalendarTheme.shadow, radius: 6, x: 0, y: 4)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Proof photo")
                                .font(.custom("Avenir Next", size: 16))
                                .fontWeight(.semibold)
                                .foregroundStyle(CalendarTheme.ink)

                            if let data = log.photoData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 180)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(CalendarTheme.pill)
                                    .frame(height: 140)
                                    .overlay(
                                        Text("Add a photo")
                                            .font(.custom("Avenir Next", size: 13))
                                            .foregroundStyle(CalendarTheme.inkSoft)
                                    )
                            }

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Text(log.photoData == nil ? "Add photo" : "Replace photo")
                                    .font(.custom("Avenir Next", size: 13))
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(CalendarTheme.heatmapFill)
                                    .clipShape(Capsule())
                            }

                            if log.photoData != nil {
                                Button("Remove photo", role: .destructive) {
                                    log.photoData = nil
                                    log.updatedAt = Date()
                                }
                            }
                        }
                        .padding(12)
                        .background(CalendarTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: CalendarTheme.shadow, radius: 6, x: 0, y: 4)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Habit check-ins")
                                .font(.custom("Avenir Next", size: 16))
                                .fontWeight(.semibold)
                                .foregroundStyle(CalendarTheme.ink)

                            if habitCheckIns.isEmpty {
                                Text("No habit check-ins logged.")
                                    .font(.custom("Avenir Next", size: 13))
                                    .foregroundStyle(CalendarTheme.inkSoft)
                            } else {
                                ForEach(habitCheckIns) { checkIn in
                                    HStack {
                                        Text(checkIn.habit?.title ?? "Habit")
                                            .font(.custom("Avenir Next", size: 14))
                                            .foregroundStyle(CalendarTheme.ink)
                                        Spacer()
                                        Text(checkIn.progress >= 1 ? "Done" : "Tiny")
                                            .font(.custom("Avenir Next", size: 12))
                                            .foregroundStyle(CalendarTheme.inkSoft)
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(CalendarTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: CalendarTheme.shadow, radius: 6, x: 0, y: 4)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tasks completed")
                                .font(.custom("Avenir Next", size: 16))
                                .fontWeight(.semibold)
                                .foregroundStyle(CalendarTheme.ink)

                            if completedTasks.isEmpty {
                                Text("No tasks completed.")
                                    .font(.custom("Avenir Next", size: 13))
                                    .foregroundStyle(CalendarTheme.inkSoft)
                            } else {
                                ForEach(completedTasks) { task in
                                    HStack {
                                        Text(task.title)
                                            .font(.custom("Avenir Next", size: 14))
                                            .foregroundStyle(CalendarTheme.ink)
                                        Spacer()
                                        if let goal = task.goal {
                                            Text(goal.title)
                                                .font(.custom("Avenir Next", size: 11))
                                                .foregroundStyle(CalendarTheme.inkSoft)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(CalendarTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: CalendarTheme.shadow, radius: 6, x: 0, y: 4)
                    } else {
                        Text("No activity logged.")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundStyle(CalendarTheme.inkSoft)
                    }
                }
                .padding(20)
            }
            .navigationTitle("Day details")
            .task {
                ensureLog()
                loadBreakdowns()
            }
            .onChange(of: selectedPhoto) { _ in
                loadPhoto()
            }
        }
    }

    private func ensureLog() {
        let startOfDay = day.date.startOfDay
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }
        let predicate = #Predicate<DailyLog> { log in
            log.date >= startOfDay && log.date < endOfDay
        }
        let descriptor = FetchDescriptor(predicate: predicate)

        if let existing = try? modelContext.fetch(descriptor).first {
            log = existing
        } else {
            let newLog = DailyLog(
                date: startOfDay,
                totalPriorities: 3,
                totalHabits: 4
            )
            modelContext.insert(newLog)
            log = newLog
        }
    }

    private func loadBreakdowns() {
        let startOfDay = day.date.startOfDay
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }

        let habitPredicate = #Predicate<HabitCheckIn> { checkIn in
            checkIn.date >= startOfDay && checkIn.date < endOfDay
        }
        let habitDescriptor = FetchDescriptor(predicate: habitPredicate)
        habitCheckIns = (try? modelContext.fetch(habitDescriptor)) ?? []

        let taskDescriptor = FetchDescriptor<TaskItem>()
        let allTasks = (try? modelContext.fetch(taskDescriptor)) ?? []
        completedTasks = allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= startOfDay && completedAt < endOfDay
        }
    }

    private func loadPhoto() {
        guard let selectedPhoto else { return }
        Task {
            if let data = try? await selectedPhoto.loadTransferable(type: Data.self) {
                await MainActor.run {
                    log?.photoData = data
                    log?.updatedAt = Date()
                }
            }
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
    static let card = AppPalette.card
    static let pill = Color(red: 0.92, green: 0.94, blue: 0.98)
    static let ink = AppPalette.ink
    static let inkSoft = AppPalette.inkSoft
    static let shadow = AppPalette.shadow
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
