import Foundation
import SwiftData

@MainActor
class DataSyncService {
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = true
    }
    
    // MARK: - User
    
    func saveUser(_ user: TodoistUser) throws {
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.id == user.id })
        let existing = try modelContext.fetch(descriptor).first
        
        if let existing = existing {
            existing.fullName = user.fullName
            existing.email = user.email
            existing.lastSynced = Date()
        } else {
            let sdUser = SDUser.from(user)
            modelContext.insert(sdUser)
        }
        
        try modelContext.save()
    }
    
    func fetchUser(id: String) -> TodoistUser? {
        let descriptor = FetchDescriptor<SDUser>(predicate: #Predicate { $0.id == id })
        guard let sdUser = try? modelContext.fetch(descriptor).first else { return nil }
        return sdUser.toTodoistUser()
    }
    
    // MARK: - Projects
    
    func saveProjects(_ projects: [TodoistProject]) throws {
        let existingIds = Set(try modelContext.fetch(FetchDescriptor<SDProject>()).map { $0.id })
        
        for project in projects {
            let descriptor = FetchDescriptor<SDProject>(predicate: #Predicate { $0.id == project.id })
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                existing.name = project.name
                existing.color = project.color
                existing.parentId = project.parentId
                existing.order = project.order
                existing.commentCount = project.commentCount
                existing.isShared = project.isShared
                existing.isFavorite = project.isFavorite
                existing.isInboxProject = project.isInboxProject
                existing.viewStyle = project.viewStyle
                existing.lastSynced = Date()
            } else {
                let sdProject = SDProject.from(project)
                modelContext.insert(sdProject)
            }
        }
        
        // Delete projects that no longer exist
        let currentIds = Set(projects.map { $0.id })
        let idsToDelete = existingIds.subtracting(currentIds)
        
        for idToDelete in idsToDelete {
            let descriptor = FetchDescriptor<SDProject>(predicate: #Predicate { $0.id == idToDelete })
            if let toDelete = try modelContext.fetch(descriptor).first {
                modelContext.delete(toDelete)
            }
        }
        
        try modelContext.save()
        
        #if DEBUG
        print("💾 Saved \(projects.count) projects to SwiftData")
        #endif
    }
    
    func fetchProjects() -> [TodoistProject] {
        let descriptor = FetchDescriptor<SDProject>(sortBy: [SortDescriptor(\.order)])
        guard let sdProjects = try? modelContext.fetch(descriptor) else { return [] }
        return sdProjects.map { $0.toTodoistProject() }
    }
    
    // MARK: - Tasks
    
    func saveTasks(_ tasks: [TodoistTask]) throws {
        let existingIds = Set(try modelContext.fetch(FetchDescriptor<SDTask>()).map { $0.id })
        
        for task in tasks {
            let descriptor = FetchDescriptor<SDTask>(predicate: #Predicate { $0.id == task.id })
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                existing.content = task.content
                existing.taskDescription = task.description
                existing.projectId = task.projectId
                existing.sectionId = task.sectionId
                existing.parentId = task.parentId
                existing.order = task.order
                existing.priority = task.priority
                existing.dueDate = task.due?.date
                existing.dueDatetime = task.due?.datetime
                existing.dueString = task.due?.string
                existing.dueLang = task.due?.lang
                existing.dueIsRecurring = task.due?.isRecurring ?? false
                existing.dueTimezone = task.due?.timezone
                existing.labels = task.labels
                existing.assigneeId = task.assigneeId
                existing.assignerId = task.assignerId
                existing.commentCount = task.commentCount
                existing.createdAt = task.createdAt
                existing.creatorId = task.creatorId
                existing.url = task.url
                existing.isCompleted = task.isCompleted ?? false
                existing.lastSynced = Date()
            } else {
                let sdTask = SDTask.from(task)
                modelContext.insert(sdTask)
            }
        }
        
        // Delete tasks that no longer exist (completed or deleted)
        let currentIds = Set(tasks.map { $0.id })
        let idsToDelete = existingIds.subtracting(currentIds)
        
        for idToDelete in idsToDelete {
            let descriptor = FetchDescriptor<SDTask>(predicate: #Predicate { $0.id == idToDelete })
            if let toDelete = try modelContext.fetch(descriptor).first {
                modelContext.delete(toDelete)
            }
        }
        
        try modelContext.save()
        
        #if DEBUG
        print("💾 Saved \(tasks.count) tasks to SwiftData")
        #endif
    }
    
    func fetchTasks() -> [TodoistTask] {
        let descriptor = FetchDescriptor<SDTask>(
            predicate: #Predicate { $0.isCompleted == false },
            sortBy: [SortDescriptor(\.priority, order: .reverse)]
        )
        guard let sdTasks = try? modelContext.fetch(descriptor) else { return [] }
        return sdTasks.map { $0.toTodoistTask() }
    }
    
    // MARK: - Sections
    
    func saveSections(_ sections: [TodoistSection]) throws {
        let existingIds = Set(try modelContext.fetch(FetchDescriptor<SDSection>()).map { $0.id })
        
        for section in sections {
            let descriptor = FetchDescriptor<SDSection>(predicate: #Predicate { $0.id == section.id })
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                existing.projectId = section.projectId
                existing.order = section.order
                existing.name = section.name
                existing.lastSynced = Date()
            } else {
                let sdSection = SDSection.from(section)
                modelContext.insert(sdSection)
            }
        }
        
        // Delete sections that no longer exist
        let currentIds = Set(sections.map { $0.id })
        let idsToDelete = existingIds.subtracting(currentIds)
        
        for idToDelete in idsToDelete {
            let descriptor = FetchDescriptor<SDSection>(predicate: #Predicate { $0.id == idToDelete })
            if let toDelete = try modelContext.fetch(descriptor).first {
                modelContext.delete(toDelete)
            }
        }
        
        try modelContext.save()
        
        #if DEBUG
        print("💾 Saved \(sections.count) sections to SwiftData")
        #endif
    }
    
    func fetchSections() -> [TodoistSection] {
        let descriptor = FetchDescriptor<SDSection>(sortBy: [SortDescriptor(\.order)])
        guard let sdSections = try? modelContext.fetch(descriptor) else { return [] }
        return sdSections.map { $0.toTodoistSection() }
    }
    
    // MARK: - Collaborators
    
    func saveCollaborators(_ collaborators: [String: [Collaborator]]) throws {
        // First, get all unique collaborators
        var allCollaborators: [Collaborator] = []
        var collaboratorProjects: [String: [String]] = [:] // collaboratorId -> [projectIds]
        
        for (projectId, collabs) in collaborators {
            for collab in collabs {
                if !allCollaborators.contains(where: { $0.id == collab.id }) {
                    allCollaborators.append(collab)
                }
                collaboratorProjects[collab.id, default: []].append(projectId)
            }
        }
        
        // Save or update each collaborator
        for collab in allCollaborators {
            let descriptor = FetchDescriptor<SDCollaborator>(predicate: #Predicate { $0.id == collab.id })
            let existing = try modelContext.fetch(descriptor).first
            
            let projectIds = collaboratorProjects[collab.id] ?? []
            
            if let existing = existing {
                existing.name = collab.name
                existing.email = collab.email
                existing.projectIds = projectIds
                existing.lastSynced = Date()
            } else {
                let sdCollab = SDCollaborator.from(collab, projectIds: projectIds)
                modelContext.insert(sdCollab)
            }
        }
        
        try modelContext.save()
        
        #if DEBUG
        print("💾 Saved \(allCollaborators.count) collaborators to SwiftData")
        #endif
    }
    
    func fetchCollaborators() -> [String: [Collaborator]] {
        let descriptor = FetchDescriptor<SDCollaborator>()
        guard let sdCollaborators = try? modelContext.fetch(descriptor) else { return [:] }
        
        var result: [String: [Collaborator]] = [:]
        
        for sdCollab in sdCollaborators {
            let collab = sdCollab.toCollaborator()
            for projectId in sdCollab.projectIds {
                result[projectId, default: []].append(collab)
            }
        }
        
        return result
    }
    
    // MARK: - Completed Tasks
    
    func saveCompletedTasks(_ tasks: [CompletedTask]) throws {
        let existingIds = Set(try modelContext.fetch(FetchDescriptor<SDCompletedTask>()).map { $0.id })
        
        for task in tasks {
            let descriptor = FetchDescriptor<SDCompletedTask>(predicate: #Predicate { $0.id == task.id })
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                existing.taskId = task.taskId
                existing.content = task.content
                existing.projectId = task.projectId
                existing.sectionId = task.sectionId
                existing.completedAt = task.completedAt
                existing.userId = task.userId
                existing.lastSynced = Date()
            } else {
                let sdTask = SDCompletedTask.from(task)
                modelContext.insert(sdTask)
            }
        }
        
        // Optionally delete old completed tasks (older than 3 months)
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let threeMonthsAgoStr = iso.string(from: threeMonthsAgo)
        
        let oldDescriptor = FetchDescriptor<SDCompletedTask>(
            predicate: #Predicate { $0.completedAt < threeMonthsAgoStr }
        )
        let oldTasks = try modelContext.fetch(oldDescriptor)
        for oldTask in oldTasks {
            modelContext.delete(oldTask)
        }
        
        try modelContext.save()
        
        #if DEBUG
        print("💾 Saved \(tasks.count) completed tasks to SwiftData")
        #endif
    }
    
    func fetchCompletedTasks() -> [CompletedTask] {
        let descriptor = FetchDescriptor<SDCompletedTask>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        guard let sdTasks = try? modelContext.fetch(descriptor) else { return [] }
        return sdTasks.map { $0.toCompletedTask() }
    }
    
    // MARK: - Activity Events
    
    func saveActivityEvents(_ events: [ActivityEvent]) throws {
        let existingIds = Set(try modelContext.fetch(FetchDescriptor<SDActivityEvent>()).map { $0.id })
        
        for event in events {
            let descriptor = FetchDescriptor<SDActivityEvent>(predicate: #Predicate { $0.id == event.id })
            let existing = try modelContext.fetch(descriptor).first
            
            if let existing = existing {
                existing.objectType = event.objectType
                existing.objectId = event.objectId
                existing.eventType = event.eventType
                existing.eventDate = event.eventDate
                existing.parentProjectId = event.parentProjectId
                existing.initiatorId = event.initiatorId
                existing.extraDataContent = event.extraData?.content
                existing.extraDataName = event.extraData?.name
                existing.extraDataLastContent = event.extraData?.lastContent
                existing.extraDataDueDate = event.extraData?.dueDate
                existing.extraDataClient = event.extraData?.client
                existing.lastSynced = Date()
            } else {
                let sdEvent = SDActivityEvent.from(event)
                modelContext.insert(sdEvent)
            }
        }
        
        try modelContext.save()
        
        #if DEBUG
        print("💾 Saved \(events.count) activity events to SwiftData")
        #endif
    }
    
    func fetchActivityEvents(limit: Int = 100) -> [ActivityEvent] {
        let descriptor = FetchDescriptor<SDActivityEvent>(
            sortBy: [SortDescriptor(\.eventDate, order: .reverse)]
        )
        guard let sdEvents = try? modelContext.fetch(descriptor) else { return [] }
        return sdEvents.prefix(limit).map { $0.toActivityEvent() }
    }
    
    // MARK: - User Stats
    
    func saveUserStats(_ stats: UserStats, userId: String) throws {
        let descriptor = FetchDescriptor<SDUserStats>(predicate: #Predicate { $0.userId == userId })
        let existing = try modelContext.fetch(descriptor).first
        
        if let existing = existing {
            existing.karmaLastUpdate = stats.karmaLastUpdate
            existing.karmaTrend = stats.karmaTrend
            existing.completedCount = stats.completedCount
            existing.dailyGoal = stats.goals?.dailyGoal
            existing.weeklyGoal = stats.goals?.weeklyGoal
            existing.lastSynced = Date()
        } else {
            let sdStats = SDUserStats.from(stats, userId: userId)
            modelContext.insert(sdStats)
        }
        
        try modelContext.save()
    }
    
    func fetchUserStats(userId: String) -> UserStats? {
        let descriptor = FetchDescriptor<SDUserStats>(predicate: #Predicate { $0.userId == userId })
        guard let sdStats = try? modelContext.fetch(descriptor).first else { return nil }
        return sdStats.toUserStats()
    }
    
    // MARK: - Utility
    
    func clearAllData() throws {
        try modelContext.delete(model: SDUser.self)
        try modelContext.delete(model: SDProject.self)
        try modelContext.delete(model: SDTask.self)
        try modelContext.delete(model: SDSection.self)
        try modelContext.delete(model: SDCollaborator.self)
        try modelContext.delete(model: SDCompletedTask.self)
        try modelContext.delete(model: SDActivityEvent.self)
        try modelContext.delete(model: SDUserStats.self)
        try modelContext.save()
        
        #if DEBUG
        print("🗑️ Cleared all SwiftData")
        #endif
    }
    
    func getLastSyncDate() -> Date? {
        // Get the oldest lastSynced date across all entities
        let userDescriptor = FetchDescriptor<SDUser>(sortBy: [SortDescriptor(\.lastSynced)])
        if let user = try? modelContext.fetch(userDescriptor).first {
            return user.lastSynced
        }
        return nil
    }
}
