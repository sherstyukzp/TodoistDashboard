import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Sync Status
                    SyncStatusBar(state: appState.syncState)
                        .padding(.horizontal)

                    // Summary Cards
                    summaryCards

                    // Project Progress
                    if !appState.projects.isEmpty {
                        projectProgressSection
                    }

                    // Team Workload (show when there are team members with assigned tasks)
                    if appState.allCollaborators.contains(where: { !appState.tasks(assignedTo: $0.id).isEmpty }) {
                        teamWorkloadSection
                    }

                    // Weekly Completion Chart
                    weeklyCompletionChart

                    // Recent Activity
                    recentActivitySection
                }
                .padding(.vertical)
            }
            .refreshable {
                await appState.performFullSync()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { Task { await appState.performFullSync() } }) {
                            Label("Sync Now", systemImage: "arrow.clockwise")
                        }
                        Divider()
                        Button(role: .destructive, action: { appState.logout() }) {
                            Label("Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay {
                if appState.syncState == .syncing && appState.projects.isEmpty {
                    LoadingOverlay(message: "Loading your data...")
                }
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Active",
                value: "\(appState.tasks.count)",
                icon: "checklist",
                color: .blue
            )

            StatCard(
                title: "Overdue",
                value: "\(appState.overdueTasks.count)",
                icon: "exclamationmark.triangle",
                color: appState.overdueTasks.isEmpty ? .green : .red
            )

            StatCard(
                title: "Focus",
                value: "\(focusScore)%",
                icon: "target",
                color: focusScore >= 50 ? .green : .orange,
                subtitle: "P1+P2 ratio"
            )
        }
        .padding(.horizontal)
    }

    private var focusScore: Int {
        guard !appState.completedTasks.isEmpty else { return 0 }
        // Focus score based on active high-priority tasks completion
        let highPriority = appState.tasks.filter { $0.priority >= 3 }.count
        let total = appState.tasks.count
        guard total > 0 else { return 100 }
        return Int(Double(highPriority) / Double(total) * 100)
    }

    // MARK: - Project Progress

    private var projectProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Project Progress")

            VStack(spacing: 10) {
                ForEach(topProjects) { project in
                    ProjectProgressRow(
                        project: project,
                        activeTasks: appState.tasks(for: project.id).count,
                        completedTasks: appState.completedTasks(for: project.id).count
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private var topProjects: [TodoistProject] {
        // Show top 5 projects with most tasks
        Array(
            appState.projects
                .filter { !($0.isInboxProject ?? false) && $0.parentId == nil }
                .sorted { appState.tasks(for: $0.id).count > appState.tasks(for: $1.id).count }
                .prefix(5)
        )
    }

    // MARK: - Team Workload

    private var teamWorkloadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Team Workload")

            VStack(spacing: 8) {
                ForEach(appState.allCollaborators) { collab in
                    let assigned = appState.tasks(assignedTo: collab.id)
                    let overdue = assigned.filter { $0.isOverdue }

                    HStack(spacing: 12) {
                        AvatarCircle(
                            initials: collab.initials,
                            size: 36,
                            color: AppTheme.chartColors[appState.allCollaborators.firstIndex(of: collab) ?? 0 % AppTheme.chartColors.count]
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(collab.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("\(assigned.count) tasks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if !overdue.isEmpty {
                            Text("\(overdue.count) overdue")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Weekly Chart

    private var weeklyCompletionChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "This Week")

            let data = weeklyData

            if !data.isEmpty {
                Chart(data, id: \.day) { item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Completed", item.count)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 160)
                .padding(.horizontal)
            } else {
                Text("No completed tasks this week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private var weeklyData: [DayCount] {
        let cal = Calendar.current
        let today = Date()

        return (0..<7).reversed().map { daysAgo in
            let date = cal.date(byAdding: .day, value: -daysAgo, to: today)!
            let dayStart = cal.startOfDay(for: date)
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

            let count = appState.completedTasks.filter { task in
                guard let completed = task.completedDate else { return false }
                return completed >= dayStart && completed < dayEnd
            }.count

            return DayCount(day: date.dayOfWeekShort, count: count)
        }
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Activity")

            if appState.activityEvents.isEmpty {
                Text("Activity log requires Todoist Pro plan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(appState.activityEvents.prefix(5))) { event in
                        ActivityRow(event: event)
                        if event.id != appState.activityEvents.prefix(5).last?.id {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Supporting Views

struct ProjectProgressRow: View {
    let project: TodoistProject
    let activeTasks: Int
    let completedTasks: Int

    private var total: Int { activeTasks + completedTasks }
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completedTasks) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(AppTheme.projectColor(for: project.color))
                    .frame(width: 10, height: 10)
                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }

            ProgressBar(
                progress: progress,
                color: AppTheme.projectColor(for: project.color)
            )

            HStack {
                Text("\(activeTasks) active")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("·")
                    .foregroundStyle(.quaternary)
                Text("\(completedTasks) done")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ActivityRow: View {
    let event: ActivityEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(event.emoji)
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.extraData?.content ?? event.extraData?.name ?? event.objectType)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(event.eventType.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let date = event.eventDateParsed {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text(date.relativeString)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct DayCount {
    let day: String
    let count: Int
}
