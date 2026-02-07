import Foundation

// MARK: - Response Envelope

struct NTaskSuccessResponse<T: Codable>: Codable {
    let ok: Bool
    let task: T?
    let message: String?
    let checks: DoctorChecks?
    let version: String?

    init(task: T? = nil, message: String? = nil, checks: DoctorChecks? = nil, version: String? = nil) {
        self.ok = true
        self.task = task
        self.message = message
        self.checks = checks
        self.version = version
    }
}

struct NTaskErrorResponse: Codable {
    let ok: Bool
    let error: NTaskErrorPayload
    let task: TaskSummary?

    init(error: NTaskErrorPayload, task: TaskSummary? = nil) {
        self.ok = false
        self.error = error
        self.task = task
    }
}

// MARK: - Error Payload

struct NTaskErrorPayload: Codable {
    let code: String
    let message: String
}

// MARK: - Task Summary

struct TaskSummary: Codable, Equatable {
    let pageId: String
    let taskId: String?
    let status: String?
    let priority: Int?
    let classOfService: String?
    let acceptanceCriteria: String?
    let claimedBy: String?
    let agentRunId: String?
    let agentName: String?
    let lockToken: String?
    let lockedUntil: String?
    let doneAt: String?
    let blockerReason: String?
    let unblockAction: String?
    let nextCheckAt: String?
    let parentTaskId: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case pageId = "page_id"
        case taskId = "task_id"
        case status
        case priority
        case classOfService = "class_of_service"
        case acceptanceCriteria = "acceptance_criteria"
        case claimedBy = "claimed_by"
        case agentRunId = "agent_run_id"
        case agentName = "agent_name"
        case lockToken = "lock_token"
        case lockedUntil = "locked_until"
        case doneAt = "done_at"
        case blockerReason = "blocker_reason"
        case unblockAction = "unblock_action"
        case nextCheckAt = "next_check_at"
        case parentTaskId = "parent_task_id"
        case reason
    }
}

// MARK: - Doctor Checks

struct DoctorChecks: Codable {
    let notionCli: NotionCliCheck?
    let envNotionToken: Bool?
    let envNotionTasksDbId: Bool?
    let dbAccessible: Bool?

    enum CodingKeys: String, CodingKey {
        case notionCli = "notion_cli"
        case envNotionToken = "env_NOTION_TOKEN"
        case envNotionTasksDbId = "env_NOTION_TASKS_DB_ID"
        case dbAccessible = "db_accessible"
    }
}

struct NotionCliCheck: Codable {
    let found: Bool
    let version: String?
}

// MARK: - List Response

struct ListTasksResponse: Codable {
    let ok: Bool
    let tasks: [TaskSummary]
    let count: Int

    init(tasks: [TaskSummary]) {
        self.ok = true
        self.tasks = tasks
        self.count = tasks.count
    }
}

// MARK: - Comment Response

struct CommentResponse: Codable {
    let ok: Bool
    let taskId: String
    let comment: String

    enum CodingKeys: String, CodingKey {
        case ok
        case taskId = "task_id"
        case comment
    }

    init(taskId: String, comment: String) {
        self.ok = true
        self.taskId = taskId
        self.comment = comment
    }
}

// MARK: - Version Info

struct VersionInfo: Codable {
    let ok: Bool
    let version: String

    init(version: String) {
        self.ok = true
        self.version = version
    }
}
