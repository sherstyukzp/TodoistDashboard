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
    private var dataSyncService: DataSyncService?

    init(dataSyncService: DataSyncService? = nil) {
        self.dataSyncService = dataSyncService
        
        if let token = KeychainService.getToken() {
            apiClient = TodoistAPIClient(token: token)
            isAuthenticated = true
            
            // Try to load current user from keychain or SwiftData
            if let syncService = dataSyncService {
                // We need to fetch the user ID somehow - let's add it to keychain
                if let userId = KeychainService.getUserId() {
                    currentUser = syncService.fetchUser(id: userId)
                }
            }
            
            // Load cached data immediately
            loadCachedData()
        }
    }
    
    // MARK: - Load Cached Data
    
    private func loadCachedData() {
        guard let syncService = dataSyncService else { return }
        
        #if DEBUG
        print("📂 Loading cached data from SwiftData...")
        #endif
        
        // Load all data from SwiftData
        projects = syncService.fetchProjects()
        tasks = syncService.fetchTasks()
        sections = syncService.fetchSections()
        collaborators = syncService.fetchCollaborators()
        completedTasks = syncService.fetchCompletedTasks()
        activityEvents = syncService.fetchActivityEvents()
        
        if let userId = currentUser?.id {
            userStats = syncService.fetchUserStats(userId: userId)
        }
        
        #if DEBUG
        print("📂 Loaded: \(projects.count) projects, \(tasks.count) tasks, \(completedTasks.count) completed")
        #endif
        
        // Update sync state
        if let lastSync = syncService.getLastSyncDate() {
            syncState = .synced(lastSync)
        }
    }

    func authenticate(with token: String) async {
        let client = TodoistAPIClient(token: token)
        do {
            let user: TodoistUser = try await client.request(endpoint: "/user")
            KeychainService.saveToken(token)
            KeychainService.saveUserId(user.id)
            apiClient = client
            currentUser = user
            isAuthenticated = true
            
            // Save user to SwiftData
            if let syncService = dataSyncService {
                try? syncService.saveUser(user)
            }
            
            await performFullSync()
        } catch {
            errorMessage = "Invalid API token. Please check and try again."
        }
    }

    func logout() {
        KeychainService.deleteToken()
        KeychainService.deleteUserId()
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
        
        // Clear SwiftData
        if let syncService = dataSyncService {
            try? syncService.clearAllData()
        }
    }

    func performFullSync() async {
        await performFullSync(retryCount: 0)
    }
    
    private func performFullSync(retryCount: Int) async {
        guard let client = apiClient else { return }
        syncState = .syncing

        do {
            // Check for cancellation before starting
            try Task.checkCancellation()
            
            // 1. Fetch user info
            if currentUser == nil {
                currentUser = try await client.request(endpoint: "/user")
                if let user = currentUser, let syncService = dataSyncService {
                    try? syncService.saveUser(user)
                }
            }

            try Task.checkCancellation()
            
            // 2. Fetch projects
            let projectsResponse: [TodoistProject] = try await client.fetchAll(endpoint: "/projects")
            projects = projectsResponse
            if let syncService = dataSyncService {
                try? syncService.saveProjects(projectsResponse)
            }

            try Task.checkCancellation()
            
            // 3. Fetch all active tasks
            let tasksResponse: [TodoistTask] = try await client.fetchAll(endpoint: "/tasks")
            tasks = tasksResponse
            if let syncService = dataSyncService {
                try? syncService.saveTasks(tasksResponse)
            }

            try Task.checkCancellation()
            
            // 4. Fetch sections
            let sectionsResponse: [TodoistSection] = try await client.fetchAll(endpoint: "/sections")
            sections = sectionsResponse
            if let syncService = dataSyncService {
                try? syncService.saveSections(sectionsResponse)
            }

            try Task.checkCancellation()

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
                
                if let syncService = dataSyncService {
                    try? syncService.saveCollaborators(projectCollabsMap)
                }

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
            if let syncService = dataSyncService {
                try? syncService.saveCompletedTasks(completedTasks)
            }

            // 7. Fetch activity log
            do {
                activityEvents = try await client.fetchActivity(limit: 100)
                if let syncService = dataSyncService {
                    try? syncService.saveActivityEvents(activityEvents)
                }
            } catch {
                // Activity log requires Pro plan - graceful fallback
                activityEvents = []
            }

            // 8. Fetch productivity stats
            do {
                userStats = try await client.request(endpoint: "/user/productivity_stats")
                if let stats = userStats, let userId = currentUser?.id, let syncService = dataSyncService {
                    try? syncService.saveUserStats(stats, userId: userId)
                }
            } catch {
                userStats = nil
            }

            syncState = .synced(Date())
            errorMessage = nil
            
            #if DEBUG
            print("✅ Full sync completed and saved to SwiftData")
            #endif
        } catch is CancellationError {
            syncState = .error("Sync was cancelled")
            errorMessage = "Sync was cancelled. This may happen if the app was backgrounded or the network was slow."
            
            #if DEBUG
            print("❌ Sync cancelled (task cancellation)")
            #endif
        } catch let urlError as URLError {
            let message: String
            let shouldRetry: Bool
            
            switch urlError.code {
            case .cancelled:
                message = "Network request was cancelled. Try again."
                shouldRetry = true
            case .timedOut:
                message = "Network request timed out. Check your connection."
                shouldRetry = true
            case .notConnectedToInternet:
                message = "No internet connection."
                shouldRetry = false
            case .networkConnectionLost:
                message = "Network connection was lost."
                shouldRetry = true
            default:
                message = "Network error: \(urlError.localizedDescription)"
                shouldRetry = false
            }
            
            // Retry once if appropriate
            if shouldRetry && retryCount < 1 {
                syncState = .retrying(retryCount + 1)
                #if DEBUG
                print("🔄 Retrying sync after URLError: \(urlError.code.rawValue)")
                #endif
                try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2 seconds
                await performFullSync(retryCount: retryCount + 1)
                return
            }
            
            syncState = .error(message)
            errorMessage = message
            
            #if DEBUG
            print("❌ Sync failed (URLError): \(urlError.code.rawValue) - \(message)")
            if retryCount > 0 {
                print("   Failed after \(retryCount) retry attempt(s)")
            }
            #endif
        } catch {
            syncState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            
            #if DEBUG
            print("❌ Sync failed: \(error.localizedDescription)")
            if let todoistError = error as? TodoistError {
                print("   Todoist Error: \(todoistError)")
            }
            #endif
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
            .sorted { project1, project2 in
                tasks(assignedTo: userId).filter({ $0.projectId == project1.id }).count >
                tasks(assignedTo: userId).filter({ $0.projectId == project2.id }).count
            }
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
    
    /// Calculate comprehensive statistics for a team member
    func statistics(for userId: String) -> MemberStatistics {
        let memberTasks = tasks(assignedTo: userId)
        let memberCompleted = completedTasks(assignedTo: userId)
        
        let activeTasks = memberTasks.count
        let completedTasks = memberCompleted.count
        let overdueTasks = memberTasks.filter { $0.isOverdue }.count
        let highPriorityTasks = memberTasks.filter { $0.priority >= 2 }.count
        
        // Due today
        let today = formatDateOnly(Date())
        let dueToday = memberTasks.filter { $0.due?.date == today }.count
        
        // Due this week
        let calendar = Calendar.current
        let weekStart = calendar.startOfDay(for: Date())
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        let dueThisWeek = memberTasks.filter { task in
            guard let dueDate = task.due?.date, let date = parseDateOnly(dueDate) else { return false }
            return date >= weekStart && date <= weekEnd
        }.count
        
        // Completed last 30 days
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!
        let completedLast30Days = memberCompleted.filter { task in
            guard let completedDate = task.completedDate else { return false }
            return completedDate >= thirtyDaysAgo
        }.count
        
        // Completion rate (completed / total in last 30 days)
        let totalTasksLast30Days = activeTasks + completedLast30Days
        let completionRate = totalTasksLast30Days > 0 ? Double(completedLast30Days) / Double(totalTasksLast30Days) : 0
        
        // High priority percentage
        let highPriorityPercentage = activeTasks > 0 ? Double(highPriorityTasks) / Double(activeTasks) : 0
        
        return MemberStatistics(
            activeTasks: activeTasks,
            completedTasks: completedTasks,
            overdueTasks: overdueTasks,
            highPriorityTasks: highPriorityTasks,
            dueToday: dueToday,
            dueThisWeek: dueThisWeek,
            completedLast30Days: completedLast30Days,
            completionRate: completionRate,
            highPriorityPercentage: highPriorityPercentage
        )
    }

    private func formatDateOnly(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
    
    private func parseDateOnly(_ dateString: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dateString)
    }
}

enum SyncState: Equatable {
    case idle
    case syncing
    case retrying(Int) // retry attempt number
    case synced(Date)
    case error(String)

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing): return true
        case (.retrying(let a), .retrying(let b)): return a == b
        case (.synced(let a), .synced(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
