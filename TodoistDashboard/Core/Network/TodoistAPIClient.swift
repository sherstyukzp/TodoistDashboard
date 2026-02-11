import Foundation

actor TodoistAPIClient {
    private let baseURL = "https://api.todoist.com/api/v1"
    private let token: String
    private let session: URLSession
    private let decoder: JSONDecoder

    // Rate limiting
    private var requestTimestamps: [Date] = []
    private let maxRequests = 900
    private let windowDuration: TimeInterval = 900

    init(token: String) {
        self.token = token
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        // IMPORTANT: Do NOT use .convertFromSnakeCase since we have explicit CodingKeys
        let decoder = JSONDecoder()
        self.decoder = decoder
    }

    // MARK: - Core Request (returns raw Data for flexible decoding)

    private func rawRequest(
        endpoint: String,
        params: [String: String] = [:]
    ) async throws -> Data {
        try await enforceRateLimit()

        var components = URLComponents(string: "\(baseURL)\(endpoint)")!
        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw TodoistError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TodoistError.invalidResponse
        }

        #if DEBUG
        let preview = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
        print("📡 \(endpoint) → \(httpResponse.statusCode) | \(preview.prefix(200))")
        #endif

        switch httpResponse.statusCode {
        case 200..<300:
            return data
        case 401:
            throw TodoistError.unauthorized
        case 403:
            throw TodoistError.forbidden
        case 429:
            throw TodoistError.rateLimited
        case 500..<600:
            throw TodoistError.serverError(httpResponse.statusCode)
        default:
            throw TodoistError.apiError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Typed request

    func request<T: Decodable>(endpoint: String, params: [String: String] = [:]) async throws -> T {
        let data = try await rawRequest(endpoint: endpoint, params: params)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("❌ Decode error for \(endpoint): \(error)")
            let preview = String(data: data.prefix(1000), encoding: .utf8) ?? ""
            print("   Response: \(preview)")
            #endif
            throw TodoistError.decodingError("\(endpoint): \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch all with pagination
    // Todoist API v1 returns either:
    //   - plain JSON array: [item1, item2, ...]
    //   - paginated object: { "results": [...], "next_cursor": "..." }

    func fetchAll<T: Decodable>(
        endpoint: String,
        params: [String: String] = [:]
    ) async throws -> [T] {
        var allItems: [T] = []
        var cursor: String? = nil

        repeat {
            var p = params
            if let cursor { p["cursor"] = cursor }

            let data = try await rawRequest(endpoint: endpoint, params: p)

            // Try plain array first
            if let items = try? decoder.decode([T].self, from: data) {
                allItems.append(contentsOf: items)
                // Plain array = no pagination
                cursor = nil
            }
            // Try paginated response { "results": [...], "next_cursor": ... }
            else if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let results = json["results"] {
                let resultsData = try JSONSerialization.data(withJSONObject: results)
                let items = try decoder.decode([T].self, from: resultsData)
                allItems.append(contentsOf: items)
                cursor = json["next_cursor"] as? String
            }
            else {
                #if DEBUG
                let preview = String(data: data.prefix(500), encoding: .utf8) ?? ""
                print("⚠️ fetchAll could not parse \(endpoint): \(preview.prefix(300))")
                #endif
                break
            }
        } while cursor != nil

        return allItems
    }

    // MARK: - Completed Tasks

    func fetchCompletedTasks(since: String, until: String, projectId: String? = nil) async throws -> [CompletedTask] {
        var params: [String: String] = [
            "since": since,
            "until": until,
            "limit": "200"
        ]
        if let projectId { params["project_id"] = projectId }

        var allTasks: [CompletedTask] = []
        var cursor: String? = nil

        repeat {
            var p = params
            if let cursor { p["cursor"] = cursor }

            let data = try await rawRequest(endpoint: "/tasks/completed", params: p)

            // Try paginated response with "items" key
            if let response = try? decoder.decode(CompletedTasksResponse.self, from: data) {
                allTasks.append(contentsOf: response.items)
                cursor = response.nextCursor
            }
            // Try plain array
            else if let items = try? decoder.decode([CompletedTask].self, from: data) {
                allTasks.append(contentsOf: items)
                cursor = nil
            }
            else {
                #if DEBUG
                print("⚠️ Could not parse completed tasks response")
                #endif
                break
            }
        } while cursor != nil

        return allTasks
    }

    // MARK: - Activity Log

    func fetchActivity(limit: Int = 50, eventType: String? = nil, projectId: String? = nil) async throws -> [ActivityEvent] {
        var params: [String: String] = ["limit": "\(limit)"]
        if let eventType { params["event_type"] = eventType }
        if let projectId { params["project_id"] = projectId }

        let data = try await rawRequest(endpoint: "/activity/get", params: params)

        // Try { "events": [...] }
        if let response = try? decoder.decode(ActivityResponse.self, from: data) {
            return response.events
        }
        // Try plain array
        if let events = try? decoder.decode([ActivityEvent].self, from: data) {
            return events
        }

        #if DEBUG
        let preview = String(data: data.prefix(500), encoding: .utf8) ?? ""
        print("⚠️ Could not parse activity: \(preview.prefix(300))")
        #endif
        return []
    }

    // MARK: - Rate Limiting

    private func enforceRateLimit() async throws {
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowDuration)
        requestTimestamps = requestTimestamps.filter { $0 > windowStart }

        if requestTimestamps.count >= maxRequests {
            let oldestInWindow = requestTimestamps.first!
            let waitTime = oldestInWindow.addingTimeInterval(windowDuration).timeIntervalSince(now)
            if waitTime > 0 {
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        requestTimestamps.append(now)
    }
}

// MARK: - Error Types

enum TodoistError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case rateLimited
    case serverError(Int)
    case apiError(statusCode: Int)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .invalidResponse: return "Invalid server response"
        case .unauthorized: return "Invalid API token"
        case .forbidden: return "Access denied (may require Pro plan)"
        case .rateLimited: return "Rate limit exceeded. Please wait."
        case .serverError(let code): return "Server error (\(code))"
        case .apiError(let code): return "API error (\(code))"
        case .decodingError(let msg): return "Data error: \(msg)"
        }
    }
}
