import SwiftUI
import Charts

struct AssigneesView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if appState.allCollaborators.isEmpty && appState.currentUser == nil {
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

                    Text("\(unassigned.count) tasks without explicit assignee")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    // Show unassigned tasks grouped by project
                    let grouped = Dictionary(grouping: unassigned, by: { $0.projectId })
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

    private var memberTasks: [TodoistTask] { appState.tasks(assignedTo: collaborator.id) }
    private var completed: [CompletedTask] { appState.completedTasks(assignedTo: collaborator.id) }
    private var overdue: [TodoistTask] { memberTasks.filter { $0.isOverdue } }
    private var isCurrentUser: Bool { collaborator.id == appState.currentUser?.id }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection

                // Stats
                statsSection

                // Priority Breakdown
                if !memberTasks.isEmpty {
                    prioritySection
                }

                // Projects with tasks
                if !memberTasks.isEmpty {
                    projectsSection
                }

                // Shared projects (for team members)
                sharedProjectsSection

                // Overdue Tasks
                if !overdue.isEmpty {
                    overdueSection
                }

                // Active Tasks
                if !memberTasks.isEmpty {
                    activeTasksSection
                }

                // Recent Completed Tasks
                if !completed.isEmpty {
                    completedSection
                }

                // Empty state
                if memberTasks.isEmpty && completed.isEmpty {
                    emptyMemberView
                }
            }
        }
        .navigationTitle(collaborator.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            AvatarCircle(initials: collaborator.initials, size: 72, color: .blue)
            HStack(spacing: 6) {
                Text(collaborator.name)
                    .font(.title2)
                    .fontWeight(.bold)
                if isCurrentUser {
                    Text("(You)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            if !collaborator.email.isEmpty {
                Text(collaborator.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top)
    }

    // MARK: - Stats

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Active", value: "\(memberTasks.count)", icon: "circle", color: .blue)
            StatCard(title: "Done", value: "\(completed.count)", icon: "checkmark.circle", color: .green)
            StatCard(title: "Overdue", value: "\(overdue.count)", icon: "exclamationmark.triangle",
                     color: overdue.isEmpty ? .green : .red)
            StatCard(title: "Projects", value: "\(projectsWithTasks.count)", icon: "folder", color: .purple)
        }
        .padding(.horizontal)
    }

    // MARK: - Priority Breakdown

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Priority Breakdown")

            let breakdown = Dictionary(grouping: memberTasks, by: { $0.priority })
                .map { (priority: $0.key, count: $0.value.count) }
                .sorted { $0.priority > $1.priority }

            VStack(spacing: 8) {
                ForEach(breakdown, id: \.priority) { item in
                    HStack(spacing: 12) {
                        PriorityBadge(priority: item.priority)

                        ProgressBar(
                            progress: Double(item.count) / Double(max(memberTasks.count, 1)),
                            color: AppTheme.priorityColor(for: item.priority),
                            height: 10
                        )

                        Text("\(item.count)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Projects Section

    private var projectsWithTasks: [(project: TodoistProject, tasks: [TodoistTask])] {
        let grouped = Dictionary(grouping: memberTasks, by: { $0.projectId })
        return grouped.compactMap { projectId, tasks in
            guard let project = appState.projects.first(where: { $0.id == projectId }) else { return nil }
            return (project: project, tasks: tasks)
        }
        .sorted { $0.tasks.count > $1.tasks.count }
    }

    private var projectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tasks by Project")

            VStack(spacing: 10) {
                ForEach(projectsWithTasks, id: \.project.id) { item in
                    let projectCompleted = appState.completedTasks(for: item.project.id)
                    let total = item.tasks.count + projectCompleted.count
                    let progress = total > 0 ? Double(projectCompleted.count) / Double(total) : 0
                    let projectOverdue = item.tasks.filter { $0.isOverdue }.count

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Circle()
                                .fill(AppTheme.projectColor(for: item.project.color))
                                .frame(width: 10, height: 10)
                            Text(item.project.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if item.project.isShared {
                                Image(systemName: "person.2")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(item.tasks.count) active")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        ProgressBar(
                            progress: progress,
                            color: AppTheme.projectColor(for: item.project.color),
                            height: 6
                        )

                        HStack(spacing: 12) {
                            Text("\(Int(progress * 100))% complete")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if projectOverdue > 0 {
                                Text("\(projectOverdue) overdue")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Shared Projects

    private var sharedProjectsSection: some View {
        let shared = appState.sharedProjects(for: collaborator.id)
        return Group {
            if !shared.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Shared Projects")

                    VStack(spacing: 6) {
                        ForEach(shared) { project in
                            HStack {
                                Circle()
                                    .fill(AppTheme.projectColor(for: project.color))
                                    .frame(width: 10, height: 10)
                                Text(project.name)
                                    .font(.subheadline)
                                Image(systemName: "person.2")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                let count = appState.tasks(for: project.id).count
                                Text("\(count) tasks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Overdue Tasks

    private var overdueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Overdue Tasks (\(overdue.count))")

            LazyVStack(spacing: 0) {
                ForEach(overdue.sorted { ($0.due?.date ?? "") < ($1.due?.date ?? "") }) { task in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .strokeBorder(.red, lineWidth: 2)
                            .frame(width: 22, height: 22)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.content)
                                .font(.subheadline)

                            HStack(spacing: 8) {
                                if let due = task.due {
                                    HStack(spacing: 3) {
                                        Image(systemName: "calendar.badge.exclamationmark")
                                        Text(due.displayString)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                }
                                if let days = task.daysOverdue {
                                    Text("\(days) days overdue")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.red)
                                }
                                if let project = appState.projects.first(where: { $0.id == task.projectId }) {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(AppTheme.projectColor(for: project.color))
                                            .frame(width: 6, height: 6)
                                        Text(project.name)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()

                        if task.priority >= 2 {
                            PriorityBadge(priority: task.priority)
                        }
                    }
                    .padding(.vertical, 8)
                    Divider().padding(.leading, 34)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Active Tasks

    private var activeTasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "All Active Tasks (\(memberTasks.count))")

            LazyVStack(spacing: 0) {
                ForEach(memberTasks.sorted { $0.priority > $1.priority }) { task in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .strokeBorder(AppTheme.priorityColor(for: task.priority), lineWidth: 2)
                            .frame(width: 22, height: 22)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.content)
                                .font(.subheadline)

                            HStack(spacing: 8) {
                                if let due = task.due {
                                    HStack(spacing: 3) {
                                        Image(systemName: "calendar")
                                        Text(due.displayString)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(task.isOverdue ? .red : .secondary)
                                }
                                if let project = appState.projects.first(where: { $0.id == task.projectId }) {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(AppTheme.projectColor(for: project.color))
                                            .frame(width: 6, height: 6)
                                        Text(project.name)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()

                        if task.priority >= 2 {
                            PriorityBadge(priority: task.priority)
                        }
                    }
                    .padding(.vertical, 8)
                    Divider().padding(.leading, 34)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Completed Tasks

    private var completedSection: some View {
        let recentCompleted = completed
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(20)

        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Recently Completed (\(completed.count) total)")

            LazyVStack(spacing: 0) {
                ForEach(Array(recentCompleted)) { task in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .frame(width: 22, height: 22)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.content)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .strikethrough()

                            HStack(spacing: 8) {
                                if let date = task.completedDate {
                                    Text(date.relativeString)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                if let project = appState.projects.first(where: { $0.id == task.projectId }) {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(AppTheme.projectColor(for: project.color))
                                            .frame(width: 6, height: 6)
                                        Text(project.name)
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                    Divider().padding(.leading, 34)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Empty State

    private var emptyMemberView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No tasks found")
                .font(.headline)
            Text("This team member has no active or completed tasks visible to you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
