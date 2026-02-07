import Foundation

// Assumed notion-cli command shapes based on salmonumbrella/notion-cli README.
// The adapter calls `notion` (from PATH) with NOTION_OUTPUT=json set in the
// process environment for every invocation.
//
// Key commands used:
//   notion db query <db-id> --filter '<json>' --all --results-only --output json
//   notion page get <page-id> --output json
//   notion page update <page-id> --properties '<json>' --output json
//   notion auth status --output json
//
// TODO: Verify exact flag names and JSON shapes against notion-cli v0.6+.
//       If notion-cli changes its interface, update the templates below.

enum NotionCLI {

    // MARK: - Environment

    static var databaseId: String {
        get throws {
            guard let id = ProcessInfo.processInfo.environment["NOTION_TASKS_DB_ID"], !id.isEmpty else {
                throw NTaskError.misconfigured("NOTION_TASKS_DB_ID environment variable is not set")
            }
            return id
        }
    }

    static var token: String {
        get throws {
            guard let t = ProcessInfo.processInfo.environment["NOTION_TOKEN"], !t.isEmpty else {
                throw NTaskError.misconfigured("NOTION_TOKEN environment variable is not set")
            }
            return t
        }
    }

    private static var notionEnv: [String: String] {
        ["NOTION_OUTPUT": "json"]
    }

    // MARK: - Doctor

    static func checkVersion() async throws -> String {
        let found = await ProcessRunner.findExecutable("notion")
        guard found else {
            throw NTaskError.cliMissing("notion binary not found in PATH")
        }

        let result = try await ProcessRunner.run(
            executable: "notion",
            arguments: ["--version"],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.cliMissing("notion --version failed: \(redactStderr(result.stderr))")
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func checkDatabaseAccess() async throws {
        let dbId = try databaseId
        let result = try await ProcessRunner.run(
            executable: "notion",
            arguments: ["db", "query", dbId, "--limit", "1", "--results-only"],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Database query failed: \(redactStderr(result.stderr))")
        }
    }

    // MARK: - Query

    /// Query READY tasks from the database.
    /// Uses notion-cli filter to find tasks with Status = READY.
    static func queryReadyTasks() async throws -> [NotionPage] {
        let dbId = try databaseId
        let filter = try buildFilterJSON([
            "property": "Status",
            "select": ["equals": "READY"]
        ])
        let result = try await ProcessRunner.run(
            executable: "notion",
            arguments: ["db", "query", dbId, "--filter", filter, "--all", "--results-only"],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to query ready tasks: \(redactStderr(result.stderr))")
        }
        return parsePages(from: result.stdout)
    }

    /// Resolve a TaskID to its Notion page by querying the database.
    static func resolveTaskIdToPage(_ taskId: String) async throws -> NotionPage {
        let dbId = try databaseId
        let filter = try buildFilterJSON([
            "property": "TaskID",
            "rich_text": ["equals": taskId]
        ])
        let result = try await ProcessRunner.run(
            executable: "notion",
            arguments: ["db", "query", dbId, "--filter", filter, "--results-only"],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to resolve TaskID '\(taskId)': \(redactStderr(result.stderr))")
        }
        let pages = parsePages(from: result.stdout)
        guard let page = pages.first else {
            throw NTaskError.misconfigured("No task found with TaskID '\(taskId)'")
        }
        return page
    }

    // MARK: - Page operations

    /// Retrieve a page by its Notion page ID.
    static func retrievePage(_ pageId: String) async throws -> NotionPage {
        let result = try await ProcessRunner.run(
            executable: "notion",
            arguments: ["page", "get", pageId],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to retrieve page '\(pageId)': \(redactStderr(result.stderr))")
        }
        guard let json = parseJSON(result.stdout) as? [String: Any],
              let page = NotionPage.from(json: json) else {
            throw NTaskError.apiError("Failed to parse page response")
        }
        return page
    }

    /// Update page properties for claiming a task.
    static func updateForClaim(
        pageId: String,
        runId: String,
        agentName: String,
        lockToken: String,
        lockedUntil: String
    ) async throws {
        let properties = claimProperties(
            runId: runId,
            agentName: agentName,
            lockToken: lockToken,
            lockedUntil: lockedUntil
        )
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties for heartbeat (extend lease).
    static func updateForHeartbeat(
        pageId: String,
        lockedUntil: String
    ) async throws {
        let properties: [String: Any] = [
            "LockedUntil": ["date": ["start": lockedUntil]]
        ]
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties to mark task as DONE.
    static func updateForComplete(
        pageId: String,
        artifacts: String,
        doneAt: String
    ) async throws {
        let properties: [String: Any] = [
            "Status": ["select": ["name": "DONE"]],
            "Artifacts": ["rich_text": [["text": ["content": artifacts]]]],
            "DoneAt": ["date": ["start": doneAt]],
            "ClaimedBy": ["select": NSNull()],
            "AgentRunID": ["rich_text": []],
            "AgentName": ["rich_text": []],
            "LockToken": ["rich_text": []],
            "LockedUntil": ["date": NSNull()]
        ]
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties to mark task as BLOCKED.
    static func updateForBlock(
        pageId: String,
        reason: String,
        unblockAction: String,
        nextCheck: String?
    ) async throws {
        var properties: [String: Any] = [
            "Status": ["select": ["name": "BLOCKED"]],
            "BlockerReason": ["rich_text": [["text": ["content": reason]]]],
            "UnblockAction": ["rich_text": [["text": ["content": unblockAction]]]],
            "ClaimedBy": ["select": NSNull()],
            "AgentRunID": ["rich_text": []],
            "AgentName": ["rich_text": []],
            "LockToken": ["rich_text": []],
            "LockedUntil": ["date": NSNull()]
        ]
        if let nextCheck {
            properties["NextCheckAt"] = ["date": ["start": nextCheck]]
        }
        try await updatePage(pageId: pageId, properties: properties)
    }

    // MARK: - Create

    /// Create a new page (task) in the database.
    static func createPage(properties: [String: Any]) async throws -> NotionPage {
        let dbId = try databaseId
        guard let data = try? JSONSerialization.data(withJSONObject: properties),
              let jsonStr = String(data: data, encoding: .utf8) else {
            throw NTaskError.apiError("Failed to serialize properties JSON")
        }
        let result = try await ProcessRunner.run(
            executable: "notion",
            arguments: ["page", "create", "--parent", dbId, "--properties", jsonStr],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to create page: \(redactStderr(result.stderr))")
        }
        guard let json = parseJSON(result.stdout) as? [String: Any],
              let page = NotionPage.from(json: json) else {
            throw NTaskError.apiError("Failed to parse created page response")
        }
        return page
    }

    // MARK: - Query (general)

    /// Query tasks with optional status filter and limit.
    static func queryTasks(status: String? = nil, limit: Int = 50) async throws -> [NotionPage] {
        let dbId = try databaseId
        var arguments = ["db", "query", dbId, "--all", "--results-only"]
        if let status {
            let filter = try buildFilterJSON([
                "property": "Status",
                "select": ["equals": status]
            ])
            arguments += ["--filter", filter]
        }
        if limit > 0 {
            arguments += ["--limit", String(limit)]
        }
        let result = try await ProcessRunner.run(
            executable: "notion",
            arguments: arguments,
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to query tasks: \(redactStderr(result.stderr))")
        }
        return parsePages(from: result.stdout)
    }

    // MARK: - Comments

    /// Add a comment to a page.
    static func addComment(pageId: String, text: String) async throws {
        let result = try await ProcessRunner.run(
            executable: "notion",
            arguments: ["comment", "add", pageId, "--text", text],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to add comment: \(redactStderr(result.stderr))")
        }
    }

    // MARK: - Status transitions

    /// Update page properties to move task to REVIEW.
    static func updateForReview(
        pageId: String,
        artifacts: String?
    ) async throws {
        var properties: [String: Any] = [
            "Status": ["select": ["name": "REVIEW"]],
            "ClaimedBy": ["select": NSNull()],
            "AgentRunID": ["rich_text": []],
            "AgentName": ["rich_text": []],
            "LockToken": ["rich_text": []],
            "LockedUntil": ["date": NSNull()]
        ]
        if let artifacts {
            properties["Artifacts"] = ["rich_text": [["text": ["content": artifacts]]]]
        }
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties to mark task as CANCELED.
    static func updateForCancel(
        pageId: String,
        reason: String
    ) async throws {
        let properties: [String: Any] = [
            "Status": ["select": ["name": "CANCELED"]],
            "BlockerReason": ["rich_text": [["text": ["content": reason]]]],
            "ClaimedBy": ["select": NSNull()],
            "AgentRunID": ["rich_text": []],
            "AgentName": ["rich_text": []],
            "LockToken": ["rich_text": []],
            "LockedUntil": ["date": NSNull()]
        ]
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update arbitrary page properties.
    static func updateProperties(pageId: String, properties: [String: Any]) async throws {
        try await updatePage(pageId: pageId, properties: properties)
    }

    // MARK: - Private helpers

    private static func claimProperties(
        runId: String,
        agentName: String,
        lockToken: String,
        lockedUntil: String
    ) -> [String: Any] {
        [
            "Status": ["select": ["name": "IN_PROGRESS"]],
            "ClaimedBy": ["select": ["name": "AGENT"]],
            "AgentRunID": ["rich_text": [["text": ["content": runId]]]],
            "AgentName": ["rich_text": [["text": ["content": agentName]]]],
            "LockToken": ["rich_text": [["text": ["content": lockToken]]]],
            "LockedUntil": ["date": ["start": lockedUntil]],
            "StartedAt": ["date": ["start": Time.iso8601(Time.now())]]
        ]
    }

    private static func updatePage(pageId: String, properties: [String: Any]) async throws {
        guard let data = try? JSONSerialization.data(withJSONObject: properties),
              let jsonStr = String(data: data, encoding: .utf8) else {
            throw NTaskError.apiError("Failed to serialize properties JSON")
        }
        let result = try await ProcessRunner.run(
            executable: "notion",
            arguments: ["page", "update", pageId, "--properties", jsonStr],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to update page '\(pageId)': \(redactStderr(result.stderr))")
        }
    }

    private static func buildFilterJSON(_ dict: [String: Any]) throws -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            throw NTaskError.apiError("Failed to serialize filter JSON")
        }
        return str
    }

    /// Redact NOTION_TOKEN from any string to prevent leaking secrets in error output.
    static func redact(_ text: String) -> String {
        redactStderr(text)
    }

    private static func redactStderr(_ stderr: String) -> String {
        guard let token = ProcessInfo.processInfo.environment["NOTION_TOKEN"],
              !token.isEmpty else {
            return stderr
        }
        return stderr.replacingOccurrences(of: token, with: "[REDACTED]")
    }

    private static func parsePages(from jsonString: String) -> [NotionPage] {
        guard let parsed = parseJSON(jsonString) else { return [] }
        if let array = parsed as? [[String: Any]] {
            return array.compactMap { NotionPage.from(json: $0) }
        }
        if let dict = parsed as? [String: Any],
           let results = dict["results"] as? [[String: Any]] {
            return results.compactMap { NotionPage.from(json: $0) }
        }
        if let dict = parsed as? [String: Any],
           let page = NotionPage.from(json: dict) {
            return [page]
        }
        return []
    }

    private static func parseJSON(_ string: String) -> Any? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
