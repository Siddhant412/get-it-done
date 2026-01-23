import SwiftUI
import SwiftData
import UIKit

struct TasksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse) private var tasks: [TaskItem]
    @Query(sort: \Goal.sortOrder) private var goals: [Goal]

    @State private var activeSheet: TasksSheet?
    @State private var selectedTask: TaskItem?

    var body: some View {
        ZStack {
            TasksBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    TasksHeader(onAdd: { activeSheet = .add })

                    if tasks.isEmpty {
                        EmptyTasksCard(onAdd: { activeSheet = .add })
                    } else {
                        if !inboxTasks.isEmpty {
                            TaskSection(
                                title: "Inbox",
                                subtitle: "Unassigned tasks",
                                tint: TasksTheme.accent,
                                tasks: inboxTasks,
                                onDetail: { selectedTask = $0 }
                            )
                        }

                        ForEach(goals) { goal in
                            let goalTasks = tasksForGoal(goal)
                            if !goalTasks.isEmpty {
                                TaskSection(
                                    title: goal.title,
                                    subtitle: goal.category,
                                    tint: TasksTheme.tint(for: goal),
                                    tasks: goalTasks,
                                    onDetail: { selectedTask = $0 }
                                )
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
            case .add:
                TaskEditorView(goals: goals, onSave: addTask)
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task, goals: goals, onDelete: deleteTask)
        }
    }

    private var inboxTasks: [TaskItem] {
        tasks.filter { $0.goal == nil }
    }

    private func tasksForGoal(_ goal: Goal) -> [TaskItem] {
        tasks.filter { $0.goal?.id == goal.id }
    }

    private func seedIfNeeded() {
        guard tasks.isEmpty else { return }
        let sampleTitles = [
            "Define habit streak freeze rules",
            "Draft streak reward visuals",
            "Review heatmap intensity colors"
        ]

        for (index, title) in sampleTitles.enumerated() {
            let task = TaskItem(title: title, priority: index, createdAt: Date())
            if let firstGoal = goals.first, index == 0 {
                task.goal = firstGoal
            }
            modelContext.insert(task)
        }
    }

    private func addTask(_ draft: TaskDraft) {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let task = TaskItem(
            title: trimmedTitle,
            detail: draft.detail.trimmingCharacters(in: .whitespacesAndNewlines),
            isCompleted: false,
            dueDate: draft.hasDueDate ? draft.dueDate : nil,
            priority: draft.priority,
            createdAt: Date(),
            goal: draft.goal
        )
        modelContext.insert(task)
    }

    private func deleteTask(_ task: TaskItem) {
        modelContext.delete(task)
    }
}

private struct TasksBackground: View {
    var body: some View {
        LinearGradient(
            colors: [TasksTheme.backgroundTop, TasksTheme.backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(TasksTheme.glow)
                .frame(width: 220, height: 140)
                .offset(x: -60, y: -60)
        }
    }
}

private struct TasksHeader: View {
    let onAdd: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tasks")
                    .font(.custom("Avenir Next", size: 32))
                    .fontWeight(.bold)
                    .foregroundStyle(TasksTheme.ink)
                Text("Keep the pipeline moving.")
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundStyle(TasksTheme.inkSoft)
            }
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 38, height: 38)
                    .background(TasksTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }
}

private struct EmptyTasksCard: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No tasks yet")
                .font(.custom("Avenir Next", size: 18))
                .fontWeight(.semibold)
                .foregroundStyle(TasksTheme.ink)
            Text("Add the next actionable step for your goals.")
                .font(.custom("Avenir Next", size: 14))
                .foregroundStyle(TasksTheme.inkSoft)
            Button("Add task", action: onAdd)
                .font(.custom("Avenir Next", size: 14))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(TasksTheme.primary)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(TasksTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TasksTheme.shadow, radius: 8, x: 0, y: 5)
    }
}

private struct TaskSection: View {
    let title: String
    let subtitle: String
    let tint: Color
    let tasks: [TaskItem]
    let onDetail: (TaskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Avenir Next", size: 18))
                        .fontWeight(.semibold)
                        .foregroundStyle(TasksTheme.ink)
                    Text(subtitle)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(TasksTheme.inkSoft)
                }
                Spacer()
                Text("\(tasks.filter { $0.isCompleted }.count)/\(tasks.count)")
                    .font(.custom("Avenir Next", size: 12))
                    .foregroundStyle(TasksTheme.inkSoft)
            }

            ForEach(tasks) { task in
                TaskCard(task: task, tint: tint, onDetail: { onDetail(task) })
            }
        }
    }
}

private struct TaskCard: View {
    @Bindable var task: TaskItem
    let tint: Color
    let onDetail: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? tint : TasksTheme.inkSoft)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.semibold)
                    .foregroundStyle(task.isCompleted ? TasksTheme.inkSoft : TasksTheme.ink)
                    .strikethrough(task.isCompleted, color: TasksTheme.inkSoft)

                if !task.detail.isEmpty {
                    Text(task.detail)
                        .font(.custom("Avenir Next", size: 12))
                        .foregroundStyle(TasksTheme.inkSoft)
                }

                HStack(spacing: 8) {
                    if let dueDate = task.dueDate {
                        TaskMetaPill(text: "Due \(TaskDateFormatter.short.string(from: dueDate))")
                    }
                    TaskMetaPill(text: "P\(task.priority)")
                }
            }

            Spacer()

            Button(action: onDetail) {
                Image(systemName: "info.circle")
                    .foregroundStyle(TasksTheme.inkSoft)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(TasksTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: TasksTheme.shadow, radius: 8, x: 0, y: 5)
    }

    private func toggle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            task.isCompleted.toggle()
        }
        TaskHaptics.tap()
    }
}

private struct TaskMetaPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.custom("Avenir Next", size: 11))
            .foregroundStyle(TasksTheme.inkSoft)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TasksTheme.pill)
            .clipShape(Capsule())
    }
}

private struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var detail = ""
    @State private var priority = 1
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var selectedGoal: Goal?

    let goals: [Goal]
    let onSave: (TaskDraft) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Task title", text: $title)
                    TextField("Detail (optional)", text: $detail)
                    Stepper("Priority: \(priority)", value: $priority, in: 1...5)
                }

                Section("Schedule") {
                    Toggle("Set due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    }
                }

                Section("Goal") {
                    if !goals.isEmpty {
                        GoalPickerRow(
                            goals: goals,
                            selectedGoal: selectedGoal,
                            onSelect: { selectedGoal = $0 }
                        )
                    } else {
                        Text("Create a goal to attach tasks.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New task")
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
        let draft = TaskDraft(
            title: title,
            detail: detail,
            priority: priority,
            hasDueDate: hasDueDate,
            dueDate: dueDate,
            goal: selectedGoal
        )
        onSave(draft)
        dismiss()
    }
}

private struct TaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var task: TaskItem
    let goals: [Goal]
    let onDelete: (TaskItem) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Task title", text: $task.title)
                    TextField("Detail", text: $task.detail)
                    Toggle("Completed", isOn: $task.isCompleted)
                    Stepper("Priority: \(task.priority)", value: $task.priority, in: 1...5)
                }

                Section("Schedule") {
                    if let dueDate = task.dueDate {
                        DatePicker("Due date", selection: Binding(
                            get: { dueDate },
                            set: { task.dueDate = $0 }
                        ), displayedComponents: .date)
                        Button("Clear due date") {
                            task.dueDate = nil
                        }
                        .foregroundStyle(.red)
                    } else {
                        Button("Add due date") {
                            task.dueDate = Date()
                        }
                    }
                }

                Section("Goal") {
                    if !goals.isEmpty {
                        GoalPickerRow(
                            goals: goals,
                            selectedGoal: task.goal,
                            onSelect: { task.goal = $0 }
                        )
                    } else {
                        Text("Create a goal to attach tasks.")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Delete task", role: .destructive) {
                        onDelete(task)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Task")
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

private struct GoalPickerRow: View {
    let goals: [Goal]
    let selectedGoal: Goal?
    let onSelect: (Goal?) -> Void

    var body: some View {
        Menu {
            Button("Inbox") {
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
                Text(selectedGoal?.title ?? "Inbox")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TaskDraft {
    let title: String
    let detail: String
    let priority: Int
    let hasDueDate: Bool
    let dueDate: Date
    let goal: Goal?
}

private enum TasksSheet: Identifiable {
    case add
    var id: Int { 0 }
}

private enum TaskDateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}

private enum TaskHaptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private enum TasksTheme {
    static let backgroundTop = Color(red: 0.92, green: 0.95, blue: 0.98)
    static let backgroundBottom = Color(red: 0.97, green: 0.98, blue: 0.95)
    static let glow = Color(red: 0.74, green: 0.86, blue: 0.94, opacity: 0.5)
    static let card = Color(red: 0.99, green: 0.98, blue: 0.97)
    static let pill = Color(red: 0.92, green: 0.94, blue: 0.97)
    static let ink = Color(red: 0.15, green: 0.16, blue: 0.18)
    static let inkSoft = Color(red: 0.38, green: 0.40, blue: 0.44)
    static let primary = Color(red: 0.24, green: 0.46, blue: 0.64)
    static let accent = Color(red: 0.29, green: 0.60, blue: 0.68)
    static let shadow = Color(red: 0.15, green: 0.16, blue: 0.18, opacity: 0.08)

    static func tint(for goal: Goal) -> Color {
        Color(hex: goal.colorHex) ?? accent
    }
}
