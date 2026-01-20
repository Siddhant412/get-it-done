import SwiftUI
import UIKit
import Combine

struct TodayView: View {
    private let maxPriorities = 3

    @State private var animatedProgress: Double = 0.0
    @State private var activeSheet: ActiveSheet?
    @State private var streakProtected = false
    @State private var streakDays: Int = 14
    @State private var focusMinutes: Int = 38

    @State private var topPriorities: [PriorityItem] = [
        PriorityItem(title: "Ship onboarding flow", detail: "Build | 40 min", isSmallWin: false, isCompleted: false),
        PriorityItem(title: "LeetCode: 1 medium problem", detail: "DSA | 25 min", isSmallWin: true, isCompleted: false),
        PriorityItem(title: "Read 20 min", detail: "Focus | 20 min", isSmallWin: true, isCompleted: false)
    ]
    @State private var habits: [HabitItem] = [
        HabitItem(title: "Gym", streak: 6, progress: 0.8),
        HabitItem(title: "Journal", streak: 12, progress: 0.6),
        HabitItem(title: "LeetCode", streak: 9, progress: 0.5),
        HabitItem(title: "Hydration", streak: 15, progress: 0.7)
    ]

    var body: some View {
        ZStack {
            TodayBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    HeaderRow(dateText: dateText)

                    HeroCard(
                        progress: animatedProgress,
                        streakDays: streakDays,
                        focusMinutes: focusMinutes,
                        onProgressTap: { activeSheet = .progress }
                    )

                    SectionHeader(
                        title: "Top 3 priorities",
                        actionTitle: "Edit",
                        action: { activeSheet = .priorityManager }
                    )
                    ForEach(priorityIndices, id: \.self) { index in
                        PriorityRow(item: $topPriorities[index])
                    }

                    SectionHeader(
                        title: "Habits to keep alive",
                        actionTitle: "All",
                        action: { activeSheet = .habitManager }
                    )
                    HabitRow(items: $habits)

                    MomentumCard(
                        progress: momentumProgress,
                        isProtected: streakProtected,
                        onToggleProtection: toggleStreakProtection
                    )

                    QuickActionsCard(
                        onStartFocus: { activeSheet = .focus },
                        onQuickAdd: { activeSheet = .quickAdd }
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
        }
        .onChange(of: todayProgress) { newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedProgress = newValue
            }
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
                    onAddPriority: addPriority,
                    onAddHabit: addHabit
                )
            case .focus:
                FocusTimerView(onComplete: addFocusMinutes)
            case .priorityManager:
                PriorityManagerView(items: $topPriorities)
            case .habitManager:
                HabitManagerView(items: $habits)
            }
        }
    }

    private var priorityIndices: [Int] {
        Array(topPriorities.indices.prefix(maxPriorities))
    }

    private var priorityItemsForProgress: [PriorityItem] {
        priorityIndices.map { topPriorities[$0] }
    }

    private var priorityCompletionCount: Int {
        priorityItemsForProgress.filter { $0.isCompleted }.count
    }

    private var todayProgress: Double {
        let priorityCount = priorityItemsForProgress.count
        let habitCount = habits.count
        let totalSlots = Double(priorityCount + habitCount)
        guard totalSlots > 0 else { return 0 }

        let priorityScore = Double(priorityCompletionCount)
        let habitScore = habits.reduce(0.0) { $0 + $1.progress }
        let rawProgress = (priorityScore + habitScore) / totalSlots
        return min(max(rawProgress, 0), 1)
    }

    private var momentumProgress: Double {
        let boost = streakProtected ? 0.08 : 0.0
        return min(1, max(0, todayProgress + boost))
    }

    private func addPriority(title: String, detail: String, isSmallWin: Bool) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)

        topPriorities.insert(
            PriorityItem(
                title: trimmedTitle,
                detail: trimmedDetail.isEmpty ? "Focus | 20 min" : trimmedDetail,
                isSmallWin: isSmallWin,
                isCompleted: false
            ),
            at: 0
        )
        Haptics.success()
    }

    private func addHabit(title: String, streak: Int) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        habits.insert(
            HabitItem(title: trimmedTitle, streak: max(0, min(streak, 365)), progress: 0),
            at: 0
        )
        Haptics.success()
    }

    private func addFocusMinutes(_ minutes: Int) {
        focusMinutes += minutes
        Haptics.success()
    }

    private func toggleStreakProtection() {
        streakProtected.toggle()
        Haptics.tap()
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
    @Binding var item: PriorityItem

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
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
            }
            .padding(14)
            .background(TodayTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func toggle() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            item.isCompleted.toggle()
        }
        Haptics.tap()
    }
}

private struct HabitRow: View {
    @Binding var items: [HabitItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach($items) { $item in
                    HabitCard(item: $item)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct HabitCard: View {
    @Binding var item: HabitItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.title)
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.semibold)
                .foregroundStyle(TodayTheme.ink)

            Text("\(item.streak)-day streak")
                .font(.custom("Avenir Next", size: 12))
                .foregroundStyle(TodayTheme.inkSoft)

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
            .contextMenu {
                Button("Tiny check-in") {
                    updateProgress(to: 0.35)
                }
                if item.progress > 0 {
                    Button("Reset today") {
                        updateProgress(to: 0)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 160)
        .background(TodayTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TodayTheme.shadow, radius: 8, x: 0, y: 5)
    }

    private var statusLabel: String {
        if item.progress >= 1 {
            return "Done"
        }
        if item.progress > 0 {
            return "Tiny done"
        }
        return "Check in"
    }

    private var statusIcon: String {
        if item.progress >= 1 {
            return "checkmark.circle.fill"
        }
        if item.progress > 0 {
            return "bolt.fill"
        }
        return "circle"
    }

    private var statusBackground: Color {
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
        let target: Double = item.progress >= 1 ? 0 : 1
        updateProgress(to: target)
    }

    private func updateProgress(to value: Double) {
        withAnimation(.easeInOut(duration: 0.35)) {
            item.progress = min(max(value, 0), 1)
        }
        Haptics.tap()
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

private struct MomentumCard: View {
    let progress: Double
    let isProtected: Bool
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
            }

            Text("You are close to your best streak. One small task keeps the chain unbroken.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(TodayTheme.inkSoft)
            ProgressBar(progress: progress)
        }
        .padding(16)
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

private struct ProgressDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let progress: Double
    let priorities: [PriorityItem]
    let habits: [HabitItem]

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
    @Binding var items: [PriorityItem]

    var body: some View {
        NavigationStack {
            List {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Title", text: $item.title)
                            .font(.custom("Avenir Next", size: 16))
                        TextField("Detail", text: $item.detail)
                            .font(.custom("Avenir Next", size: 12))
                            .foregroundStyle(.secondary)
                        Toggle("Tiny win", isOn: $item.isSmallWin)
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { items.remove(atOffsets: $0) }
                .onMove { items.move(fromOffsets: $0, toOffset: $1) }
            }
            .navigationTitle("Edit priorities")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }
}

private struct HabitManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var items: [HabitItem]

    var body: some View {
        NavigationStack {
            List {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Habit name", text: $item.title)
                            .font(.custom("Avenir Next", size: 16))
                        Stepper("Streak: \(item.streak) days", value: $item.streak, in: 0...365)
                            .font(.custom("Avenir Next", size: 12))
                    }
                    .padding(.vertical, 6)
                }
                .onDelete { items.remove(atOffsets: $0) }
                .onMove { items.move(fromOffsets: $0, toOffset: $1) }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
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

    let onAddPriority: (String, String, Bool) -> Void
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
            onAddPriority(title, detail, isSmallWin)
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

    let onComplete: (Int) -> Void

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
                        Haptics.tap()
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
                        Haptics.tap()
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
                }
            }
            .navigationTitle("Focus")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
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
            onComplete(selectedMinutes)
            Haptics.success()
        }
    }

    private func resetTimer() {
        isRunning = false
        remainingSeconds = selectedMinutes * 60
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

private struct PriorityItem: Identifiable {
    let id = UUID()
    var title: String
    var detail: String
    var isSmallWin: Bool
    var isCompleted: Bool
}

private struct HabitItem: Identifiable {
    let id = UUID()
    var title: String
    var streak: Int
    var progress: Double
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
    case priorityManager
    case habitManager

    var id: Int {
        switch self {
        case .progress:
            return 0
        case .quickAdd:
            return 1
        case .focus:
            return 2
        case .priorityManager:
            return 3
        case .habitManager:
            return 4
        }
    }
}

private enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private enum TodayTheme {
    static let backgroundTop = Color(red: 0.97, green: 0.94, blue: 0.90)
    static let backgroundBottom = Color(red: 0.94, green: 0.98, blue: 0.98)
    static let glow = Color(red: 0.93, green: 0.76, blue: 0.58, opacity: 0.45)
    static let panelSoft = Color(red: 0.87, green: 0.93, blue: 0.92, opacity: 0.6)
    static let cardSurface = Color(red: 0.99, green: 0.98, blue: 0.97, opacity: 0.95)
    static let cardGradient = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.97, blue: 0.94),
            Color(red: 0.96, green: 0.98, blue: 0.97)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let cardBorder = Color(red: 0.85, green: 0.87, blue: 0.88, opacity: 0.6)
    static let ink = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let inkSoft = Color(red: 0.38, green: 0.40, blue: 0.44)
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
    static let shadow = Color(red: 0.15, green: 0.16, blue: 0.18, opacity: 0.08)
}
