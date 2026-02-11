import SwiftUI
import Charts

// MARK: - Projects List

struct ProjectsListView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var sortBy: ProjectSort = .tasks

    enum ProjectSort: String, CaseIterable {
        case name = "Name"
        case tasks = "Tasks"
        case progress = "Progress"
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary
                Section {
                    HStack(spacing: 20) {
                        StatMini(title: "Projects", value: "\(filteredProjects.count)", icon: "folder")
                        StatMini(title: "Total Tasks", value: "\(appState.tasks.count)", icon: "checklist")
                        StatMini(title: "Completed", value: "\(appState.completedTasks.count)", icon: "checkmark.circle")
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                // Comparison Chart
                if filteredProjects.count > 1 {
                    Section("Comparison") {
                        projectComparisonChart
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                // Project List
                Section("All Projects") {
                    ForEach(sortedProjects) { project in
                        NavigationLink(destination: ProjectDetailView(project: project)) {
                            ProjectListRow(
                                project: project,
                                activeTasks: appState.tasks(for: project.id).count,
                                completedTasks: appState.completedTasks(for: project.id).count,
                                overdueTasks: appState.tasks(for: project.id).filter { $0.isOverdue }.count
                            )
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search projects")
            .refreshable { await appState.performFullSync() }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort by", selection: $sortBy) {
                            ForEach(ProjectSort.allCases, id: \.self) { sort in
                                Text(sort.rawValue).tag(sort)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                    }
                }
            }
        }
    }

    private var filteredProjects: [TodoistProject] {
        let base = appState.projects.filter { $0.parentId == nil }
        if searchText.isEmpty { return base }
        return base.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var sortedProjects: [TodoistProject] {
        switch sortBy {
        case .name:
            return filteredProjects.sorted { $0.name < $1.name }
        case .tasks:
            return filteredProjects.sorted {
                appState.tasks(for: $0.id).count > appState.tasks(for: $1.id).count
            }
        case .progress:
            return filteredProjects.sorted {
                projectProgress($0) > projectProgress($1)
            }
        }
    }

    private func projectProgress(_ project: TodoistProject) -> Double {
        let active = Double(appState.tasks(for: project.id).count)
        let completed = Double(appState.completedTasks(for: project.id).count)
        let total = active + completed
        guard total > 0 else { return 0 }
        return completed / total
    }

    private var projectComparisonChart: some View {
        Chart(Array(sortedProjects.prefix(8))) { project in
            let active = appState.tasks(for: project.id).count
            let completed = appState.completedTasks(for: project.id).count

            BarMark(
                x: .value("Project", project.name),
                y: .value("Count", active)
            )
            .foregroundStyle(by: .value("Type", "Active"))

            BarMark(
                x: .value("Project", project.name),
                y: .value("Count", completed)
            )
            .foregroundStyle(by: .value("Type", "Completed"))
        }
        .chartForegroundStyleScale([
            "Active": Color.blue,
            "Completed": Color.green
        ])
    }
}

// MARK: - Project List Row

struct ProjectListRow: View {
    let project: TodoistProject
    let activeTasks: Int
    let completedTasks: Int
    let overdueTasks: Int

    private var total: Int { activeTasks + completedTasks }
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completedTasks) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(AppTheme.projectColor(for: project.color))
                    .frame(width: 12, height: 12)

                Text(project.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if project.isShared {
                    Image(systemName: "person.2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressBar(
                progress: progress,
                color: AppTheme.projectColor(for: project.color),
                height: 6
            )

            HStack(spacing: 12) {
                Label("\(activeTasks)", systemImage: "circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(completedTasks)", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundStyle(.green)

                if overdueTasks > 0 {
                    Label("\(overdueTasks)", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.projectColor(for: project.color))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Project Detail

struct ProjectDetailView: View {
    @EnvironmentObject var appState: AppState
    let project: TodoistProject

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress Ring
                VStack(spacing: 8) {
                    ProgressRing(
                        progress: progress,
                        size: 120,
                        lineWidth: 10,
                        color: AppTheme.projectColor(for: project.color)
                    )
                    Text("\(completedCount) of \(totalCount) tasks done")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                // Stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(title: "Active", value: "\(activeTasks.count)", icon: "circle", color: .blue)
                    StatCard(title: "Done", value: "\(completedCount)", icon: "checkmark.circle", color: .green)
                    StatCard(title: "Overdue", value: "\(overdueTasks.count)", icon: "exclamationmark.triangle",
                             color: overdueTasks.isEmpty ? .green : .red)
                }
                .padding(.horizontal)

                // Priority Breakdown
                priorityBreakdown

                // Sections
                if !projectSections.isEmpty {
                    sectionsView
                }

                // Task List
                tasksList
            }
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.large)
    }

    private var activeTasks: [TodoistTask] { appState.tasks(for: project.id) }
    private var overdueTasks: [TodoistTask] { activeTasks.filter { $0.isOverdue } }
    private var completedCount: Int { appState.completedTasks(for: project.id).count }
    private var totalCount: Int { activeTasks.count + completedCount }
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    private var projectSections: [TodoistSection] { appState.sections(for: project.id) }

    private var priorityBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "By Priority")

            HStack(spacing: 12) {
                ForEach([4, 3, 2, 1], id: \.self) { p in
                    let count = activeTasks.filter { $0.priority == p }.count
                    VStack(spacing: 4) {
                        Text("\(count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.priorityColor(for: p))
                        Text(AppTheme.priorityLabel(for: p))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.priorityColor(for: p).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)
        }
    }

    private var sectionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sections")

            ForEach(projectSections) { section in
                let sectionTasks = activeTasks.filter { $0.sectionId == section.id }
                HStack {
                    Text(section.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(sectionTasks.count) tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
        }
    }

    private var tasksList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Active Tasks (\(activeTasks.count))")

            LazyVStack(spacing: 0) {
                ForEach(activeTasks.sorted { $0.priority > $1.priority }) { task in
                    TaskRow(task: task)
                    Divider().padding(.leading, 44)
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: TodoistTask

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .strokeBorder(AppTheme.priorityColor(for: task.priority), lineWidth: 2)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.content)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted ?? false)

                HStack(spacing: 8) {
                    if let due = task.due {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                            Text(due.displayString)
                        }
                        .font(.caption)
                        .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }

                    if !task.labels.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "tag")
                            Text(task.labels.joined(separator: ", "))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }
            }

            Spacer()

            if task.priority >= 2 {
                PriorityBadge(priority: task.priority)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Helper

struct StatMini: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
