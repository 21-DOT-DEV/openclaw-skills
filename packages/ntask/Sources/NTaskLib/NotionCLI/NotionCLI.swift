import Foundation

// Assumed ntn (notion-cli) command shapes based on salmonumbrella/notion-cli README.
// The adapter calls `ntn` (from PATH) with NOTION_OUTPUT=json set in the
// process environment for every invocation.
//
// Key commands used:
//   ntn db query <db-id> --filter '<json>' --all --results-only --output json
//   ntn page get <page-id> --output json
//   ntn page update <page-id> --properties '<json>' --output json
//   ntn auth status --output json
//
// TODO: Verify exact flag names and JSON shapes against notion-cli v0.6+.
//       If notion-cli changes its interface, update the templates below.

enum NotionCLI {

    /// The binary name for notion-cli (renamed from `notion` to `ntn` in v0.5.21).
    private static let binaryName = "ntn"

    // MARK: - Environment

    static var databaseId: String {
        get throws {
            guard let id = ProcessInfo.processInfo.environment["NOTION_TASKS_DB_ID"], !id.isEmpty else {
                throw NTaskError.misconfigured("NOTION_TASKS_DB_ID environment variable is not set")
            }
            return id
        }
    }

    private static var notionEnv: [String: String] {
        ["NOTION_OUTPUT": "json"]
    }

    // MARK: - Doctor

    /// Check if notion-cli has a valid auth session (keychain or config).
    /// Runs `notion auth status -o json` and parses the result.
    /// Returns the token source string (e.g. "system keyring") or nil.
    static func checkAuthStatus() async -> String? {
        do {
            let result = try await ProcessRunner.run(
                executable: binaryName,
                arguments: ["auth", "status", "-o", "json"],
                environment: notionEnv
            )
            guard result.exitCode == 0,
                  let data = result.stdout.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["authenticated"] as? Bool == true else {
                return nil
            }
            return json["token_source"] as? String ?? "unknown"
        } catch {
            return nil
        }
    }

    static func checkVersion() async throws -> String {
        let found = await ProcessRunner.findExecutable(binaryName)
        guard found else {
            throw NTaskError.cliMissing("ntn binary not found in PATH")
        }

        let result = try await ProcessRunner.run(
            executable: binaryName,
            arguments: ["--version"],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.cliMissing("ntn --version failed: \(redactStderr(result.stderr))")
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func checkDatabaseAccess() async throws {
        let dbId = try databaseId
        let result = try await ProcessRunner.run(
            executable: binaryName,
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
            "status": ["equals": "Ready"]
        ])
        let result = try await ProcessRunner.run(
            executable: binaryName,
            arguments: ["db", "query", dbId, "--filter", filter, "--all", "--results-only"],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to query ready tasks: \(redactStderr(result.stderr))")
        }
        return parsePages(from: result.stdout)
    }

    /// Resolve a TaskID to its Notion page by querying the database.
    /// Accepts "TASK-42" or "42" format — extracts the number for unique_id filter.
    static func resolveTaskIdToPage(_ taskId: String) async throws -> NotionPage {
        let numberStr = taskId.split(separator: "-").last.flatMap(String.init) ?? taskId
        guard let number = Int(numberStr) else {
            throw NTaskError.misconfigured("Invalid task ID format '\(taskId)'. Expected TASK-42 or 42.")
        }
        let dbId = try databaseId
        let filter = try buildFilterJSON([
            "property": "ID",
            "unique_id": ["equals": number]
        ])
        let result = try await ProcessRunner.run(
            executable: binaryName,
            arguments: ["db", "query", dbId, "--filter", filter, "--results-only"],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to resolve TaskID '\(taskId)': \(redactStderr(result.stderr))")
        }
        let pages = parsePages(from: result.stdout)
        guard let page = pages.first else {
            throw NTaskError.misconfigured("No task found with ID '\(taskId)'")
        }
        return page
    }

    // MARK: - Page operations

    /// Retrieve a page by its Notion page ID.
    static func retrievePage(_ pageId: String) async throws -> NotionPage {
        let result = try await ProcessRunner.run(
            executable: binaryName,
            arguments: ["page", "get", pageId],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to retrieve page '\(pageId)': \(redactStderr(result.stderr))")
        }
        guard let data = result.stdout.data(using: .utf8),
              let page = try? JSONDecoder().decode(NotionPage.self, from: data) else {
            throw NTaskError.apiError("Failed to parse page response")
        }
        return page
    }

    /// Update page properties for claiming a task.
    static func updateForClaim(
        pageId: String,
        runId: String,
        lockToken: String,
        lockedUntil: String
    ) async throws {
        guard let agentUserId = ProcessInfo.processInfo.environment["NOTION_AGENT_USER_ID"],
              !agentUserId.isEmpty else {
            throw NTaskError.misconfigured("NOTION_AGENT_USER_ID environment variable is not set")
        }
        let properties = claimProperties(
            runId: runId,
            lockToken: lockToken,
            lockedUntil: lockedUntil,
            agentUserId: agentUserId
        )
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties for re-claiming a task (In Progress with no lock).
    /// Preserves Status, Assignee, and Started At — only sets lock fields.
    static func updateForReClaim(
        pageId: String,
        runId: String,
        lockToken: String,
        lockedUntil: String
    ) async throws {
        let properties: [String: Any] = [
            "Agent Run": ["rich_text": [["text": ["content": runId]]]],
            "Lock Token": ["rich_text": [["text": ["content": lockToken]]]],
            "Lock Expires": ["date": ["start": lockedUntil]]
        ]
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties for heartbeat (extend lease).
    static func updateForHeartbeat(
        pageId: String,
        lockedUntil: String
    ) async throws {
        let properties: [String: Any] = [
            "Lock Expires": ["date": ["start": lockedUntil]]
        ]
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties to mark task as DONE.
    static func updateForComplete(
        pageId: String,
        doneAt: String
    ) async throws {
        let properties: [String: Any] = [
            "Status": ["status": ["name": "Done"]],
            "Done At": ["date": ["start": doneAt]],
            "Agent Run": ["rich_text": []],
            "Lock Token": ["rich_text": []],
            "Lock Expires": ["date": NSNull()]
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
            "Status": ["status": ["name": "Blocked"]],
            "Blocker Reason": ["rich_text": [["text": ["content": reason]]]],
            "Unblock Action": ["rich_text": [["text": ["content": unblockAction]]]],
            "Agent Run": ["rich_text": []],
            "Lock Token": ["rich_text": []],
            "Lock Expires": ["date": NSNull()]
        ]
        if let nextCheck {
            properties["Next Check At"] = ["date": ["start": nextCheck]]
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
            executable: binaryName,
            arguments: ["page", "create", "--parent", dbId, "--parent-type", "database", "--properties", jsonStr],
            environment: notionEnv
        )
        guard result.exitCode == 0 else {
            throw NTaskError.apiError("Failed to create page: \(redactStderr(result.stderr))")
        }
        guard let data = result.stdout.data(using: .utf8),
              let page = try? JSONDecoder().decode(NotionPage.self, from: data) else {
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
                "status": ["equals": status]
            ])
            arguments += ["--filter", filter]
        }
        if limit > 0 {
            arguments += ["--limit", String(limit)]
        }
        let result = try await ProcessRunner.run(
            executable: binaryName,
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
            executable: binaryName,
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
        pageId: String
    ) async throws {
        let properties: [String: Any] = [
            "Status": ["status": ["name": "Review"]],
            "Agent Run": ["rich_text": []],
            "Lock Token": ["rich_text": []],
            "Lock Expires": ["date": NSNull()]
        ]
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties to approve a reviewed task (Review → Done).
    static func updateForApprove(pageId: String, doneAt: String) async throws {
        let properties: [String: Any] = [
            "Status": ["status": ["name": "Done"]],
            "Done At": ["date": ["start": doneAt]],
            "Agent Run": ["rich_text": []],
            "Lock Token": ["rich_text": []],
            "Lock Expires": ["date": NSNull()]
        ]
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties to send task back for rework (Review → In Progress).
    static func updateForRework(pageId: String) async throws {
        let properties: [String: Any] = [
            "Status": ["status": ["name": "In Progress"]],
            "Agent Run": ["rich_text": []],
            "Lock Token": ["rich_text": []],
            "Lock Expires": ["date": NSNull()]
        ]
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties to mark task as CANCELED.
    static func updateForCancel(
        pageId: String,
        reason: String
    ) async throws {
        let properties: [String: Any] = [
            "Status": ["status": ["name": "Canceled"]],
            "Blocker Reason": ["rich_text": [["text": ["content": reason]]]],
            "Agent Run": ["rich_text": []],
            "Lock Token": ["rich_text": []],
            "Lock Expires": ["date": NSNull()]
        ]
        try await updatePage(pageId: pageId, properties: properties)
    }

    /// Update page properties to unblock a task (Blocked → In Progress).
    /// Preserves Blocker Reason and Unblock Action for audit trail.
    static func updateForUnblock(pageId: String) async throws {
        let properties: [String: Any] = [
            "Status": ["status": ["name": "In Progress"]],
            "Agent Run": ["rich_text": []],
            "Lock Token": ["rich_text": []],
            "Lock Expires": ["date": NSNull()]
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
        lockToken: String,
        lockedUntil: String,
        agentUserId: String
    ) -> [String: Any] {
        [
            "Status": ["status": ["name": "In Progress"]],
            "Assignee": ["people": [["object": "user", "id": agentUserId]]],
            "Agent Run": ["rich_text": [["text": ["content": runId]]]],
            "Lock Token": ["rich_text": [["text": ["content": lockToken]]]],
            "Lock Expires": ["date": ["start": lockedUntil]],
            "Started At": ["date": ["start": Time.iso8601(Time.now())]]
        ]
    }

    private static func updatePage(pageId: String, properties: [String: Any]) async throws {
        guard let data = try? JSONSerialization.data(withJSONObject: properties),
              let jsonStr = String(data: data, encoding: .utf8) else {
            throw NTaskError.apiError("Failed to serialize properties JSON")
        }
        let result = try await ProcessRunner.run(
            executable: binaryName,
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
        guard let data = jsonString.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        // Try direct array of pages
        if let pages = try? decoder.decode([NotionPage].self, from: data) {
            return pages
        }
        // Try wrapped response with "results" key
        if let wrapped = try? decoder.decode(NotionQueryResponse.self, from: data) {
            return wrapped.results
        }
        // Try single page
        if let page = try? decoder.decode(NotionPage.self, from: data) {
            return [page]
        }
        return []
    }
}

private struct NotionQueryResponse: Decodable {
    let results: [NotionPage]
}
