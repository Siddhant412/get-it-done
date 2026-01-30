import SwiftUI
import SwiftData
import Combine
import UIKit

struct TodayView: View {
    private let maxPriorities = 3

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyPriority.sortOrder) private var priorities: [DailyPriority]
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @Query(sort: \UserStats.updatedAt, order: .reverse) private var stats: [UserStats]
    @Query(sort: \Goal.sortOrder) private var goals: [Goal]
    @Query(sort: \DailyLog.date) private var logs: [DailyLog]
    @Query(sort: \HabitCheckIn.date) private var habitCheckIns: [HabitCheckIn]
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \Milestone.createdAt, order: .reverse) private var milestones: [Milestone]
    @Query(sort: \XPBonus.createdAt, order: .reverse) private var xpBonuses: [XPBonus]
    @Query(sort: \QuestClaim.claimedAt, order: .reverse) private var questClaims: [QuestClaim]
    @Query(sort: \FocusSession.startDate, order: .reverse) private var focusSessions: [FocusSession]

    @State private var animatedProgress: Double = 0.0
    @State private var activeSheet: ActiveSheet?
    @State private var selectedPriority: DailyPriority?
    @State private var selectedHabit: Habit?

    var body: some View {
        ZStack {
            TodayBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    HeaderRow(dateText: dateText)

                    if shouldShowRecoveryBanner {
                        RecoveryBanner(
                            tokensRemaining: freezeTokensRemaining,
                            onUseFreeze: activateStreakProtection
                        )
                    }

                    HeroCard(
                        progress: animatedProgress,
                        streakDays: currentStreakDays,
                        focusMinutes: currentFocusMinutes,
                        xp: todayXP,
                        onProgressTap: { activeSheet = .progress }
                    )

                    SectionHeader(
                        title: "Top 3 priorities",
                        actionTitle: "Edit",
                        action: { activeSheet = .priorityManager }
                    )
                    ForEach(priorityItemsForProgress) { item in
                        PriorityRow(item: item, onDetail: { selectedPriority = item })
                    }

                    SectionHeader(
                        title: "Habits to keep alive",
                        actionTitle: "All",
                        action: { activeSheet = .habitManager }
                    )
                    HabitRow(
                        items: habits,
                        onDetail: { selectedHabit = $0 },
                        onProgressChange: recordHabitCheckIn
                    )

                    WeeklyQuestCard(quests: weeklyQuests, onClaim: claimQuest)

                    MomentumCard(
                        progress: momentumProgress,
                        isProtected: isStreakProtected,
                        tokensRemaining: freezeTokensRemaining,
                        onToggleProtection: toggleStreakProtection
                    )

                    QuickActionsCard(
                        onStartFocus: { activeSheet = .focus },
                        onQuickAdd: { activeSheet = .quickAdd }
                    )

                    FocusHistoryCard(
                        sessions: recentFocusSessions,
                        totalMinutes: focusMinutesLast7,
                        onViewAll: { activeSheet = .focusHistory }
                    )

                    RecapCard(
                        completedPriorities: priorityCompletionCount,
                        totalPriorities: priorityItemsForProgress.count,
                        completedHabits: habits.filter { $0.progress >= 1 }.count,
                        totalHabits: habits.count,
                        focusMinutes: currentFocusMinutes,
                        onView: { activeSheet = .recap }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            animatedProgress = 0
            withAnimation(.easeOut(duration: 0.9)) {
                animatedProgress = todayProgress
            }
            upsertTodayLog()
            refreshFreezeTokensIfNeeded()
        }
        .onChange(of: todayProgress) { newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newValue
            }
            upsertTodayLog()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .progress:
                ProgressDetailView(
                    progress: todayProgress,
                    priorities: priorityItemsForProgress,
                    habits: habits
                )
            case .quickAdd:
                QuickAddSheet(
                    goals: goals,
                    onAddPriority: addPriority,
                    onAddHabit: addHabit
                )
            case .focus:
                FocusTimerView(tasks: tasks, onComplete: addFocusSession)
            case .priorityManager:
                PriorityManagerView()
            case .habitManager:
                HabitManagerView()
            case .recap:
                RecapView(
                    date: Date(),
                    completedPriorities: priorityCompletionCount,
                    totalPriorities: priorityItemsForProgress.count,
                    completedHabits: habits.filter { $0.progress >= 1 }.count,
                    totalHabits: habits.count,
                    focusMinutes: currentFocusMinutes,
                    progress: todayProgress
                )
            case .focusHistory:
                FocusHistoryView(sessions: focusSessions, tasks: tasks)
            }
        }
        .sheet(item: $selectedPriority) { item in
            PriorityDetailView(item: item, goals: goals, onDelete: deletePriority)
        }
        .sheet(item: $selectedHabit) { item in
            HabitDetailView(
                item: item,
                onDelete: deleteHabit,
                onProgressChange: { recordHabitCheckIn(for: item) }
            )
        }
    }

    private var priorityItemsForProgress: [DailyPriority] {
        Array(priorities.prefix(maxPriorities))
    }

    private var priorityCompletionCount: Int {
        priorityItemsForProgress.filter { $0.isCompleted }.count
    }

    private var todayProgress: Double {
        let totalSlots = Double(priorityItemsForProgress.count + habits.count)
        guard totalSlots > 0 else { return 0 }

        let priorityScore = Double(priorityCompletionCount)
        let habitScore = habits.reduce(0.0) { $0 + $1.progress }
        let rawProgress = (priorityScore + habitScore) / totalSlots
        return min(max(rawProgress, 0), 1)
    }

    private var momentumProgress: Double {
        let boost = isStreakProtected ? 0.08 : 0.0
        return min(1, max(0, todayProgress + boost))
    }

    private var currentStats: UserStats? {
        stats.first
    }

    private var currentStreakDays: Int {
        currentStats?.streakDays ?? 0
    }

    private var currentFocusMinutes: Int {
        let start = Date().startOfDay
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return focusSessions.reduce(0) { total, session in
            guard session.startDate >= start && session.startDate < end else { return total }
            return total + session.durationMinutes
        }
    }

    private var todayXP: Int {
        let baseXP = XPCalculator.xpForCounts(
            completedPriorities: priorityCompletionCount,
            completedHabits: habits.filter { $0.progress >= 1 }.count,
            focusMinutes: currentFocusMinutes
        )
        let day = Date().startOfDay
        return baseXP
            + XPCalculator.xpForTasks(tasks, on: day)
            + XPCalculator.xpForMilestones(milestones, on: day)
            + XPCalculator.bonuses(on: day, bonuses: xpBonuses)
    }

    private var weeklyCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var weekStart: Date {
        weeklyCalendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date().startOfDay
    }

    private var weekEnd: Date {
        weeklyCalendar.date(byAdding: .day, value: 7, to: weekStart) ?? Date().startOfDay
    }

    private var weeklyLogs: [DailyLog] {
        logs.filter { $0.date >= weekStart && $0.date < weekEnd }
    }

    private var weeklyActiveDays: Int {
        weeklyLogs.filter { $0.intensity > 0.05 }.count
    }

    private var weeklyPrioritiesCompleted: Int {
        weeklyLogs.reduce(0) { $0 + $1.completedPriorities }
    }

    private var weeklyFocusMinutes: Int {
        weeklyLogs.reduce(0) { $0 + $1.focusMinutes }
    }

    private var weeklyTasksCompleted: Int {
        tasks.reduce(0) { total, task in
            guard let completedAt = task.completedAt,
                  completedAt >= weekStart && completedAt < weekEnd else { return total }
            return total + 1
        }
    }

    private var weeklyHabitCheckIns: Int {
        habitCheckIns.reduce(0) { total, checkIn in
            guard checkIn.date >= weekStart,
                  checkIn.date < weekEnd,
                  checkIn.progress > 0.01 else { return total }
            return total + 1
        }
    }

    private var recentFocusSessions: [FocusSession] {
        Array(focusSessions.prefix(3))
    }

    private var focusMinutesLast7: Int {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -6, to: Date().startOfDay) ?? Date().startOfDay
        return focusSessions.reduce(0) { total, session in
            guard session.startDate >= startDate else { return total }
            return total + session.durationMinutes
        }
    }

    private var claimedQuestIDs: Set<String> {
        let sameWeekClaims = questClaims.filter { claim in
            weeklyCalendar.isDate(claim.weekStart, inSameDayAs: weekStart)
        }
        return Set(sameWeekClaims.map(\.questID))
    }

    private var weeklyQuests: [WeeklyQuest] {
        [
            WeeklyQuest(
                id: "show-up",
                title: "Show up 5 days",
                detail: "Active days this week",
                progress: weeklyActiveDays,
                target: 5,
                rewardXP: 120,
                isClaimed: claimedQuestIDs.contains("show-up")
            ),
            WeeklyQuest(
                id: "priorities",
                title: "Finish 8 priorities",
                detail: "Top 3 wins completed",
                progress: weeklyPrioritiesCompleted,
                target: 8,
                rewardXP: 160,
                isClaimed: claimedQuestIDs.contains("priorities")
            ),
            WeeklyQuest(
                id: "focus",
                title: "Focus 150 minutes",
                detail: "Deep work minutes",
                progress: weeklyFocusMinutes,
                target: 150,
                rewardXP: 180,
                isClaimed: claimedQuestIDs.contains("focus")
            ),
            WeeklyQuest(
                id: "tasks",
                title: "Complete 3 tasks",
                detail: "Ship concrete work",
                progress: weeklyTasksCompleted,
                target: 3,
                rewardXP: 150,
                isClaimed: claimedQuestIDs.contains("tasks")
            ),
            WeeklyQuest(
                id: "habits",
                title: "Log 6 habit check-ins",
                detail: "Tiny wins count",
                progress: weeklyHabitCheckIns,
                target: 6,
                rewardXP: 140,
                isClaimed: claimedQuestIDs.contains("habits")
            )
        ]
    }

    private func claimQuest(_ quest: WeeklyQuest) {
        guard quest.isComplete, !quest.isClaimed else { return }

        let claim = QuestClaim(
            questID: quest.id,
            weekStart: weekStart,
            rewardXP: quest.rewardXP
        )
        modelContext.insert(claim)

        let bonus = XPBonus(
            source: "quest",
            detail: quest.title,
            amount: quest.rewardXP,
            weekStart: weekStart
        )
        modelContext.insert(bonus)

        AppHaptics.success()
    }

    private var isStreakProtected: Bool {
        currentStats?.streakProtected ?? false
    }

    private var freezeTokensRemaining: Int {
        currentStats?.streakFreezeTokens ?? 0
    }

    private var shouldShowRecoveryBanner: Bool {
        todayProgress < 0.3 && !isStreakProtected
    }

    private func addPriority(title: String, detail: String, isSmallWin: Bool, goal: Goal?) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)

        let nextOrder = (priorities.map(\.sortOrder).max() ?? -1) + 1
        let item = DailyPriority(
            title: trimmedTitle,
            detail: trimmedDetail.isEmpty ? "Focus | 20 min" : trimmedDetail,
            isSmallWin: isSmallWin,
            sortOrder: nextOrder,
            goal: goal
        )
        modelContext.insert(item)
        AppHaptics.success()
        upsertTodayLog()
    }

    private func addHabit(title: String, streak: Int) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let nextOrder = (habits.map(\.sortOrder).max() ?? -1) + 1
        let item = Habit(
            title: trimmedTitle,
            streak: max(0, min(streak, 365)),
            progress: 0,
            sortOrder: nextOrder
        )
        modelContext.insert(item)
        AppHaptics.success()
        upsertTodayLog()
    }

    private func addFocusSession(minutes: Int, task: TaskItem?) {
        updateStats { stats in
            stats.focusMinutes += minutes
        }

        let session = FocusSession(
            startDate: Date(),
            durationMinutes: minutes,
            task: task
        )
        modelContext.insert(session)

        AppHaptics.success()
        upsertTodayLog()
    }

    private func toggleStreakProtection() {
        updateStats { stats in
            if stats.streakProtected {
                stats.streakProtected = false
            } else if stats.streakFreezeTokens > 0 {
                stats.streakFreezeTokens -= 1
                stats.streakProtected = true
            }
        }
        AppHaptics.tap()
    }

    private func activateStreakProtection() {
        updateStats { stats in
            guard !stats.streakProtected, stats.streakFreezeTokens > 0 else { return }
            stats.streakFreezeTokens -= 1
            stats.streakProtected = true
        }
        AppHaptics.tap()
    }

    private func updateStats(_ update: (UserStats) -> Void) {
        if let stats = currentStats {
            update(stats)
            stats.updatedAt = Date()
        } else {
            let stats = UserStats()
            update(stats)
            modelContext.insert(stats)
        }
    }

    private func refreshFreezeTokensIfNeeded() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        updateStats { stats in
            guard stats.lastFreezeResetMonth != currentMonth else { return }
            stats.lastFreezeResetMonth = currentMonth
            stats.streakFreezeTokens = stats.freezeTokenAllowance
        }
    }

    private func deletePriority(_ item: DailyPriority) {
        modelContext.delete(item)
        normalizePriorityOrder()
        upsertTodayLog()
    }

    private func deleteHabit(_ item: Habit) {
        modelContext.delete(item)
        normalizeHabitOrder()
        upsertTodayLog()
    }

    private func recordHabitCheckIn(for habit: Habit) {
        let day = Date().startOfDay
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: day) else {
            return
        }
        let habitID = habit.id
        let predicate = #Predicate<HabitCheckIn> { checkIn in
            checkIn.date >= day && checkIn.date < endOfDay && checkIn.habit?.id == habitID
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let existing = (try? modelContext.fetch(descriptor))?.first

        if habit.progress <= 0.01 {
            if let existing {
                modelContext.delete(existing)
            }
            return
        }

        let checkIn = existing ?? HabitCheckIn(date: day, progress: habit.progress, habit: habit)
        checkIn.progress = habit.progress
        if existing == nil {
            modelContext.insert(checkIn)
        }
    }

    private func normalizePriorityOrder() {
        let ordered = priorities.sorted { $0.sortOrder < $1.sortOrder }
        for (index, item) in ordered.enumerated() {
            item.sortOrder = index
        }
    }

    private func normalizeHabitOrder() {
        let ordered = habits.sorted { $0.sortOrder < $1.sortOrder }
        for (index, item) in ordered.enumerated() {
            item.sortOrder = index
        }
    }

    private func upsertTodayLog() {
        let startOfDay = Date().startOfDay
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }

        let predicate = #Predicate<DailyLog> { log in
            log.date >= startOfDay && log.date < endOfDay
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        let existing = (try? modelContext.fetch(descriptor))?.first

        let log = existing ?? DailyLog(date: startOfDay)
        log.intensity = todayProgress
        log.completedPriorities = priorityCompletionCount
        log.totalPriorities = priorityItemsForProgress.count
        log.completedHabits = habits.filter { $0.progress >= 1 }.count
        log.totalHabits = habits.count
        log.focusMinutes = currentFocusMinutes
        log.updatedAt = Date()

        if existing == nil {
            modelContext.insert(log)
        }

        updateWidgetSnapshot()
    }

    private func updateWidgetSnapshot() {
        let snapshot = WidgetSnapshot(
            date: Date(),
            streakDays: currentStreakDays,
            todayProgress: todayProgress,
            topPriorities: priorityItemsForProgress.map { $0.title }
        )
        WidgetDataStore.save(snapshot)
    }

    private var dateText: String {
        TodayView.dateFormatter.string(from: Date())
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()
}

private struct TodayBackground: View {
    var body: some View {
        LinearGradient(
            colors: [TodayTheme.backgroundTop, TodayTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(TodayTheme.glow)
                .frame(width: 220, height: 220)
                .offset(x: 90, y: -80)
        }
        .overlay(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(TodayTheme.panelSoft)
                .frame(width: 240, height: 140)
                .rotationEffect(.degrees(-8))
                .offset(x: -60, y: 70)
        }
    }
}

private struct HeaderRow: View {
    let dateText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.custom("Avenir Next", size: 32))
                .fontWeight(.bold)
                .foregroundStyle(TodayTheme.ink)
            Text(dateText)
                .font(.custom("Avenir Next", size: 16))
                .foregroundStyle(TodayTheme.inkSoft)
        }
        .padding(.top, 6)
    }
}

private struct HeroCard: View {
    let progress: Double
    let streakDays: Int
    let focusMinutes: Int
    let xp: Int
    let onProgressTap: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onProgressTap) {
                ProgressRing(progress: progress)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 10) {
                Text("Daily momentum")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)

                Text("Complete one small win to keep your streak alive.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(TodayTheme.inkSoft)

                HStack(spacing: 12) {
                    StatPill(title: "Streak", value: "\(streakDays) days")
                    StatPill(title: "Focus", value: "\(focusMinutes) min")
                    StatPill(title: "XP", value: "\(xp)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(TodayTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TodayTheme.cardBorder, lineWidth: 1)
        )
    }
}

private struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = 84
    var lineWidth: CGFloat = 10
    var showsLabel: Bool = true

    var body: some View {
        let clamped = min(max(progress, 0), 1)

        ZStack {
            Circle()
                .stroke(TodayTheme.ringTrack, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, clamped))
                .stroke(
                    TodayTheme.ringGradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if showsLabel {
                VStack(spacing: 2) {
                    Text("\(Int(clamped * 100))%")
                        .font(.custom("Avenir Next", size: 18))
                        .fontWeight(.bold)
                    Text("today")
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(TodayTheme.inkSoft)
                }
                .foregroundStyle(TodayTheme.ink)
            }
        }
        .frame(width: size, height: size)
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.custom("Avenir Next", size: 10))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.inkSoft)
            Text(value)
                .font(.custom("Avenir Next", size: 13))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(TodayTheme.pillBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SectionHeader: View {
    let title: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next", size: 20))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
            Spacer()
            Button(action: action) {
                Text(actionTitle)
            }
            .font(.custom("Avenir Next", size: 14))
            .foregroundStyle(TodayTheme.accent)
        }
        .padding(.top, 6)
    }
}

private struct PriorityRow: View {
    @Bindable var item: DailyPriority
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                ZStack {
                    Circle()
                        .strokeBorder(TodayTheme.accent, lineWidth: 2)
                        .frame(width: 22, height: 22)

                    if item.isCompleted {
                        Circle()
                            .fill(TodayTheme.accent)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    } else if item.isSmallWin {
                        Circle()
                            .fill(TodayTheme.highlight)
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(item.isCompleted ? TodayTheme.inkSoft : TodayTheme.ink)
                    .strikethrough(item.isCompleted, color: TodayTheme.inkSoft)
                Text(item.detail)
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(TodayTheme.inkSoft)
            }

            Spacer()

            Text(item.isSmallWin ? "Tiny win" : "Core")
                .font(.custom("Avenir Next", size: 12))
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(item.isSmallWin ? TodayTheme.badgeSoft : TodayTheme.badgeStrong)
                .foregroundStyle(TodayTheme.ink)
                .clipShape(Capsule())

            if let goal = item.goal {
                GoalTag(goal: goal)
            }

            Button(action: onDetail) {
                Image(systemName: "info.circle")
                    .foregroundStyle(TodayTheme.inkSoft)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }

    private func toggle() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            item.isCompleted.toggle()
        }
        AppHaptics.tap()
    }
}

private struct GoalTag: View {
    let goal: Goal

    var body: some View {
        let tint = Color(hex: goal.colorHex) ?? TodayTheme.accent

        Text(goal.title)
            .font(.custom("Avenir Next", size: 11))
            .fontWeight(.semibold)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.18))
            .foregroundStyle(tint)
            .clipShape(Capsule())
    }
}

private struct GoalSelectionMenu: View {
    let goals: [Goal]
    let selectedGoal: Goal?
    let onSelect: (Goal?) -> Void

    var body: some View {
        Menu {
            Button("No goal") {
                onSelect(nil)
            }
            ForEach(goals) { goal in
                Button(goal.title) {
                    onSelect(goal)
                }
            }
        } label: {
            HStack {
                Text("Goal")
                Spacer()
                Text(selectedGoal?.title ?? "None")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct HabitRow: View {
    let items: [Habit]
    let onDetail: (Habit) -> Void
    let onProgressChange: (Habit) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(items) { item in
                    HabitCard(
                        item: item,
                        onDetail: { onDetail(item) },
                        onProgressChange: { onProgressChange(item) }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct HabitCard: View {
    @Bindable var item: Habit
    let onDetail: () -> Void
    let onProgressChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.title)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)
                Spacer()
                Button(action: onDetail) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(TodayTheme.inkSoft)
                }
                .buttonStyle(.plain)
            }

            Text("\(item.streak)-day streak")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(TodayTheme.inkSoft)

            HabitScheduleRow(scheduleDays: item.scheduleDays)

            ProgressBar(progress: item.progress)

            Button(action: toggleFullCheckIn) {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                    Text(statusLabel)
                        .font(.custom("Avenir Next", size: 12))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .foregroundStyle(statusForeground)
                .background(statusBackground)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!isScheduledToday)
            .contextMenu {
                if isScheduledToday {
                    Button("Tiny check-in") {
                        updateProgress(to: 0.35)
                    }
                    if item.progress > 0 {
                        Button("Reset today") {
                            updateProgress(to: 0)
                        }
                    }
                } else {
                    Button("Not scheduled today") { }
                }
            }
        }
        .padding(14)
        .frame(width: 170)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
        .opacity(isScheduledToday ? 1 : 0.65)
    }

    private var statusLabel: String {
        if !isScheduledToday {
            return "Rest day"
        }
        if item.progress >= 1 {
            return "Done"
        }
        if item.progress > 0 {
            return "Tiny done"
        }
        return "Check in"
    }

    private var statusIcon: String {
        if !isScheduledToday {
            return "moon.zzz"
        }
        if item.progress >= 1 {
            return "checkmark.circle.fill"
        }
        if item.progress > 0 {
            return "bolt.fill"
        }
        return "circle"
    }

    private var statusBackground: Color {
        if !isScheduledToday {
            return TodayTheme.badgeStrong
        }
        if item.progress >= 1 {
            return TodayTheme.accent
        }
        if item.progress > 0 {
            return TodayTheme.badgeSoft
        }
        return TodayTheme.badgeStrong
    }

    private var statusForeground: Color {
        if item.progress >= 1 {
            return .white
        }
        return TodayTheme.ink
    }

    private func toggleFullCheckIn() {
        guard isScheduledToday else { return }
        let target: Double = item.progress >= 1 ? 0 : 1
        updateProgress(to: target)
    }

    private func updateProgress(to value: Double) {
        withAnimation(.easeInOut(duration: 0.35)) {
            item.progress = min(max(value, 0), 1)
        }
        AppHaptics.tap()
        onProgressChange()
    }

    private var isScheduledToday: Bool {
        item.scheduleDays.isEmpty || item.scheduleDays.contains(todayScheduleDay)
    }

    private var todayScheduleDay: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let mapping = [7, 1, 2, 3, 4, 5, 6]
        return mapping[weekday - 1]
    }
}

private struct ProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(TodayTheme.ringTrack)
                Capsule()
                    .fill(TodayTheme.progressFill)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.35), value: progress)
    }
}

private struct HabitScheduleRow: View {
    let scheduleDays: [Int]

    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...7, id: \.self) { day in
                let isScheduled = scheduleDays.contains(day)
                let isToday = day == todayIndex
                Text(labels[day - 1])
                    .font(.custom("Avenir Next", size: 10))
                    .fontWeight(.semibold)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isScheduled ? .white : TodayTheme.inkSoft)
                    .background(isScheduled ? TodayTheme.accent : TodayTheme.badgeStrong)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isToday ? TodayTheme.highlight : .clear, lineWidth: 2)
                    )
            }
        }
    }

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let mapping = [7, 1, 2, 3, 4, 5, 6]
        return mapping[weekday - 1]
    }
}

private struct MomentumCard: View {
    let progress: Double
    let isProtected: Bool
    let tokensRemaining: Int
    let onToggleProtection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Momentum meter")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)
                Spacer()
                Button(action: onToggleProtection) {
                    HStack(spacing: 6) {
                        Image(systemName: isProtected ? "shield.checkerboard" : "shield")
                        Text(isProtected ? "Protected" : "Protect")
                    }
                    .font(.custom("Avenir Next", size: 12))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(isProtected ? .white : TodayTheme.ink)
                    .background(isProtected ? TodayTheme.accent : TodayTheme.badgeStrong)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!isProtected && tokensRemaining == 0)
            }

            Text("You are close to your best streak. One small task keeps the chain unbroken.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(TodayTheme.inkSoft)
            Text("\(tokensRemaining) freeze tokens left this month")
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(TodayTheme.inkSoft)
            ProgressBar(progress: progress)
        }
        .padding(16)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct WeeklyQuestCard: View {
    let quests: [WeeklyQuest]
    let onClaim: (WeeklyQuest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly quests")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)
                Spacer()
                Text("Resets Monday")
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(TodayTheme.inkSoft)
            }

            ForEach(quests) { quest in
                QuestRow(quest: quest, onClaim: { onClaim(quest) })
            }
        }
        .padding(16)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct QuestRow: View {
    let quest: WeeklyQuest
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(quest.title)
                    .font(.custom("Avenir Next", size: 14))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)
                Spacer()
                if quest.isClaimed {
                    QuestStatusPill(label: "Claimed", isEmphasis: true)
                } else if quest.isComplete {
                    Button(action: onClaim) {
                        QuestStatusPill(label: "Claim +\(quest.rewardXP) XP", isEmphasis: true)
                    }
                    .buttonStyle(.plain)
                } else {
                    QuestStatusPill(label: "+\(quest.rewardXP) XP", isEmphasis: false)
                }
            }

            Text(quest.detail)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(TodayTheme.inkSoft)

            HStack(spacing: 8) {
                QuestProgressBar(progress: quest.progressRatio)
                Text("\(min(quest.progress, quest.target))/\(quest.target)")
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(TodayTheme.inkSoft)
            }
        }
        .padding(10)
        .background(TodayTheme.pillBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct QuestStatusPill: View {
    let label: String
    let isEmphasis: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isEmphasis ? "checkmark.circle.fill" : "bolt.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(label)
        }
        .font(.custom("Avenir Next", size: 11))
        .fontWeight(.semibold)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(isEmphasis ? .white : TodayTheme.ink)
        .background(isEmphasis ? TodayTheme.accent : TodayTheme.badgeStrong)
        .clipShape(Capsule())
    }
}

private struct QuestProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(TodayTheme.ringTrack)
                Capsule()
                    .fill(TodayTheme.progressFill)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.3), value: progress)
    }
}

private struct RecoveryBanner: View {
    let tokensRemaining: Int
    let onUseFreeze: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Keep the streak alive")
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)
                Text("Do one tiny task or use a freeze token.")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(TodayTheme.inkSoft)
            }
            Spacer()
            Button("Use freeze") {
                onUseFreeze()
            }
            .font(.custom("Avenir Next", size: 12))
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tokensRemaining > 0 ? TodayTheme.accent : TodayTheme.badgeStrong)
            .clipShape(Capsule())
            .disabled(tokensRemaining == 0)
        }
        .padding(14)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct QuickActionsCard: View {
    let onStartFocus: () -> Void
    let onQuickAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Start focus", action: onStartFocus)
                .font(.custom("Avenir Next", size: 15))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(TodayTheme.primaryButton)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button("Quick add", action: onQuickAdd)
                .font(.custom("Avenir Next", size: 15))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(TodayTheme.secondaryButton)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct FocusHistoryCard: View {
    let sessions: [FocusSession]
    let totalMinutes: Int
    let onViewAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Focus log")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)
                Spacer()
                Button("See all", action: onViewAll)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(TodayTheme.inkSoft)
            }

            Text("Last 7 days: \(totalMinutes) min")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(TodayTheme.inkSoft)

            if sessions.isEmpty {
                Text("No focus sessions yet.")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(TodayTheme.inkSoft)
            } else {
                ForEach(sessions) { session in
                    FocusSessionRow(session: session)
                }
            }
        }
        .padding(16)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct FocusSessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.task?.title ?? "Unassigned focus")
                    .font(.custom("Avenir Next", size: 13))
                    .foregroundStyle(TodayTheme.ink)
                Text(TodayView.dateTimeFormatter.string(from: session.startDate))
                    .font(.custom("Avenir Next", size: 11))
                    .foregroundStyle(TodayTheme.inkSoft)
            }
            Spacer()
            Text("\(session.durationMinutes)m")
                .font(.custom("Avenir Next", size: 12))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
        }
        .padding(10)
        .background(TodayTheme.pillBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct FocusHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let sessions: [FocusSession]
    let tasks: [TaskItem]

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    Text("No focus sessions yet.")
                        .font(.custom("Avenir Next", size: 14))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sessions) { session in
                        NavigationLink(destination: FocusSessionDetailView(session: session, tasks: tasks)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.task?.title ?? "Unassigned focus")
                                    .font(.custom("Avenir Next", size: 16))
                                Text(TodayView.dateTimeFormatter.string(from: session.startDate))
                                    .font(.custom("Avenir Next", size: 12))
                                    .foregroundStyle(.secondary)
                                Text("\(session.durationMinutes) minutes")
                                    .font(.custom("Avenir Next", size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
            .navigationTitle("Focus history")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
    }
}

private struct FocusSessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: FocusSession
    let tasks: [TaskItem]

    var body: some View {
        Form {
            Section("Details") {
                DatePicker("Start time", selection: $session.startDate, displayedComponents: [.date, .hourAndMinute])
                Stepper("Duration: \(session.durationMinutes) min", value: $session.durationMinutes, in: 5...240, step: 5)
            }

            Section("Task") {
                Menu {
                    Button("No task") {
                        session.task = nil
                    }
                    if !tasks.isEmpty {
                        Divider()
                    }
                    ForEach(tasks) { task in
                        Button(task.title) {
                            session.task = task
                        }
                    }
                } label: {
                    HStack {
                        Text("Attach task")
                        Spacer()
                        Text(session.task?.title ?? "None")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: $session.note)
                    .frame(minHeight: 120)
            }

            Section {
                Button("Delete session", role: .destructive) {
                    modelContext.delete(session)
                    dismiss()
                }
            }
        }
        .navigationTitle("Focus session")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct RecapCard: View {
    let completedPriorities: Int
    let totalPriorities: Int
    let completedHabits: Int
    let totalHabits: Int
    let focusMinutes: Int
    let onView: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("End of day recap")
                    .font(.custom("Avenir Next", size: 18))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)
                Spacer()
                Button("View", action: onView)
                    .font(.custom("Avenir Next", size: 13))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(TodayTheme.primaryButton)
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                RecapPill(title: "Priorities", value: "\(completedPriorities)/\(totalPriorities)")
                RecapPill(title: "Habits", value: "\(completedHabits)/\(totalHabits)")
                RecapPill(title: "Focus", value: "\(focusMinutes)m")
            }
        }
        .padding(16)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct RecapPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.custom("Avenir Next", size: 10))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.inkSoft)
            Text(value)
                .font(.custom("Avenir Next", size: 13))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(TodayTheme.pillBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProgressDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let progress: Double
    let priorities: [DailyPriority]
    let habits: [Habit]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()
                        ProgressRing(progress: progress, size: 140, lineWidth: 14)
                        Spacer()
                    }
                    .padding(.top, 12)

                    ProgressSummaryRow(
                        title: "Priorities done",
                        value: "\(priorities.filter { $0.isCompleted }.count)/\(priorities.count)"
                    )
                    ProgressSummaryRow(
                        title: "Habits checked in",
                        value: "\(habits.filter { $0.progress >= 1 }.count)/\(habits.count)"
                    )

                    Text("Priorities")
                        .font(.custom("Avenir Next", size: 18))
                        .fontWeight(.semibold)
                        .foregroundStyle(TodayTheme.ink)

                    ForEach(priorities) { item in
                        ProgressItemRow(
                            title: item.title,
                            status: item.isCompleted ? "Done" : "Pending",
                            isPositive: item.isCompleted
                        )
                    }

                    Text("Habits")
                        .font(.custom("Avenir Next", size: 18))
                        .fontWeight(.semibold)
                        .foregroundStyle(TodayTheme.ink)
                        .padding(.top, 6)

                    ForEach(habits) { item in
                        ProgressItemRow(
                            title: item.title,
                            status: item.progress >= 1 ? "Done" : (item.progress > 0 ? "Tiny" : "Pending"),
                            isPositive: item.progress > 0
                        )
                    }
                }
                .padding(20)
            }
            .navigationTitle("Today's progress")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RecapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let completedPriorities: Int
    let totalPriorities: Int
    let completedHabits: Int
    let totalHabits: Int
    let focusMinutes: Int
    let progress: Double

    @State private var log: DailyLog?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ProgressRing(progress: progress, size: 120, lineWidth: 12)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)

                    RecapSummaryRow(title: "Priorities", value: "\(completedPriorities)/\(totalPriorities)")
                    RecapSummaryRow(title: "Habits", value: "\(completedHabits)/\(totalHabits)")
                    RecapSummaryRow(title: "Focus", value: "\(focusMinutes) min")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reflection")
                            .font(.custom("Avenir Next", size: 16))
                            .fontWeight(.semibold)
                            .foregroundStyle(TodayTheme.ink)

                        TextEditor(text: Binding(
                            get: { log?.note ?? "" },
                            set: { newValue in
                                log?.note = newValue
                                log?.updatedAt = Date()
                            }
                        ))
                        .frame(minHeight: 120)
                        .padding(10)
                        .background(TodayTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(TodayTheme.cardBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(20)
            }
            .navigationTitle("Daily recap")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                ensureLog()
            }
        }
    }

    private func ensureLog() {
        let startOfDay = date.startOfDay
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }
        let predicate = #Predicate<DailyLog> { log in
            log.date >= startOfDay && log.date < endOfDay
        }
        let descriptor = FetchDescriptor(predicate: predicate)

        if let existing = try? modelContext.fetch(descriptor).first {
            log = existing
            existing.intensity = progress
            existing.completedPriorities = completedPriorities
            existing.totalPriorities = totalPriorities
            existing.completedHabits = completedHabits
            existing.totalHabits = totalHabits
            existing.focusMinutes = focusMinutes
            existing.updatedAt = Date()
        } else {
            let newLog = DailyLog(
                date: startOfDay,
                intensity: progress,
                completedPriorities: completedPriorities,
                totalPriorities: totalPriorities,
                completedHabits: completedHabits,
                totalHabits: totalHabits,
                focusMinutes: focusMinutes,
                updatedAt: Date()
            )
            modelContext.insert(newLog)
            log = newLog
        }
    }
}

private struct RecapSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(TodayTheme.inkSoft)
            Spacer()
            Text(value)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
        }
        .padding(12)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProgressSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(TodayTheme.inkSoft)
            Spacer()
            Text(value)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)
        }
        .padding(12)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProgressItemRow: View {
    let title: String
    let status: String
    let isPositive: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(TodayTheme.ink)
            Spacer()
            Text(status)
                .font(.custom("Avenir Next", size: 12))
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isPositive ? TodayTheme.badgeStrong : TodayTheme.badgeSoft)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

private struct PriorityManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyPriority.sortOrder) private var items: [DailyPriority]
    @Query(sort: \Goal.sortOrder) private var goals: [Goal]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    PriorityManagerRow(item: item, goals: goals)
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
            }
            .navigationTitle("Edit priorities")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showAdd = true
                    }
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddPrioritySheet(goals: goals) { title, detail, isSmallWin, goal in
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { return }
                let nextOrder = (items.map(\.sortOrder).max() ?? -1) + 1
                let item = DailyPriority(
                    title: trimmedTitle,
                    detail: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                    isSmallWin: isSmallWin,
                    sortOrder: nextOrder,
                    goal: goal
                )
                modelContext.insert(item)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
        normalizeOrder()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var revised = items
        revised.move(fromOffsets: source, toOffset: destination)
        for (index, item) in revised.enumerated() {
            item.sortOrder = index
        }
    }

    private func normalizeOrder() {
        let ordered = items.sorted { $0.sortOrder < $1.sortOrder }
        for (index, item) in ordered.enumerated() {
            item.sortOrder = index
        }
    }
}

private struct PriorityManagerRow: View {
    @Bindable var item: DailyPriority
    let goals: [Goal]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $item.title)
                .font(.custom("Avenir Next", size: 16))
            TextField("Detail", text: $item.detail)
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(.secondary)
            Toggle("Tiny win", isOn: $item.isSmallWin)

            if !goals.isEmpty {
                GoalSelectionMenu(
                    goals: goals,
                    selectedGoal: item.goal,
                    onSelect: { item.goal = $0 }
                )
            }
        }
        .padding(.vertical, 6)
    }
}

private struct HabitManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.sortOrder) private var items: [Habit]
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    HabitManagerRow(item: item)
                }
                .onDelete(perform: delete)
                .onMove(perform: move)
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Add") {
                        showAdd = true
                    }
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddHabitSheet { title, streak in
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { return }
                let nextOrder = (items.map(\.sortOrder).max() ?? -1) + 1
                let item = Habit(
                    title: trimmedTitle,
                    streak: max(0, min(streak, 365)),
                    progress: 0,
                    sortOrder: nextOrder
                )
                modelContext.insert(item)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
        normalizeOrder()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var revised = items
        revised.move(fromOffsets: source, toOffset: destination)
        for (index, item) in revised.enumerated() {
            item.sortOrder = index
        }
    }

    private func normalizeOrder() {
        let ordered = items.sorted { $0.sortOrder < $1.sortOrder }
        for (index, item) in ordered.enumerated() {
            item.sortOrder = index
        }
    }
}

private struct HabitManagerRow: View {
    @Bindable var item: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Habit name", text: $item.title)
                .font(.custom("Avenir Next", size: 16))
            Stepper("Streak: \(item.streak) days", value: $item.streak, in: 0...365)
                .font(.custom("Avenir Next", size: 12))
        }
        .padding(.vertical, 6)
    }
}

private struct AddPrioritySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var detail = ""
    @State private var isSmallWin = true
    @State private var selectedGoal: Goal?

    let goals: [Goal]
    let onAdd: (String, String, Bool, Goal?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Priority title", text: $title)
                    TextField("Detail (optional)", text: $detail)
                    Toggle("Tiny win", isOn: $isSmallWin)
                    if !goals.isEmpty {
                        GoalSelectionMenu(
                            goals: goals,
                            selectedGoal: selectedGoal,
                            onSelect: { selectedGoal = $0 }
                        )
                    }
                }
            }
            .navigationTitle("Add priority")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(title, detail, isSmallWin, selectedGoal)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AddHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var streak = 1

    let onAdd: (String, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Habit title", text: $title)
                    Stepper("Streak start: \(streak) days", value: $streak, in: 0...365)
                }
            }
            .navigationTitle("Add habit")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(title, streak)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var type: AddType = .priority
    @State private var title = ""
    @State private var detail = ""
    @State private var isSmallWin = true
    @State private var streak = 1
    @State private var selectedGoal: Goal?

    let goals: [Goal]
    let onAddPriority: (String, String, Bool, Goal?) -> Void
    let onAddHabit: (String, Int) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(AddType.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField(type == .priority ? "Priority title" : "Habit title", text: $title)

                    if type == .priority {
                        TextField("Detail (optional)", text: $detail)
                        Toggle("Tiny win", isOn: $isSmallWin)
                        if !goals.isEmpty {
                            GoalSelectionMenu(
                                goals: goals,
                                selectedGoal: selectedGoal,
                                onSelect: { selectedGoal = $0 }
                            )
                        } else {
                            Text("Create a goal to attach priorities.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Stepper("Streak start: \(streak) days", value: $streak, in: 0...365)
                    }
                }
            }
            .navigationTitle("Quick add")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        handleAdd()
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleAdd() {
        switch type {
        case .priority:
            onAddPriority(title, detail, isSmallWin, selectedGoal)
        case .habit:
            onAddHabit(title, streak)
        }
        dismiss()
    }
}

private struct FocusTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMinutes = 25
    @State private var remainingSeconds = 25 * 60
    @State private var isRunning = false
    @State private var didLogSession = false

    let tasks: [TaskItem]
    let onComplete: (Int, TaskItem?) -> Void

    @State private var selectedTask: TaskItem?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Focus session")
                    .font(.custom("Avenir Next", size: 22))
                    .fontWeight(.bold)
                    .foregroundStyle(TodayTheme.ink)

                ZStack {
                    FocusRing(progress: progress)
                    Text(timeString)
                        .font(.custom("Avenir Next", size: 28))
                        .fontWeight(.bold)
                        .foregroundStyle(TodayTheme.ink)
                }

                FocusTaskPicker(tasks: tasks, selectedTask: $selectedTask)

                Picker("Length", selection: $selectedMinutes) {
                    Text("15 min").tag(15)
                    Text("25 min").tag(25)
                    Text("45 min").tag(45)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button(isRunning ? "Pause" : "Start") {
                        isRunning.toggle()
                        AppHaptics.tap()
                    }
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(TodayTheme.primaryButton)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Button("Reset") {
                        resetTimer()
                        AppHaptics.tap()
                    }
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(TodayTheme.ink)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(TodayTheme.secondaryButton)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Spacer()
            }
            .padding(20)
            .onReceive(timer) { _ in
                tick()
            }
            .onChange(of: selectedMinutes) { newValue in
                if !isRunning {
                    remainingSeconds = newValue * 60
                    didLogSession = false
                }
            }
            .navigationTitle("Focus")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        logSessionIfNeeded()
                        dismiss()
                    }
                }
            }
        }
    }

    private var progress: Double {
        let total = Double(selectedMinutes * 60)
        guard total > 0 else { return 0 }
        return 1 - (Double(remainingSeconds) / total)
    }

    private var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func tick() {
        guard isRunning, remainingSeconds > 0 else { return }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            isRunning = false
            onComplete(selectedMinutes, selectedTask)
            didLogSession = true
            AppHaptics.success()
        }
    }

    private func resetTimer() {
        isRunning = false
        remainingSeconds = selectedMinutes * 60
        didLogSession = false
    }

    private func logSessionIfNeeded() {
        guard !didLogSession else { return }
        let totalSeconds = selectedMinutes * 60
        let elapsedSeconds = max(0, totalSeconds - remainingSeconds)
        let elapsedMinutes = elapsedSeconds / 60
        guard elapsedMinutes > 0 else { return }
        onComplete(elapsedMinutes, selectedTask)
        didLogSession = true
    }
}

private struct FocusTaskPicker: View {
    let tasks: [TaskItem]
    @Binding var selectedTask: TaskItem?

    var body: some View {
        Menu {
            Button("No task") {
                selectedTask = nil
            }

            if !tasks.isEmpty {
                Divider()
            }

            ForEach(tasks) { task in
                Button(task.title) {
                    selectedTask = task
                }
            }
        } label: {
            HStack {
                Text(selectedTask?.title ?? "Attach to task")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(TodayTheme.ink)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(TodayTheme.inkSoft)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(TodayTheme.secondaryButton)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(tasks.isEmpty)
    }
}

private struct FocusRing: View {
    let progress: Double

    var body: some View {
        let clamped = min(max(progress, 0), 1)

        ZStack {
            Circle()
                .stroke(TodayTheme.ringTrack, lineWidth: 14)
            Circle()
                .trim(from: 0, to: max(0.02, clamped))
                .stroke(
                    TodayTheme.ringGradient,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 180, height: 180)
    }
}

private struct PriorityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: DailyPriority
    let goals: [Goal]
    let onDelete: (DailyPriority) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $item.title)
                    TextField("Detail", text: $item.detail)
                    Toggle("Tiny win", isOn: $item.isSmallWin)
                    Toggle("Completed", isOn: $item.isCompleted)

                    if !goals.isEmpty {
                        GoalSelectionMenu(
                            goals: goals,
                            selectedGoal: item.goal,
                            onSelect: { item.goal = $0 }
                        )
                    } else {
                        Text("Create a goal to attach priorities.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Delete priority", role: .destructive) {
                        onDelete(item)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Priority")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct HabitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: Habit
    let onDelete: (Habit) -> Void
    let onProgressChange: () -> Void

    @State private var permissionDenied = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Overview") {
                    HStack {
                        Text("Progress")
                        Spacer()
                        Text("\(Int(item.progress * 100))%")
                            .fontWeight(.semibold)
                    }
                    ProgressBar(progress: item.progress)
                }

                Section("Details") {
                    TextField("Habit name", text: $item.title)
                    Stepper("Streak: \(item.streak) days", value: $item.streak, in: 0...365)
                    Toggle("Completed today", isOn: Binding(
                        get: { item.progress >= 1 },
                        set: { newValue in
                            item.progress = newValue ? 1 : 0
                            onProgressChange()
                        }
                    ))
                }

                Section("Schedule") {
                    Text("Active days")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(.secondary)
                    WeekdayPicker(selectedDays: Binding(
                        get: { item.scheduleDays },
                        set: { item.scheduleDays = $0.sorted() }
                    ))
                }

                Section("Reminder") {
                    Toggle("Enable reminders", isOn: $item.reminderEnabled)

                    DatePicker("Time", selection: Binding(
                        get: { reminderTime },
                        set: { updateReminderTime($0) }
                    ), displayedComponents: .hourAndMinute)
                    .disabled(!item.reminderEnabled)

                    if permissionDenied {
                        Text("Notifications are disabled. Enable them in Settings to receive reminders.")
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Delete habit", role: .destructive) {
                        onDelete(item)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Habit")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: item.reminderEnabled) { newValue in
                handleReminderToggle(newValue)
            }
            .onChange(of: item.scheduleDays) { _ in
                scheduleHabitReminderIfNeeded()
            }
            .onChange(of: item.reminderHour) { _ in
                scheduleHabitReminderIfNeeded()
            }
            .onChange(of: item.reminderMinute) { _ in
                scheduleHabitReminderIfNeeded()
            }
            .onChange(of: item.title) { _ in
                scheduleHabitReminderIfNeeded()
            }
        }
    }

    private var reminderTime: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = item.reminderHour
        components.minute = item.reminderMinute
        return calendar.date(from: components) ?? Date()
    }

    private func updateReminderTime(_ date: Date) {
        let calendar = Calendar.current
        item.reminderHour = calendar.component(.hour, from: date)
        item.reminderMinute = calendar.component(.minute, from: date)
    }

    private func handleReminderToggle(_ isOn: Bool) {
        Task {
            if isOn {
                let granted = await NotificationManager.requestAuthorization()
                if granted {
                    permissionDenied = false
                    await NotificationManager.scheduleHabitReminders(
                        habitID: item.id,
                        title: item.title,
                        days: item.scheduleDays,
                        hour: item.reminderHour,
                        minute: item.reminderMinute
                    )
                } else {
                    item.reminderEnabled = false
                    permissionDenied = true
                }
            } else {
                await NotificationManager.clearHabitReminders(habitID: item.id)
            }
        }
    }

    private func scheduleHabitReminderIfNeeded() {
        guard item.reminderEnabled else { return }
        Task {
            await NotificationManager.scheduleHabitReminders(
                habitID: item.id,
                title: item.title,
                days: item.scheduleDays,
                hour: item.reminderHour,
                minute: item.reminderMinute
            )
        }
    }
}

private struct WeekdayPicker: View {
    @Binding var selectedDays: [Int]

    private let days = [
        WeekdayOption(id: 1, short: "M"),
        WeekdayOption(id: 2, short: "T"),
        WeekdayOption(id: 3, short: "W"),
        WeekdayOption(id: 4, short: "T"),
        WeekdayOption(id: 5, short: "F"),
        WeekdayOption(id: 6, short: "S"),
        WeekdayOption(id: 7, short: "S")
    ]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(days) { day in
                Button(action: { toggle(day.id) }) {
                    Text(day.short)
                        .font(.custom("Avenir Next", size: 12))
                        .fontWeight(.semibold)
                        .foregroundStyle(isSelected(day.id) ? .white : TodayTheme.ink)
                        .frame(width: 28, height: 28)
                        .background(isSelected(day.id) ? TodayTheme.accent : TodayTheme.badgeStrong)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func isSelected(_ id: Int) -> Bool {
        selectedDays.contains(id)
    }

    private func toggle(_ id: Int) {
        if isSelected(id) {
            selectedDays.removeAll { $0 == id }
        } else {
            selectedDays.append(id)
        }
    }
}

private struct WeekdayOption: Identifiable {
    let id: Int
    let short: String
}

private enum AddType: String, CaseIterable, Identifiable {
    case priority
    case habit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .priority:
            return "Priority"
        case .habit:
            return "Habit"
        }
    }
}

private enum ActiveSheet: Identifiable {
    case progress
    case quickAdd
    case focus
    case focusHistory
    case priorityManager
    case habitManager
    case recap

    var id: Int {
        switch self {
        case .progress:
            return 0
        case .quickAdd:
            return 1
        case .focus:
            return 2
        case .focusHistory:
            return 3
        case .priorityManager:
            return 4
        case .habitManager:
            return 5
        case .recap:
            return 6
        }
    }
}

private struct WeeklyQuest: Identifiable {
    let id: String
    let title: String
    let detail: String
    let progress: Int
    let target: Int
    let rewardXP: Int
    let isClaimed: Bool

    var isComplete: Bool {
        progress >= target
    }

    var canClaim: Bool {
        isComplete && !isClaimed
    }

    var progressRatio: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(progress) / Double(target))
    }
}

private enum TodayTheme {
    static let backgroundTop = Color(red: 0.97, green: 0.94, blue: 0.90)
    static let backgroundBottom = Color(red: 0.94, green: 0.98, blue: 0.98)
    static let glow = Color(red: 0.93, green: 0.76, blue: 0.58, opacity: 0.45)
    static let panelSoft = Color(red: 0.87, green: 0.93, blue: 0.92, opacity: 0.6)
    static let cardSurface = AppPalette.card
    static let cardGradient = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.97, blue: 0.94),
            Color(red: 0.96, green: 0.98, blue: 0.97)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardBorder = Color(red: 0.85, green: 0.87, blue: 0.88, opacity: 0.6)
    static let ink = AppPalette.ink
    static let inkSoft = AppPalette.inkSoft
    static let accent = Color(red: 0.19, green: 0.55, blue: 0.50)
    static let highlight = Color(red: 0.92, green: 0.42, blue: 0.32)
    static let badgeSoft = Color(red: 0.95, green: 0.86, blue: 0.76)
    static let badgeStrong = Color(red: 0.86, green: 0.93, blue: 0.90)
    static let ringTrack = Color(red: 0.88, green: 0.90, blue: 0.92)
    static let ringGradient = AngularGradient(
        colors: [
            Color(red: 0.22, green: 0.62, blue: 0.54),
            Color(red: 0.96, green: 0.58, blue: 0.32)
        ],
        center: .center
    )
    static let progressFill = LinearGradient(
        colors: [
            Color(red: 0.23, green: 0.64, blue: 0.55),
            Color(red: 0.98, green: 0.70, blue: 0.42)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    static let pillBackground = Color(red: 0.94, green: 0.93, blue: 0.90)
    static let primaryButton = LinearGradient(
        colors: [
            Color(red: 0.20, green: 0.58, blue: 0.51),
            Color(red: 0.18, green: 0.45, blue: 0.40)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let secondaryButton = Color(red: 0.94, green: 0.90, blue: 0.84)
    static let shadow = AppPalette.shadow
}
