import SwiftUI
import Charts

struct AssigneesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if appState.allCollaborators.isEmpty {
                    noCollaboratorsView
                } else {
                    collaboratorsContent
                }
            }
            .navigationTitle("Team")
            .refreshable { await appState.performFullSync() }
        }
    }

    // MARK: - No Collaborators

    private var noCollaboratorsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Show current user as the only "member"
                if let user = appState.currentUser {
                    soloUserCard(user)
                }

                EmptyStateView(
                    icon: "person.3",
                    title: "No Team Members",
                    message: "Share projects in Todoist to see team workload here. Currently showing your personal stats."
                )
            }
            .padding(.top)
        }
    }

    private func soloUserCard(_ user: TodoistUser) -> some View {
        VStack(spacing: 16) {
            AvatarCircle(initials: user.initials, size: 64, color: .blue)

            Text(user.displayName)
                .font(.title3)
                .fontWeight(.semibold)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(title: "Active", value: "\(appState.tasks.count)", icon: "circle", color: .blue)
                StatCard(title: "Done", value: "\(appState.completedTasks.count)", icon: "checkmark.circle", color: .green)
                StatCard(title: "Overdue", value: "\(appState.overdueTasks.count)", icon: "exclamationmark.triangle",
                         color: appState.overdueTasks.isEmpty ? .green : .red)
            }
            .padding(.horizontal)

            // Priority distribution
            if !appState.tasks.isEmpty {
                priorityChart(tasks: appState.tasks)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Collaborators Content

    private var collaboratorsContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Workload Comparison
                workloadComparisonChart

                // Team Members
                VStack(spacing: 12) {
                    SectionHeader(title: "Team Members")

                    ForEach(sortedCollaborators) { collab in
                        NavigationLink(destination: AssigneeDetailView(collaborator: collab)) {
                            AssigneeCard(
                                collaborator: collab,
                                tasks: appState.tasks(assignedTo: collab.id),
                                completed: appState.completedTasks(assignedTo: collab.id),
                                colorIndex: appState.allCollaborators.firstIndex(of: collab) ?? 0
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                // Unassigned tasks
                unassignedSection
            }
            .padding(.vertical)
        }
    }

    private var sortedCollaborators: [Collaborator] {
        appState.allCollaborators.sorted {
            appState.tasks(assignedTo: $0.id).count > appState.tasks(assignedTo: $1.id).count
        }
    }

    // MARK: - Workload Chart

    private var workloadComparisonChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Workload Distribution")

            Chart(sortedCollaborators) { collab in
                let taskCount = appState.tasks(assignedTo: collab.id).count
                let overdueCount = appState.tasks(assignedTo: collab.id).filter { $0.isOverdue }.count

                BarMark(
                    x: .value("Name", collab.name),
                    y: .value("Tasks", taskCount - overdueCount)
                )
                .foregroundStyle(.blue)

                BarMark(
                    x: .value("Name", collab.name),
                    y: .value("Overdue", overdueCount)
                )
                .foregroundStyle(.red)
            }
            .chartForegroundStyleScale([
                "On Track": Color.blue,
                "Overdue": Color.red
            ])
            .frame(height: 200)
            .padding(.horizontal)
        }
    }

    // MARK: - Unassigned

    private var unassignedSection: some View {
        let unassigned = appState.tasks.filter { $0.assigneeId == nil }

        return Group {
            if !unassigned.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Unassigned Tasks")

                    Text("\(unassigned.count) tasks without assignee")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
        }
    }

    private func priorityChart(tasks: [TodoistTask]) -> some View {
        let breakdown = Dictionary(grouping: tasks, by: { $0.priority })
            .map { (priority: $0.key, count: $0.value.count) }
            .sorted { $0.priority > $1.priority }

        return Chart(breakdown, id: \.priority) { item in
            SectorMark(
                angle: .value("Count", item.count),
                innerRadius: .ratio(0.6),
                angularInset: 2
            )
            .foregroundStyle(AppTheme.priorityColor(for: item.priority))
            .annotation(position: .overlay) {
                Text("\(item.count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
        }
        .frame(height: 180)
    }
}

// MARK: - Assignee Card

struct AssigneeCard: View {
    let collaborator: Collaborator
    let tasks: [TodoistTask]
    let completed: [CompletedTask]
    let colorIndex: Int

    private var color: Color {
        AppTheme.chartColors[colorIndex % AppTheme.chartColors.count]
    }

    var body: some View {
        HStack(spacing: 14) {
            AvatarCircle(initials: collaborator.initials, size: 44, color: color)

            VStack(alignment: .leading, spacing: 4) {
                Text(collaborator.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Label("\(tasks.count) active", systemImage: "circle")
                    Label("\(completed.count) done", systemImage: "checkmark.circle")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                let overdue = tasks.filter { $0.isOverdue }.count
                if overdue > 0 {
                    Text("\(overdue)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                    Text("overdue")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.quaternary)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Assignee Detail

struct AssigneeDetailView: View {
    @EnvironmentObject var appState: AppState
    let collaborator: Collaborator

    private var tasks: [TodoistTask] { appState.tasks(assignedTo: collaborator.id) }
    private var completed: [CompletedTask] { appState.completedTasks(assignedTo: collaborator.id) }
    private var overdue: [TodoistTask] { tasks.filter { $0.isOverdue } }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    AvatarCircle(initials: collaborator.initials, size: 72, color: .blue)
                    Text(collaborator.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(collaborator.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Active", value: "\(tasks.count)", icon: "circle", color: .blue)
                    StatCard(title: "Done", value: "\(completed.count)", icon: "checkmark.circle", color: .green)
                    StatCard(title: "Overdue", value: "\(overdue.count)", icon: "exclamationmark.triangle",
                             color: overdue.isEmpty ? .green : .red)
                }
                .padding(.horizontal)

                // Tasks by Project
                tasksByProject

                // Active Tasks
                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Active Tasks")
                        LazyVStack(spacing: 0) {
                            ForEach(tasks.sorted { $0.priority > $1.priority }) { task in
                                TaskRow(task: task)
                                Divider().padding(.leading, 44)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle(collaborator.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var tasksByProject: some View {
        let grouped = Dictionary(grouping: tasks, by: { $0.projectId })

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "By Project")

            ForEach(Array(grouped.keys.sorted()), id: \.self) { projectId in
                if let project = appState.projects.first(where: { $0.id == projectId }) {
                    HStack {
                        Circle()
                            .fill(AppTheme.projectColor(for: project.color))
                            .frame(width: 10, height: 10)
                        Text(project.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(grouped[projectId]?.count ?? 0)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}
