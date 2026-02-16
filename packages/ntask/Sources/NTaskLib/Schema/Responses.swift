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
    let taskClass: String?
    let agentRun: String?
    let lockToken: String?
    let lockExpires: String?
    let startedAt: String?
    let doneAt: String?
    let blockerReason: String?
    let unblockAction: String?
    let nextCheckAt: String?
    let completedSubtasks: Int?
    let parentTaskId: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case pageId = "page_id"
        case taskId = "task_id"
        case status
        case priority
        case taskClass = "class"
        case agentRun = "agent_run"
        case lockToken = "lock_token"
        case lockExpires = "lock_expires"
        case startedAt = "started_at"
        case doneAt = "done_at"
        case blockerReason = "blocker_reason"
        case unblockAction = "unblock_action"
        case nextCheckAt = "next_check_at"
        case completedSubtasks = "completed_subtasks"
        case parentTaskId = "parent_task_id"
        case reason
    }

    init(
        pageId: String,
        taskId: String? = nil,
        status: String? = nil,
        priority: Int? = nil,
        taskClass: String? = nil,
        agentRun: String? = nil,
        lockToken: String? = nil,
        lockExpires: String? = nil,
        startedAt: String? = nil,
        doneAt: String? = nil,
        blockerReason: String? = nil,
        unblockAction: String? = nil,
        nextCheckAt: String? = nil,
        completedSubtasks: Int? = nil,
        parentTaskId: String? = nil,
        reason: String? = nil
    ) {
        self.pageId = pageId
        self.taskId = taskId
        self.status = status
        self.priority = priority
        self.taskClass = taskClass
        self.agentRun = agentRun
        self.lockToken = lockToken
        self.lockExpires = lockExpires
        self.startedAt = startedAt
        self.doneAt = doneAt
        self.blockerReason = blockerReason
        self.unblockAction = unblockAction
        self.nextCheckAt = nextCheckAt
        self.completedSubtasks = completedSubtasks
        self.parentTaskId = parentTaskId
        self.reason = reason
    }
}

// MARK: - Doctor Checks

struct NotionTokenCheck: Codable, Equatable {
    let available: Bool
    let source: String?
}

struct DoctorChecks: Codable {
    let notionCli: NotionCliCheck?
    let notionToken: NotionTokenCheck?
    let envNotionTasksDbId: Bool?
    let envNotionAgentUserId: Bool?
    let dbAccessible: Bool?

    enum CodingKeys: String, CodingKey {
        case notionCli = "notion_cli"
        case notionToken = "notion_token"
        case envNotionTasksDbId = "env_NOTION_TASKS_DB_ID"
        case envNotionAgentUserId = "env_NOTION_AGENT_USER_ID"
        case dbAccessible = "db_accessible"
    }
}

struct DoctorErrorResponse: Codable {
    let ok: Bool
    let error: NTaskErrorPayload
    let checks: DoctorChecks

    init(error: NTaskErrorPayload, checks: DoctorChecks) {
        self.ok = false
        self.error = error
        self.checks = checks
    }
}

struct NotionCliCheck: Codable, Equatable {
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
