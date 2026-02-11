import SwiftUI

struct OverdueView: View {
    @EnvironmentObject var appState: AppState
    @State private var groupBy: GroupBy = .priority

    enum GroupBy: String, CaseIterable {
        case priority = "Priority"
        case project = "Project"
        case daysOverdue = "Days Overdue"
    }

    var body: some View {
        NavigationStack {
            Group {
                if appState.overdueTasks.isEmpty {
                    allClearView
                } else {
                    overdueContent
                }
            }
            .navigationTitle("Overdue")
            .refreshable { await appState.performFullSync() }
            .toolbar {
                if !appState.overdueTasks.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Picker("Group by", selection: $groupBy) {
                                ForEach(GroupBy.allCases, id: \.self) { g in
                                    Text(g.rawValue).tag(g)
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
        }
    }

    // MARK: - All Clear

    private var allClearView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("All Clear!")
                .font(.title2)
                .fontWeight(.bold)

            Text("No overdue tasks. Great job keeping up!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Content

    private var overdueContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Alert Banner
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(appState.overdueTasks.count) overdue tasks")
                            .font(.headline)
                        Text("Oldest: \(oldestOverdueDays) days ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)

                // Grouped Content
                switch groupBy {
                case .priority:
                    groupedByPriority
                case .project:
                    groupedByProject
                case .daysOverdue:
                    groupedByDaysOverdue
                }
            }
            .padding(.vertical)
        }
    }

    private var oldestOverdueDays: Int {
        appState.overdueTasks.compactMap { $0.daysOverdue }.max() ?? 0
    }

    // MARK: - Grouped by Priority

    private var groupedByPriority: some View {
        ForEach([4, 3, 2, 1], id: \.self) { priority in
            let tasks = appState.overdueTasks.filter { $0.priority == priority }
            if !tasks.isEmpty {
                overdueSection(
                    title: "\(AppTheme.priorityLabel(for: priority)) — \(tasks.count) tasks",
                    tasks: tasks,
                    color: AppTheme.priorityColor(for: priority)
                )
            }
        }
    }

    // MARK: - Grouped by Project

    private var groupedByProject: some View {
        let grouped = Dictionary(grouping: appState.overdueTasks, by: { $0.projectId })

        return ForEach(Array(grouped.keys.sorted()), id: \.self) { projectId in
            if let project = appState.projects.first(where: { $0.id == projectId }),
               let tasks = grouped[projectId] {
                overdueSection(
                    title: "\(project.name) — \(tasks.count) tasks",
                    tasks: tasks,
                    color: AppTheme.projectColor(for: project.color)
                )
            }
        }
    }

    // MARK: - Grouped by Days Overdue

    private var groupedByDaysOverdue: some View {
        let critical = appState.overdueTasks.filter { ($0.daysOverdue ?? 0) > 7 }
        let moderate = appState.overdueTasks.filter { ($0.daysOverdue ?? 0) > 2 && ($0.daysOverdue ?? 0) <= 7 }
        let recent = appState.overdueTasks.filter { ($0.daysOverdue ?? 0) <= 2 }

        return VStack(spacing: 0) {
            if !critical.isEmpty {
                overdueSection(title: "Critical (7+ days)", tasks: critical, color: .red)
            }
            if !moderate.isEmpty {
                overdueSection(title: "Moderate (3-7 days)", tasks: moderate, color: .orange)
            }
            if !recent.isEmpty {
                overdueSection(title: "Recent (1-2 days)", tasks: recent, color: .yellow)
            }
        }
    }

    // MARK: - Section Builder

    private func overdueSection(title: String, tasks: [TodoistTask], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(tasks) { task in
                    OverdueTaskRow(task: task, projectName: projectName(for: task.projectId))
                    if task.id != tasks.last?.id {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }

    private func projectName(for id: String) -> String {
        appState.projects.first { $0.id == id }?.name ?? "Unknown"
    }
}

// MARK: - Overdue Task Row

struct OverdueTaskRow: View {
    let task: TodoistTask
    let projectName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Days overdue badge
            VStack(spacing: 2) {
                Text("\(task.daysOverdue ?? 0)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                Text("days")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.content)
                    .font(.subheadline)

                HStack(spacing: 8) {
                    if let due = task.due {
                        Label(due.displayString, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Text(projectName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            PriorityBadge(priority: task.priority)
        }
        .padding(.vertical, 8)
    }
}
