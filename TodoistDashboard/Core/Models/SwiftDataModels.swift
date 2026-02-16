import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model
final class SDUser {
    @Attribute(.unique) var id: String
    var fullName: String
    var email: String
    var lastSynced: Date
    
    init(id: String, fullName: String, email: String, lastSynced: Date = Date()) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.lastSynced = lastSynced
    }
    
    func toTodoistUser() -> TodoistUser {
        TodoistUser(id: id, fullName: fullName, email: email)
    }
    
    static func from(_ user: TodoistUser) -> SDUser {
        SDUser(id: user.id, fullName: user.fullName, email: user.email)
    }
}

extension TodoistUser {
    init(id: String, fullName: String, email: String) {
        self.id = id
        self.fullName = fullName
        self.email = email
    }
}

@Model
final class SDProject {
    @Attribute(.unique) var id: String
    var name: String
    var color: String
    var parentId: String?
    var order: Int?
    var commentCount: Int?
    var isShared: Bool
    var isFavorite: Bool
    var isInboxProject: Bool?
    var viewStyle: String?
    var lastSynced: Date
    
    @Relationship(deleteRule: .cascade, inverse: \SDTask.project)
    var tasks: [SDTask]?
    
    @Relationship(deleteRule: .cascade, inverse: \SDSection.project)
    var sections: [SDSection]?
    
    init(id: String, name: String, color: String, parentId: String? = nil, order: Int? = nil,
         commentCount: Int? = nil, isShared: Bool = false, isFavorite: Bool = false,
         isInboxProject: Bool? = nil, viewStyle: String? = nil, lastSynced: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
        self.parentId = parentId
        self.order = order
        self.commentCount = commentCount
        self.isShared = isShared
        self.isFavorite = isFavorite
        self.isInboxProject = isInboxProject
        self.viewStyle = viewStyle
        self.lastSynced = lastSynced
    }
    
    func toTodoistProject() -> TodoistProject {
        TodoistProject(
            id: id,
            name: name,
            color: color,
            parentId: parentId,
            order: order,
            commentCount: commentCount,
            isShared: isShared,
            isFavorite: isFavorite,
            isInboxProject: isInboxProject,
            viewStyle: viewStyle
        )
    }
    
    static func from(_ project: TodoistProject) -> SDProject {
        SDProject(
            id: project.id,
            name: project.name,
            color: project.color,
            parentId: project.parentId,
            order: project.order,
            commentCount: project.commentCount,
            isShared: project.isShared,
            isFavorite: project.isFavorite,
            isInboxProject: project.isInboxProject,
            viewStyle: project.viewStyle
        )
    }
}

extension TodoistProject {
    init(id: String, name: String, color: String, parentId: String?, order: Int?,
         commentCount: Int?, isShared: Bool, isFavorite: Bool, isInboxProject: Bool?, viewStyle: String?) {
        self.id = id
        self.name = name
        self.color = color
        self.parentId = parentId
        self.order = order
        self.commentCount = commentCount
        self.isShared = isShared
        self.isFavorite = isFavorite
        self.isInboxProject = isInboxProject
        self.viewStyle = viewStyle
    }
}

@Model
final class SDTask {
    @Attribute(.unique) var id: String
    var content: String
    var taskDescription: String?
    var projectId: String
    var sectionId: String?
    var parentId: String?
    var order: Int?
    var priority: Int
    var dueDate: String?
    var dueDatetime: String?
    var dueString: String?
    var dueLang: String?
    var dueIsRecurring: Bool
    var dueTimezone: String?
    var labels: [String]
    var assigneeId: String?
    var assignerId: String?
    var commentCount: Int?
    var createdAt: String?
    var creatorId: String?
    var url: String?
    var isCompleted: Bool
    var lastSynced: Date
    
    var project: SDProject?
    
    init(id: String, content: String, taskDescription: String? = nil, projectId: String,
         sectionId: String? = nil, parentId: String? = nil, order: Int? = nil,
         priority: Int = 1, dueDate: String? = nil, dueDatetime: String? = nil,
         dueString: String? = nil, dueLang: String? = nil, dueIsRecurring: Bool = false,
         dueTimezone: String? = nil, labels: [String] = [], assigneeId: String? = nil,
         assignerId: String? = nil, commentCount: Int? = nil, createdAt: String? = nil,
         creatorId: String? = nil, url: String? = nil, isCompleted: Bool = false,
         lastSynced: Date = Date()) {
        self.id = id
        self.content = content
        self.taskDescription = taskDescription
        self.projectId = projectId
        self.sectionId = sectionId
        self.parentId = parentId
        self.order = order
        self.priority = priority
        self.dueDate = dueDate
        self.dueDatetime = dueDatetime
        self.dueString = dueString
        self.dueLang = dueLang
        self.dueIsRecurring = dueIsRecurring
        self.dueTimezone = dueTimezone
        self.labels = labels
        self.assigneeId = assigneeId
        self.assignerId = assignerId
        self.commentCount = commentCount
        self.createdAt = createdAt
        self.creatorId = creatorId
        self.url = url
        self.isCompleted = isCompleted
        self.lastSynced = lastSynced
    }
    
    func toTodoistTask() -> TodoistTask {
        let due = dueDate != nil ? DueDate(
            date: dueDate!,
            string: dueString,
            lang: dueLang,
            isRecurring: dueIsRecurring,
            datetime: dueDatetime,
            timezone: dueTimezone
        ) : nil
        
        return TodoistTask(
            id: id,
            content: content,
            description: taskDescription,
            projectId: projectId,
            sectionId: sectionId,
            parentId: parentId,
            order: order,
            priority: priority,
            due: due,
            labels: labels,
            assigneeId: assigneeId,
            assignerId: assignerId,
            commentCount: commentCount,
            createdAt: createdAt,
            creatorId: creatorId,
            url: url,
            isCompleted: isCompleted
        )
    }
    
    static func from(_ task: TodoistTask) -> SDTask {
        SDTask(
            id: task.id,
            content: task.content,
            taskDescription: task.description,
            projectId: task.projectId,
            sectionId: task.sectionId,
            parentId: task.parentId,
            order: task.order,
            priority: task.priority,
            dueDate: task.due?.date,
            dueDatetime: task.due?.datetime,
            dueString: task.due?.string,
            dueLang: task.due?.lang,
            dueIsRecurring: task.due?.isRecurring ?? false,
            dueTimezone: task.due?.timezone,
            labels: task.labels,
            assigneeId: task.assigneeId,
            assignerId: task.assignerId,
            commentCount: task.commentCount,
            createdAt: task.createdAt,
            creatorId: task.creatorId,
            url: task.url,
            isCompleted: task.isCompleted ?? false
        )
    }
}

extension TodoistTask {
    init(id: String, content: String, description: String?, projectId: String,
         sectionId: String?, parentId: String?, order: Int?, priority: Int,
         due: DueDate?, labels: [String], assigneeId: String?, assignerId: String?,
         commentCount: Int?, createdAt: String?, creatorId: String?, url: String?,
         isCompleted: Bool) {
        self.id = id
        self.content = content
        self.description = description
        self.projectId = projectId
        self.sectionId = sectionId
        self.parentId = parentId
        self.order = order
        self.priority = priority
        self.due = due
        self.labels = labels
        self.assigneeId = assigneeId
        self.assignerId = assignerId
        self.commentCount = commentCount
        self.createdAt = createdAt
        self.creatorId = creatorId
        self.url = url
        self.isCompleted = isCompleted
        self.deadline = nil
        self.duration = nil
    }
}



@Model
final class SDSection {
    @Attribute(.unique) var id: String
    var projectId: String
    var order: Int
    var name: String
    var lastSynced: Date
    
    var project: SDProject?
    
    init(id: String, projectId: String, order: Int, name: String, lastSynced: Date = Date()) {
        self.id = id
        self.projectId = projectId
        self.order = order
        self.name = name
        self.lastSynced = lastSynced
    }
    
    func toTodoistSection() -> TodoistSection {
        TodoistSection(id: id, projectId: projectId, order: order, name: name)
    }
    
    static func from(_ section: TodoistSection) -> SDSection {
        SDSection(id: section.id, projectId: section.projectId, order: section.order, name: section.name)
    }
}

extension TodoistSection {
    init(id: String, projectId: String, order: Int, name: String) {
        self.id = id
        self.projectId = projectId
        self.order = order
        self.name = name
    }
}

@Model
final class SDCollaborator {
    @Attribute(.unique) var id: String
    var name: String
    var email: String
    var projectIds: [String] // Projects where this collaborator is active
    var lastSynced: Date
    
    init(id: String, name: String, email: String, projectIds: [String] = [], lastSynced: Date = Date()) {
        self.id = id
        self.name = name
        self.email = email
        self.projectIds = projectIds
        self.lastSynced = lastSynced
    }
    
    func toCollaborator() -> Collaborator {
        Collaborator(id: id, name: name, email: email)
    }
    
    static func from(_ collaborator: Collaborator, projectIds: [String] = []) -> SDCollaborator {
        SDCollaborator(id: collaborator.id, name: collaborator.name, email: collaborator.email, projectIds: projectIds)
    }
}

@Model
final class SDCompletedTask {
    @Attribute(.unique) var id: String
    var taskId: String
    var content: String
    var projectId: String
    var sectionId: String?
    var completedAt: String
    var userId: String?
    var lastSynced: Date
    
    init(id: String, taskId: String, content: String, projectId: String,
         sectionId: String? = nil, completedAt: String, userId: String? = nil,
         lastSynced: Date = Date()) {
        self.id = id
        self.taskId = taskId
        self.content = content
        self.projectId = projectId
        self.sectionId = sectionId
        self.completedAt = completedAt
        self.userId = userId
        self.lastSynced = lastSynced
    }
    
    func toCompletedTask() -> CompletedTask {
        CompletedTask(id: id, taskId: taskId, content: content, projectId: projectId,
                     sectionId: sectionId, completedAt: completedAt, userId: userId)
    }
    
    static func from(_ task: CompletedTask) -> SDCompletedTask {
        SDCompletedTask(id: task.id, taskId: task.taskId, content: task.content,
                       projectId: task.projectId, sectionId: task.sectionId,
                       completedAt: task.completedAt, userId: task.userId)
    }
}

extension CompletedTask {
    init(id: String, taskId: String, content: String, projectId: String,
         sectionId: String?, completedAt: String, userId: String?) {
        self.id = id
        self.taskId = taskId
        self.content = content
        self.projectId = projectId
        self.sectionId = sectionId
        self.completedAt = completedAt
        self.userId = userId
    }
}

@Model
final class SDActivityEvent {
    @Attribute(.unique) var id: String
    var objectType: String
    var objectId: String
    var eventType: String
    var eventDate: String
    var parentProjectId: String?
    var initiatorId: String?
    var extraDataContent: String?
    var extraDataName: String?
    var extraDataLastContent: String?
    var extraDataDueDate: String?
    var extraDataClient: String?
    var lastSynced: Date
    
    init(id: String, objectType: String, objectId: String, eventType: String,
         eventDate: String, parentProjectId: String? = nil, initiatorId: String? = nil,
         extraDataContent: String? = nil, extraDataName: String? = nil,
         extraDataLastContent: String? = nil, extraDataDueDate: String? = nil,
         extraDataClient: String? = nil, lastSynced: Date = Date()) {
        self.id = id
        self.objectType = objectType
        self.objectId = objectId
        self.eventType = eventType
        self.eventDate = eventDate
        self.parentProjectId = parentProjectId
        self.initiatorId = initiatorId
        self.extraDataContent = extraDataContent
        self.extraDataName = extraDataName
        self.extraDataLastContent = extraDataLastContent
        self.extraDataDueDate = extraDataDueDate
        self.extraDataClient = extraDataClient
        self.lastSynced = lastSynced
    }
    
    func toActivityEvent() -> ActivityEvent {
        let extraData = (extraDataContent != nil || extraDataName != nil) ? ActivityExtraData(
            content: extraDataContent,
            name: extraDataName,
            lastContent: extraDataLastContent,
            dueDate: extraDataDueDate,
            client: extraDataClient
        ) : nil
        
        return ActivityEvent(
            id: id,
            objectType: objectType,
            objectId: objectId,
            eventType: eventType,
            eventDate: eventDate,
            parentProjectId: parentProjectId,
            initiatorId: initiatorId,
            extraData: extraData
        )
    }
    
    static func from(_ event: ActivityEvent) -> SDActivityEvent {
        SDActivityEvent(
            id: event.id,
            objectType: event.objectType,
            objectId: event.objectId,
            eventType: event.eventType,
            eventDate: event.eventDate,
            parentProjectId: event.parentProjectId,
            initiatorId: event.initiatorId,
            extraDataContent: event.extraData?.content,
            extraDataName: event.extraData?.name,
            extraDataLastContent: event.extraData?.lastContent,
            extraDataDueDate: event.extraData?.dueDate,
            extraDataClient: event.extraData?.client
        )
    }
}

extension ActivityEvent {
    init(id: String, objectType: String, objectId: String, eventType: String,
         eventDate: String, parentProjectId: String?, initiatorId: String?,
         extraData: ActivityExtraData?) {
        self.id = id
        self.objectType = objectType
        self.objectId = objectId
        self.eventType = eventType
        self.eventDate = eventDate
        self.parentProjectId = parentProjectId
        self.initiatorId = initiatorId
        self.extraData = extraData
    }
}



@Model
final class SDUserStats {
    @Attribute(.unique) var userId: String
    var karmaLastUpdate: Double?
    var karmaTrend: String?
    var completedCount: Int?
    var dailyGoal: Int?
    var weeklyGoal: Int?
    var lastSynced: Date
    
    init(userId: String, karmaLastUpdate: Double? = nil, karmaTrend: String? = nil,
         completedCount: Int? = nil, dailyGoal: Int? = nil, weeklyGoal: Int? = nil,
         lastSynced: Date = Date()) {
        self.userId = userId
        self.karmaLastUpdate = karmaLastUpdate
        self.karmaTrend = karmaTrend
        self.completedCount = completedCount
        self.dailyGoal = dailyGoal
        self.weeklyGoal = weeklyGoal
        self.lastSynced = lastSynced
    }
    
    func toUserStats() -> UserStats {
        let goals = (dailyGoal != nil || weeklyGoal != nil) ? UserStats.UserGoals(
            dailyGoal: dailyGoal,
            weeklyGoal: weeklyGoal
        ) : nil
        
        return UserStats(
            karmaLastUpdate: karmaLastUpdate,
            karmaTrend: karmaTrend,
            completedCount: completedCount,
            goals: goals
        )
    }
    
    static func from(_ stats: UserStats, userId: String) -> SDUserStats {
        SDUserStats(
            userId: userId,
            karmaLastUpdate: stats.karmaLastUpdate,
            karmaTrend: stats.karmaTrend,
            completedCount: stats.completedCount,
            dailyGoal: stats.goals?.dailyGoal,
            weeklyGoal: stats.goals?.weeklyGoal
        )
    }
}



