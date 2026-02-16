import Foundation

// MARK: - User

struct TodoistUser: Codable, Identifiable {
    let id: String
    let fullName: String
    let email: String

    var displayName: String { fullName }
    var initials: String {
        let parts = fullName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(fullName.prefix(2)).uppercased()
    }

    private enum CodingKeys: String, CodingKey {
        case id, email
        case fullName = "full_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id can be String or Int from different endpoints
        if let strId = try? c.decode(String.self, forKey: .id) {
            id = strId
        } else if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = ""
        }
        fullName = (try? c.decode(String.self, forKey: .fullName)) ?? "User"
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
    }
}

// MARK: - Project

struct TodoistProject: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let color: String
    let parentId: String?
    let order: Int?
    let commentCount: Int?
    let isShared: Bool
    let isFavorite: Bool
    let isInboxProject: Bool?
    let viewStyle: String?

    var isSubProject: Bool { parentId != nil }

    static func == (lhs: TodoistProject, rhs: TodoistProject) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // Todoist API v1 uses: shared (not is_shared), inbox_project, child_order
    private enum CodingKeys: String, CodingKey {
        case id, name, color
        case parentId = "parent_id"
        case commentCount = "comment_count"
        case isFavorite = "is_favorite"
        case viewStyle = "view_style"
        // These have multiple possible key names
        case shared, isShared = "is_shared"
        case inboxProject = "inbox_project", isInboxProject = "is_inbox_project"
        case childOrder = "child_order", order
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Untitled"
        color = (try? c.decode(String.self, forKey: .color)) ?? "charcoal"
        parentId = try? c.decodeIfPresent(String.self, forKey: .parentId)
        commentCount = try? c.decodeIfPresent(Int.self, forKey: .commentCount)
        isFavorite = (try? c.decode(Bool.self, forKey: .isFavorite)) ?? false
        viewStyle = try? c.decodeIfPresent(String.self, forKey: .viewStyle)

        // "shared" or "is_shared"
        if let val = try? c.decode(Bool.self, forKey: .shared) {
            isShared = val
        } else if let val = try? c.decode(Bool.self, forKey: .isShared) {
            isShared = val
        } else {
            isShared = false
        }

        // "inbox_project" or "is_inbox_project"
        if let val = try? c.decode(Bool.self, forKey: .inboxProject) {
            isInboxProject = val
        } else if let val = try? c.decode(Bool.self, forKey: .isInboxProject) {
            isInboxProject = val
        } else {
            isInboxProject = nil
        }

        // "child_order" or "order"
        if let val = try? c.decode(Int.self, forKey: .childOrder) {
            order = val
        } else if let val = try? c.decode(Int.self, forKey: .order) {
            order = val
        } else {
            order = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(color, forKey: .color)
        try c.encodeIfPresent(parentId, forKey: .parentId)
        try c.encodeIfPresent(commentCount, forKey: .commentCount)
        try c.encode(isFavorite, forKey: .isFavorite)
        try c.encodeIfPresent(viewStyle, forKey: .viewStyle)
        try c.encode(isShared, forKey: .isShared)
        try c.encodeIfPresent(isInboxProject, forKey: .isInboxProject)
        try c.encodeIfPresent(order, forKey: .order)
    }
}

// MARK: - Task

struct TodoistTask: Codable, Identifiable {
    let id: String
    let content: String
    let description: String?
    let projectId: String
    let sectionId: String?
    let parentId: String?
    let order: Int?
    let priority: Int
    let due: DueDate?
    let labels: [String]
    let assigneeId: String?
    let assignerId: String?
    let commentCount: Int?
    let createdAt: String?
    let creatorId: String?
    let url: String?
    let isCompleted: Bool?
    let deadline: Deadline?
    let duration: TaskDuration?

    var isOverdue: Bool {
        guard let due = due, let dueDate = due.parsedDate else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date()) && !(isCompleted ?? false)
    }

    var daysOverdue: Int? {
        guard isOverdue, let due = due, let dueDate = due.parsedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day
    }

    var uiPriority: Int { 5 - priority }

    private enum CodingKeys: String, CodingKey {
        case id, content, description, priority, due, labels, deadline, duration, url, order
        case projectId = "project_id"
        case sectionId = "section_id"
        case parentId = "parent_id"
        case assigneeId = "assignee_id"
        case assignerId = "assigner_id"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case creatorId = "creator_id"
        case isCompleted = "is_completed"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        projectId = (try? c.decode(String.self, forKey: .projectId)) ?? ""
        sectionId = try? c.decodeIfPresent(String.self, forKey: .sectionId)
        parentId = try? c.decodeIfPresent(String.self, forKey: .parentId)
        order = try? c.decodeIfPresent(Int.self, forKey: .order)
        priority = (try? c.decode(Int.self, forKey: .priority)) ?? 1
        due = try? c.decodeIfPresent(DueDate.self, forKey: .due)
        labels = (try? c.decode([String].self, forKey: .labels)) ?? []
        // assigneeId can be String or Int from API
        if let strVal = try? c.decodeIfPresent(String.self, forKey: .assigneeId) {
            assigneeId = strVal
        } else if let intVal = try? c.decodeIfPresent(Int.self, forKey: .assigneeId) {
            assigneeId = String(intVal)
        } else {
            assigneeId = nil
        }
        // assignerId can be String or Int from API
        if let strVal = try? c.decodeIfPresent(String.self, forKey: .assignerId) {
            assignerId = strVal
        } else if let intVal = try? c.decodeIfPresent(Int.self, forKey: .assignerId) {
            assignerId = String(intVal)
        } else {
            assignerId = nil
        }
        commentCount = try? c.decodeIfPresent(Int.self, forKey: .commentCount)
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
        // creatorId can be String or Int from API
        if let strVal = try? c.decodeIfPresent(String.self, forKey: .creatorId) {
            creatorId = strVal
        } else if let intVal = try? c.decodeIfPresent(Int.self, forKey: .creatorId) {
            creatorId = String(intVal)
        } else {
            creatorId = nil
        }
        url = try? c.decodeIfPresent(String.self, forKey: .url)
        isCompleted = try? c.decodeIfPresent(Bool.self, forKey: .isCompleted)
        deadline = try? c.decodeIfPresent(Deadline.self, forKey: .deadline)
        duration = try? c.decodeIfPresent(TaskDuration.self, forKey: .duration)
    }
}

struct DueDate: Codable {
    let date: String
    let string: String?
    let lang: String?
    let isRecurring: Bool
    let datetime: String?
    let timezone: String?

    var parsedDate: Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        if let datetime = datetime {
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let d = df.date(from: datetime) { return d }
            df.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            if let d = df.date(from: datetime) { return d }
        }
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: date)
    }

    var displayString: String {
        guard let parsed = parsedDate else { return date }
        let cal = Calendar.current
        if cal.isDateInToday(parsed) { return "Today" }
        if cal.isDateInTomorrow(parsed) { return "Tomorrow" }
        if cal.isDateInYesterday(parsed) { return "Yesterday" }
        let df = DateFormatter()
        df.dateFormat = cal.isDate(parsed, equalTo: Date(), toGranularity: .year) ? "MMM d" : "MMM d, yyyy"
        return df.string(from: parsed)
    }

    private enum CodingKeys: String, CodingKey {
        case date, string, lang, datetime, timezone
        case isRecurring = "is_recurring"
    }
}

struct Deadline: Codable {
    let date: String?
    let lang: String?
    let string: String?
}

struct TaskDuration: Codable {
    let amount: Int
    let unit: String
}

// MARK: - Section

struct TodoistSection: Codable, Identifiable {
    let id: String
    let projectId: String
    let order: Int
    let name: String

    private enum CodingKeys: String, CodingKey {
        case id, name
        case projectId = "project_id"
        case order
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        projectId = (try? c.decode(String.self, forKey: .projectId)) ?? ""
        // order might be "section_order" in some responses
        order = (try? c.decode(Int.self, forKey: .order)) ?? 0
    }
}

// MARK: - Collaborator

struct Collaborator: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    static func == (lhs: Collaborator, rhs: Collaborator) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(id: String, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let strId = try? c.decode(String.self, forKey: .id) {
            id = strId
        } else if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = ""
        }
        // Sync API uses "full_name", REST API uses "name"
        if let fullName = try? c.decode(String.self, forKey: .fullName) {
            name = fullName
        } else if let nameVal = try? c.decode(String.self, forKey: .name) {
            name = nameVal
        } else {
            name = "Unknown"
        }
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, email
        case fullName = "full_name"
    }
}

// MARK: - Collaborator State (from Sync API)

struct CollaboratorState: Codable {
    let projectId: String
    let userId: String
    let state: String
    let isDeleted: Bool

    private enum CodingKeys: String, CodingKey {
        case projectId = "project_id"
        case userId = "user_id"
        case state
        case isDeleted = "is_deleted"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        projectId = (try? c.decode(String.self, forKey: .projectId)) ?? ""
        // userId can be String or Int
        if let strVal = try? c.decode(String.self, forKey: .userId) {
            userId = strVal
        } else if let intVal = try? c.decode(Int.self, forKey: .userId) {
            userId = String(intVal)
        } else {
            userId = ""
        }
        state = (try? c.decode(String.self, forKey: .state)) ?? "active"
        isDeleted = (try? c.decode(Bool.self, forKey: .isDeleted)) ?? false
    }
}

// MARK: - Sync Response

struct SyncResponse: Codable {
    let collaborators: [Collaborator]
    let collaboratorStates: [CollaboratorState]
    let syncToken: String
    let fullSync: Bool

    private enum CodingKeys: String, CodingKey {
        case collaborators
        case collaboratorStates = "collaborator_states"
        case syncToken = "sync_token"
        case fullSync = "full_sync"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        collaborators = (try? c.decode([Collaborator].self, forKey: .collaborators)) ?? []
        collaboratorStates = (try? c.decode([CollaboratorState].self, forKey: .collaboratorStates)) ?? []
        syncToken = (try? c.decode(String.self, forKey: .syncToken)) ?? ""
        fullSync = (try? c.decode(Bool.self, forKey: .fullSync)) ?? false
    }
}

// MARK: - Completed Task

struct CompletedTask: Codable, Identifiable {
    let id: String
    let taskId: String
    let content: String
    let projectId: String
    let sectionId: String?
    let completedAt: String
    let userId: String?

    var completedDate: Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: completedAt) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: completedAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id, content
        case taskId = "task_id"
        case projectId = "project_id"
        case sectionId = "section_id"
        case completedAt = "completed_at"
        case userId = "user_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        taskId = (try? c.decode(String.self, forKey: .taskId)) ?? ""
        content = (try? c.decode(String.self, forKey: .content)) ?? ""
        projectId = (try? c.decode(String.self, forKey: .projectId)) ?? ""
        sectionId = try? c.decodeIfPresent(String.self, forKey: .sectionId)
        completedAt = (try? c.decode(String.self, forKey: .completedAt)) ?? ""
        // userId can be String or Int from API
        if let strVal = try? c.decodeIfPresent(String.self, forKey: .userId) {
            userId = strVal
        } else if let intVal = try? c.decodeIfPresent(Int.self, forKey: .userId) {
            userId = String(intVal)
        } else {
            userId = nil
        }
    }
}

struct CompletedTasksResponse: Codable {
    let items: [CompletedTask]
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decode([CompletedTask].self, forKey: .items)) ?? []
        nextCursor = try? c.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}

// MARK: - Activity

struct ActivityEvent: Codable, Identifiable {
    let id: String
    let objectType: String
    let objectId: String
    let eventType: String
    let eventDate: String
    let parentProjectId: String?
    let initiatorId: String?
    let extraData: ActivityExtraData?

    var eventDateParsed: Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: eventDate) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: eventDate)
    }

    var emoji: String {
        switch eventType {
        case "added": return "➕"
        case "completed": return "✅"
        case "updated": return "✏️"
        case "deleted": return "🗑️"
        default: return "📌"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case objectType = "object_type"
        case objectId = "object_id"
        case eventType = "event_type"
        case eventDate = "event_date"
        case parentProjectId = "parent_project_id"
        case initiatorId = "initiator_id"
        case extraData = "extra_data"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? c.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        }
        objectType = (try? c.decode(String.self, forKey: .objectType)) ?? ""
        if let intObjId = try? c.decode(Int.self, forKey: .objectId) {
            objectId = String(intObjId)
        } else {
            objectId = (try? c.decode(String.self, forKey: .objectId)) ?? ""
        }
        eventType = (try? c.decode(String.self, forKey: .eventType)) ?? ""
        eventDate = (try? c.decode(String.self, forKey: .eventDate)) ?? ""
        parentProjectId = try? c.decodeIfPresent(String.self, forKey: .parentProjectId)
        initiatorId = try? c.decodeIfPresent(String.self, forKey: .initiatorId)
        extraData = try? c.decodeIfPresent(ActivityExtraData.self, forKey: .extraData)
    }
}

struct ActivityExtraData: Codable {
    let content: String?
    let name: String?
    let lastContent: String?
    let dueDate: String?
    let client: String?

    private enum CodingKeys: String, CodingKey {
        case content, name, client
        case lastContent = "last_content"
        case dueDate = "due_date"
    }
}

struct ActivityResponse: Codable {
    let events: [ActivityEvent]
    let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case events
        case nextCursor = "next_cursor"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        events = (try? c.decode([ActivityEvent].self, forKey: .events)) ?? []
        nextCursor = try? c.decodeIfPresent(String.self, forKey: .nextCursor)
    }
}

// MARK: - User Stats

struct UserStats: Codable {
    let karmaLastUpdate: Double?
    let karmaTrend: String?
    let completedCount: Int?
    let goals: UserGoals?

    struct UserGoals: Codable {
        let dailyGoal: Int?
        let weeklyGoal: Int?
        private enum CodingKeys: String, CodingKey {
            case dailyGoal = "daily_goal"
            case weeklyGoal = "weekly_goal"
        }
    }

    private enum CodingKeys: String, CodingKey {
        case goals
        case karmaLastUpdate = "karma_last_update"
        case karmaTrend = "karma_trend"
        case completedCount = "completed_count"
    }
}

