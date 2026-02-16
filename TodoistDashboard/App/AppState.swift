import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var syncState: SyncState = .idle
    @Published var projects: [TodoistProject] = []
    @Published var tasks: [TodoistTask] = []
    @Published var completedTasks: [CompletedTask] = []
    @Published var sections: [TodoistSection] = []
    @Published var collaborators: [String: [Collaborator]] = [:] // projectId -> collaborators
    @Published var activityEvents: [ActivityEvent] = []
    @Published var userStats: UserStats?
    @Published var currentUser: TodoistUser?
    @Published var errorMessage: String?

    private var apiClient: TodoistAPIClient?

    init() {
        if let token = KeychainService.getToken() {
            apiClient = TodoistAPIClient(token: token)
            isAuthenticated = true
        }
    }

    func authenticate(with token: String) async {
        let client = TodoistAPIClient(token: token)
        do {
            let user: TodoistUser = try await client.request(endpoint: "/user")
            KeychainService.saveToken(token)
            apiClient = client
            currentUser = user
            isAuthenticated = true
            await performFullSync()
        } catch {
            errorMessage = "Invalid API token. Please check and try again."
        }
    }

    func logout() {
        KeychainService.deleteToken()
        apiClient = nil
        isAuthenticated = false
        projects = []
        tasks = []
        completedTasks = []
        sections = []
        collaborators = [:]
        activityEvents = []
        userStats = nil
        currentUser = nil
    }

    func performFullSync() async {
        guard let client = apiClient else { return }
        syncState = .syncing

        do {
            // 1. Fetch user info
            if currentUser == nil {
                currentUser = try await client.request(endpoint: "/user")
            }

            // 2. Fetch projects
            let projectsResponse: [TodoistProject] = try await client.fetchAll(endpoint: "/projects")
            projects = projectsResponse

            // 3. Fetch all active tasks
            let tasksResponse: [TodoistTask] = try await client.fetchAll(endpoint: "/tasks")
            tasks = tasksResponse

            // 4. Fetch sections
            let sectionsResponse: [TodoistSection] = try await client.fetchAll(endpoint: "/sections")
            sections = sectionsResponse

            // 5. Fetch collaborators via Sync API
            do {
                let syncResponse = try await client.fetchCollaborators()

                #if DEBUG
                print("✅ Fetched \(syncResponse.collaborators.count) collaborators")
                print("✅ Fetched \(syncResponse.collaboratorStates.count) collaborator states")
                for collab in syncResponse.collaborators {
                    print("   - Collaborator: \(collab.name) (ID: \(collab.id))")
                }
                #endif

                // Build project-to-collaborators mapping from collaborator_states
                var projectCollabsMap: [String: [Collaborator]] = [:]

                for state in syncResponse.collaboratorStates {
                    // Only include active, non-deleted collaborators
                    guard state.state == "active" && !state.isDeleted else { continue }

                    // Find the collaborator info
                    if let collab = syncResponse.collaborators.first(where: { $0.id == state.userId }) {
                        if projectCollabsMap[state.projectId] == nil {
                            projectCollabsMap[state.projectId] = []
                        }
                        projectCollabsMap[state.projectId]?.append(collab)
                    }
                }

                collaborators = projectCollabsMap

                #if DEBUG
                print("✅ Built collaborators map for \(projectCollabsMap.keys.count) projects")
                for (projectId, collabs) in projectCollabsMap {
                    if let project = projects.first(where: { $0.id == projectId }) {
                        print("   - \(project.name): \(collabs.map { $0.name }.joined(separator: ", "))")
                    }
                }
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Failed to fetch collaborators via sync API: \(error.localizedDescription)")
                #endif
                // Continue without collaborators
                collaborators = [:]
            }

            // 6. Fetch completed tasks (last 3 months)
            let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            let sinceStr = formatter.string(from: threeMonthsAgo)
            let untilStr = formatter.string(from: Date())

            completedTasks = try await client.fetchCompletedTasks(since: sinceStr, until: untilStr)

            // 7. Fetch activity log
            do {
                activityEvents = try await client.fetchActivity(limit: 100)
            } catch {
                // Activity log requires Pro plan - graceful fallback
                activityEvents = []
            }

            // 8. Fetch productivity stats
            do {
                userStats = try await client.request(endpoint: "/user/productivity_stats")
            } catch {
                userStats = nil
            }

            syncState = .synced(Date())
            errorMessage = nil
        } catch {
            syncState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed Properties

    var overdueTasks: [TodoistTask] {
        tasks.filter { $0.isOverdue }
            .sorted { ($0.due?.date ?? "") < ($1.due?.date ?? "") }
    }

    var todayTasks: [TodoistTask] {
        let today = formatDateOnly(Date())
        return tasks.filter { $0.due?.date == today }
    }

    func tasks(for projectId: String) -> [TodoistTask] {
        tasks.filter { $0.projectId == projectId }
    }

    func completedTasks(for projectId: String) -> [CompletedTask] {
        completedTasks.filter { $0.projectId == projectId }
    }

    func sections(for projectId: String) -> [TodoistSection] {
        sections.filter { $0.projectId == projectId }
    }

    var allCollaborators: [Collaborator] {
        var seen = Set<String>()
        var result: [Collaborator] = []

        // Include the current user as a team member
        if let user = currentUser {
            seen.insert(user.id)
            result.append(Collaborator(id: user.id, name: user.displayName, email: user.email))
        }

        // Add collaborators from shared projects
        for collabs in collaborators.values {
            for c in collabs {
                if !seen.contains(c.id) {
                    seen.insert(c.id)
                    result.append(c)
                }
            }
        }

        // Add any assignees found in tasks that are not yet in the list
        for task in tasks {
            if let assigneeId = task.assigneeId, !seen.contains(assigneeId) {
                seen.insert(assigneeId)
                result.append(Collaborator(id: assigneeId, name: "User \(assigneeId)", email: ""))
            }
        }

        return result
    }

    func tasks(assignedTo userId: String) -> [TodoistTask] {
        // For the current user: include explicitly assigned tasks + unassigned tasks in personal projects
        if userId == currentUser?.id {
            return tasks.filter { task in
                task.assigneeId == userId ||
                (task.assigneeId == nil && !isSharedProject(task.projectId))
            }
        }
        // For other team members: only explicitly assigned tasks
        return tasks.filter { $0.assigneeId == userId }
    }

    func completedTasks(assignedTo userId: String) -> [CompletedTask] {
        completedTasks.filter { $0.userId == userId }
    }

    /// Projects where this team member has assigned tasks
    func projects(for userId: String) -> [TodoistProject] {
        let memberTasks = tasks(assignedTo: userId)
        let projectIds = Set(memberTasks.map { $0.projectId })
        return projects.filter { projectIds.contains($0.id) }
            .sorted { tasks(assignedTo: userId).filter({ $0.projectId == $0.id }).count >
                      tasks(assignedTo: userId).filter({ $0.projectId == $1.id }).count }
    }

    /// Shared projects this collaborator belongs to
    func sharedProjects(for userId: String) -> [TodoistProject] {
        var result: [TodoistProject] = []
        for (projectId, collabs) in collaborators {
            if collabs.contains(where: { $0.id == userId }) {
                if let project = projects.first(where: { $0.id == projectId }) {
                    result.append(project)
                }
            }
        }
        return result
    }

    /// Check if a project is shared (has collaborators)
    func isSharedProject(_ projectId: String) -> Bool {
        collaborators[projectId] != nil && !(collaborators[projectId]?.isEmpty ?? true)
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

enum SyncState: Equatable {
    case idle
    case syncing
    case synced(Date)
    case error(String)

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing): return true
        case (.synced(let a), .synced(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
