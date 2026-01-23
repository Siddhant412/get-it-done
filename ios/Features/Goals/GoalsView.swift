import SwiftUI
import SwiftData

struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Goal.sortOrder) private var goals: [Goal]

    @State private var activeSheet: GoalsSheet?

    var body: some View {
        ZStack {
            GoalsBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    GoalsHeader(onAdd: { activeSheet = .addGoal })

                    if goals.isEmpty {
                        EmptyGoalsCard(onAdd: { activeSheet = .addGoal })
                    } else {
                        ForEach(goals) { goal in
                            NavigationLink(destination: GoalDetailView(goal: goal)) {
                                GoalCard(goal: goal)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteGoal(goal)
                                } label: {
                                    Text("Delete goal")
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            seedIfNeeded()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addGoal:
                GoalEditorView(onSave: addGoal)
            }
        }
    }

    private func seedIfNeeded() {
        guard goals.isEmpty else { return }

        let goalA = Goal(
            title: "DSA Mastery",
            iconName: "function",
            colorHex: "1F6F8B",
            targetDate: Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date(),
            priority: 1,
            whyNote: "Crack interviews with consistent practice.",
            category: "Learning",
            sortOrder: 0
        )
        let milestonesA = [
            "Finish 50 medium problems",
            "Solve 10 dynamic programming sets",
            "Mock interview: 3 rounds"
        ]
        for (index, title) in milestonesA.enumerated() {
            let milestone = Milestone(title: title, sortOrder: index, goal: goalA)
            goalA.milestones.append(milestone)
        }
        modelContext.insert(goalA)

        let goalB = Goal(
            title: "Build Skillevate MVP",
            iconName: "sparkles",
            colorHex: "C57B57",
            targetDate: Calendar.current.date(byAdding: .day, value: 45, to: Date()) ?? Date(),
            priority: 2,
            whyNote: "Launch to early users this month.",
            category: "Product",
            sortOrder: 1
        )
        let milestonesB = [
            "Ship onboarding",
            "Launch focus timer",
            "Release TestFlight build"
        ]
        for (index, title) in milestonesB.enumerated() {
            let milestone = Milestone(title: title, sortOrder: index, goal: goalB)
            goalB.milestones.append(milestone)
        }
        modelContext.insert(goalB)
    }

    private func addGoal(_ draft: GoalDraft) {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let nextOrder = (goals.map(\.sortOrder).max() ?? -1) + 1
        let goal = Goal(
            title: trimmedTitle,
            iconName: draft.iconName,
            colorHex: draft.colorHex,
            startDate: Date(),
            targetDate: draft.targetDate,
            priority: draft.priority,
            whyNote: draft.whyNote.trimmingCharacters(in: .whitespacesAndNewlines),
            category: draft.category.trimmingCharacters(in: .whitespacesAndNewlines),
            sortOrder: nextOrder
        )
        modelContext.insert(goal)
    }

    private func deleteGoal(_ goal: Goal) {
        modelContext.delete(goal)
    }
}

private struct GoalsBackground: View {
    var body: some View {
        LinearGradient(
            colors: [GoalsTheme.backgroundTop, GoalsTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(GoalsTheme.glow)
                .frame(width: 200, height: 140)
                .offset(x: 60, y: -50)
        }
    }
}

private struct GoalsHeader: View {
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Goals")
                    .font(.custom("Avenir Next", size: 32))
                    .fontWeight(.bold)
                    .foregroundStyle(GoalsTheme.ink)
                Text("Plan the wins that matter.")
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(GoalsTheme.inkSoft)
            }
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(GoalsTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }
}

private struct EmptyGoalsCard: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Start your first goal")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(GoalsTheme.ink)
            Text("Define a clear outcome and break it into milestones.")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(GoalsTheme.inkSoft)
            Button("Create goal", action: onAdd)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(GoalsTheme.primary)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(GoalsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: GoalsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct GoalCard: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(GoalsTheme.tint(for: goal))
                        .frame(width: 42, height: 42)
                    Image(systemName: goal.iconName)
                        .foregroundStyle(.white)
                        .font(.system(size: 18, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.custom("Avenir Next", size: 18))
                        .fontWeight(.semibold)
                        .foregroundStyle(GoalsTheme.ink)
                    Text(goal.category)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(GoalsTheme.inkSoft)
                }

                Spacer()

                Text("\(Int(goal.completionRatio * 100))%")
                    .font(.custom("Avenir Next", size: 14))
                    .fontWeight(.bold)
                    .foregroundStyle(GoalsTheme.ink)
            }

            GoalProgressBar(progress: goal.completionRatio, tint: GoalsTheme.tint(for: goal))

            HStack {
                Text(goal.completedMilestoneSummary)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(GoalsTheme.inkSoft)
                Spacer()
                Text("Target \(GoalDateFormatter.medium.string(from: goal.targetDate))")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(GoalsTheme.inkSoft)
            }
        }
        .padding(16)
        .background(GoalsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: GoalsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct GoalProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(GoalsTheme.track)
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 8)
        .animation(.easeInOut(duration: 0.3), value: progress)
    }
}

private struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var goal: Goal
    @State private var newMilestoneTitle = ""
    @State private var newTaskTitle = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                GoalDetailHeader(goal: goal)

                if !goal.whyNote.isEmpty {
                    GoalNoteCard(title: "Why this matters", text: goal.whyNote)
                }

                GoalMetaRow(goal: goal)

                Text("Milestones")
                    .font(.custom("Avenir Next", size: 20))
                    .fontWeight(.semibold)
                    .foregroundStyle(GoalsTheme.ink)

                ForEach(sortedMilestones) { milestone in
                    MilestoneRow(milestone: milestone, onDelete: deleteMilestone)
                }

                AddMilestoneRow(
                    title: $newMilestoneTitle,
                    onAdd: addMilestone
                )

                Text("Tasks")
                    .font(.custom("Avenir Next", size: 20))
                    .fontWeight(.semibold)
                    .foregroundStyle(GoalsTheme.ink)
                    .padding(.top, 6)

                if sortedTasks.isEmpty {
                    Text("No tasks yet. Add the next action for this goal.")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(GoalsTheme.inkSoft)
                        .padding(.bottom, 4)
                } else {
                    ForEach(sortedTasks) { task in
                        GoalTaskRow(task: task, onDelete: deleteTask)
                    }
                }

                AddTaskRow(
                    title: $newTaskTitle,
                    onAdd: addTask
                )

                Text("Skill tree")
                    .font(.custom("Avenir Next", size: 20))
                    .fontWeight(.semibold)
                    .foregroundStyle(GoalsTheme.ink)
                    .padding(.top, 6)

                SkillTreeStub()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .navigationTitle(goal.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var sortedMilestones: [Milestone] {
        goal.milestones.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedTasks: [TaskItem] {
        goal.tasks.sorted { $0.createdAt < $1.createdAt }
    }

    private func addMilestone() {
        let trimmed = newMilestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let nextOrder = (sortedMilestones.map(\.sortOrder).max() ?? -1) + 1
        let milestone = Milestone(title: trimmed, sortOrder: nextOrder, goal: goal)
        goal.milestones.append(milestone)
        newMilestoneTitle = ""
    }

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = TaskItem(title: trimmed, createdAt: Date(), goal: goal)
        modelContext.insert(task)
        newTaskTitle = ""
    }

    private func deleteMilestone(_ milestone: Milestone) {
        if let index = goal.milestones.firstIndex(where: { $0.id == milestone.id }) {
            goal.milestones.remove(at: index)
        }
        modelContext.delete(milestone)
        normalizeOrder()
    }

    private func deleteTask(_ task: TaskItem) {
        if let index = goal.tasks.firstIndex(where: { $0.id == task.id }) {
            goal.tasks.remove(at: index)
        }
        modelContext.delete(task)
    }

    private func normalizeOrder() {
        let ordered = sortedMilestones
        for (index, item) in ordered.enumerated() {
            item.sortOrder = index
        }
    }
}

private struct GoalDetailHeader: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(GoalsTheme.tint(for: goal))
                        .frame(width: 52, height: 52)
                    Image(systemName: goal.iconName)
                        .foregroundStyle(.white)
                        .font(.system(size: 22, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(goal.title)
                        .font(.custom("Avenir Next", size: 22))
                        .fontWeight(.bold)
                        .foregroundStyle(GoalsTheme.ink)
                    Text(goal.category)
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundStyle(GoalsTheme.inkSoft)
                }
                Spacer()
            }

            GoalProgressBar(progress: goal.completionRatio, tint: GoalsTheme.tint(for: goal))

            HStack {
                Text(goal.completedMilestoneSummary)
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(GoalsTheme.inkSoft)
                Spacer()
                Text("Target \(GoalDateFormatter.medium.string(from: goal.targetDate))")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(GoalsTheme.inkSoft)
            }
        }
        .padding(16)
        .background(GoalsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: GoalsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct GoalNoteCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.semibold)
                .foregroundStyle(GoalsTheme.ink)
            Text(text)
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(GoalsTheme.inkSoft)
        }
        .padding(16)
        .background(GoalsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: GoalsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct GoalMetaRow: View {
    let goal: Goal

    var body: some View {
        HStack(spacing: 12) {
            GoalMetaPill(title: "Priority", value: "\(goal.priority)")
            GoalMetaPill(title: "Start", value: GoalDateFormatter.short.string(from: goal.startDate))
            GoalMetaPill(title: "Target", value: GoalDateFormatter.short.string(from: goal.targetDate))
        }
    }
}

private struct GoalMetaPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.custom("Avenir Next", size: 10))
                .fontWeight(.semibold)
                .foregroundStyle(GoalsTheme.inkSoft)
            Text(value)
                .font(.custom("Avenir Next", size: 13))
                .fontWeight(.semibold)
                .foregroundStyle(GoalsTheme.ink)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(GoalsTheme.pill)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MilestoneRow: View {
    @Bindable var milestone: Milestone
    let onDelete: (Milestone) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(milestone.isCompleted ? GoalsTheme.primary : GoalsTheme.inkSoft)
            }
            .buttonStyle(.plain)

            TextField("Milestone", text: $milestone.title)
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(GoalsTheme.ink)

            Spacer()

            if milestone.isCompleted {
                Text("Done")
                    .font(.custom("Avenir Next", size: 12))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(GoalsTheme.pill)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(GoalsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: GoalsTheme.shadow, radius: 6, x: 0, y: 4)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(milestone)
            } label: {
                Text("Delete milestone")
            }
        }
    }

    private func toggle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            milestone.isCompleted.toggle()
        }
    }
}

private struct AddMilestoneRow: View {
    @Binding var title: String
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .foregroundStyle(GoalsTheme.primary)
            TextField("Add a milestone", text: $title)
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(GoalsTheme.ink)
            Spacer()
            Button("Add", action: onAdd)
                .font(.custom("Avenir Next", size: 13))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(GoalsTheme.primary)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(GoalsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: GoalsTheme.shadow, radius: 6, x: 0, y: 4)
    }
}

private struct GoalTaskRow: View {
    @Bindable var task: TaskItem
    let onDelete: (TaskItem) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? GoalsTheme.primary : GoalsTheme.inkSoft)
            }
            .buttonStyle(.plain)

            TextField("Task", text: $task.title)
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(GoalsTheme.ink)

            Spacer()

            if task.isCompleted {
                Text("Done")
                    .font(.custom("Avenir Next", size: 12))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(GoalsTheme.pill)
                    .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(GoalsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: GoalsTheme.shadow, radius: 6, x: 0, y: 4)
        .contextMenu {
            Button(role: .destructive) {
                onDelete(task)
            } label: {
                Text("Delete task")
            }
        }
    }

    private func toggle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            task.isCompleted.toggle()
        }
    }
}

private struct AddTaskRow: View {
    @Binding var title: String
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle")
                .foregroundStyle(GoalsTheme.primary)
            TextField("Add a task", text: $title)
                .font(.custom("Avenir Next", size: 15))
                .foregroundStyle(GoalsTheme.ink)
            Spacer()
            Button("Add", action: onAdd)
                .font(.custom("Avenir Next", size: 13))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(GoalsTheme.primary)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(GoalsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: GoalsTheme.shadow, radius: 6, x: 0, y: 4)
    }
}

private struct SkillTreeStub: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Unlock nodes as milestones are completed.")
                .font(.custom("Avenir Next", size: 13))
                .foregroundStyle(GoalsTheme.inkSoft)

            HStack(spacing: 12) {
                SkillNode(isActive: true)
                SkillNode(isActive: true)
                SkillNode(isActive: false)
                SkillNode(isActive: false)
            }
        }
        .padding(16)
        .background(GoalsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: GoalsTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct SkillNode: View {
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? GoalsTheme.primary : GoalsTheme.track)
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .stroke(GoalsTheme.primary.opacity(isActive ? 0 : 0.4), lineWidth: 2)
            )
    }
}

private struct GoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category = "General"
    @State private var whyNote = ""
    @State private var priority = 1
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var iconName = GoalIconOption.defaults.first?.name ?? "flag.fill"
    @State private var colorHex = GoalColorOption.defaults.first?.hex ?? "2F6F6C"

    let onSave: (GoalDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Goal title", text: $title)
                    TextField("Category", text: $category)
                    Stepper("Priority: \(priority)", value: $priority, in: 1...5)
                }

                Section("Why") {
                    TextField("Your why (optional)", text: $whyNote, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Timeline") {
                    DatePicker("Target date", selection: $targetDate, displayedComponents: .date)
                }

                Section("Style") {
                    Picker("Icon", selection: $iconName) {
                        ForEach(GoalIconOption.defaults) { option in
                            Label(option.label, systemImage: option.name)
                                .tag(option.name)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 12) {
                        ForEach(GoalColorOption.defaults) { option in
                            Button {
                                colorHex = option.hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: option.hex) ?? GoalsTheme.primary)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(colorHex == option.hex ? GoalsTheme.ink : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("New goal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        handleSave()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func handleSave() {
        let draft = GoalDraft(
            title: title,
            category: category,
            whyNote: whyNote,
            priority: priority,
            targetDate: targetDate,
            iconName: iconName,
            colorHex: colorHex
        )
        onSave(draft)
        dismiss()
    }
}

private struct GoalDraft {
    let title: String
    let category: String
    let whyNote: String
    let priority: Int
    let targetDate: Date
    let iconName: String
    let colorHex: String
}

private struct GoalIconOption: Identifiable {
    let id = UUID()
    let name: String
    let label: String

    static let defaults: [GoalIconOption] = [
        GoalIconOption(name: "flag.fill", label: "Flag"),
        GoalIconOption(name: "sparkles", label: "Spark"),
        GoalIconOption(name: "bolt.fill", label: "Energy"),
        GoalIconOption(name: "graduationcap.fill", label: "Study"),
        GoalIconOption(name: "heart.fill", label: "Health")
    ]
}

private struct GoalColorOption: Identifiable {
    let id = UUID()
    let hex: String

    static let defaults: [GoalColorOption] = [
        GoalColorOption(hex: "2F6F6C"),
        GoalColorOption(hex: "C57B57"),
        GoalColorOption(hex: "1F6F8B"),
        GoalColorOption(hex: "E38B6D"),
        GoalColorOption(hex: "4F6D7A")
    ]
}

private enum GoalsSheet: Identifiable {
    case addGoal

    var id: Int { 0 }
}

private enum GoalDateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let medium: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

private enum GoalsTheme {
    static let backgroundTop = Color(red: 0.95, green: 0.93, blue: 0.97)
    static let backgroundBottom = Color(red: 0.97, green: 0.98, blue: 0.95)
    static let glow = Color(red: 0.80, green: 0.86, blue: 0.95, opacity: 0.5)
    static let card = Color(red: 0.99, green: 0.98, blue: 0.97)
    static let track = Color(red: 0.88, green: 0.90, blue: 0.92)
    static let pill = Color(red: 0.93, green: 0.90, blue: 0.95)
    static let ink = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let inkSoft = Color(red: 0.38, green: 0.40, blue: 0.44)
    static let primary = Color(red: 0.30, green: 0.43, blue: 0.62)
    static let shadow = Color(red: 0.15, green: 0.16, blue: 0.18, opacity: 0.08)

    static func tint(for goal: Goal) -> Color {
        Color(hex: goal.colorHex) ?? primary
    }
}
