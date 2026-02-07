import Testing
import Foundation
@testable import NTaskLib

@Suite("JSON Output Contract Tests")
struct ContractTests {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    // MARK: - Success Response Contract

    @Test("Success response has ok=true")
    func successResponseOk() throws {
        let response = NTaskSuccessResponse<TaskSummary>(task: nil)
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["ok"] as? Bool == true)
    }

    @Test("Success response round-trips through JSON")
    func successResponseRoundTrip() throws {
        let task = TaskSummary(
            pageId: "abc123",
            taskId: "PROJ-42",
            status: "READY",
            priority: 8,
            classOfService: "STANDARD",
            acceptanceCriteria: "Do the thing",
            claimedBy: nil,
            agentRunId: nil,
            agentName: nil,
            lockToken: nil,
            lockedUntil: nil,
            doneAt: nil,
            blockerReason: nil,
            unblockAction: nil,
            nextCheckAt: nil,
            parentTaskId: nil,
            reason: nil
        )
        let response = NTaskSuccessResponse(task: task)
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(NTaskSuccessResponse<TaskSummary>.self, from: data)
        #expect(decoded.ok == true)
        #expect(decoded.task?.pageId == "abc123")
        #expect(decoded.task?.taskId == "PROJ-42")
        #expect(decoded.task?.status == "READY")
        #expect(decoded.task?.priority == 8)
    }

    // MARK: - Error Response Contract

    @Test("Error response has ok=false")
    func errorResponseOk() throws {
        let response = NTaskErrorResponse(
            error: NTaskErrorPayload(code: "CONFLICT", message: "Already claimed")
        )
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["ok"] as? Bool == false)
    }

    @Test("Error response includes error.code and error.message")
    func errorResponseFields() throws {
        let response = NTaskErrorResponse(
            error: NTaskErrorPayload(code: "API_ERROR", message: "Timeout")
        )
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let errorObj = json["error"] as! [String: Any]
        #expect(errorObj["code"] as? String == "API_ERROR")
        #expect(errorObj["message"] as? String == "Timeout")
    }

    @Test("Error response round-trips through JSON")
    func errorResponseRoundTrip() throws {
        let task = TaskSummary(
            pageId: "abc123",
            taskId: "PROJ-42",
            status: "IN_PROGRESS",
            priority: nil,
            classOfService: nil,
            acceptanceCriteria: nil,
            claimedBy: "AGENT",
            agentRunId: "run-other",
            agentName: nil,
            lockToken: nil,
            lockedUntil: nil,
            doneAt: nil,
            blockerReason: nil,
            unblockAction: nil,
            nextCheckAt: nil,
            parentTaskId: nil,
            reason: nil
        )
        let response = NTaskErrorResponse(
            error: NTaskErrorPayload(code: "CONFLICT", message: "Claimed"),
            task: task
        )
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(NTaskErrorResponse.self, from: data)
        #expect(decoded.ok == false)
        #expect(decoded.error.code == "CONFLICT")
        #expect(decoded.task?.claimedBy == "AGENT")
    }

    // MARK: - TaskSummary Field Names (snake_case contract)

    @Test("TaskSummary encodes with snake_case field names")
    func taskSummarySnakeCase() throws {
        let task = TaskSummary(
            pageId: "p1",
            taskId: "T-1",
            status: "DONE",
            priority: 5,
            classOfService: "EXPEDITE",
            acceptanceCriteria: "AC",
            claimedBy: "AGENT",
            agentRunId: "run-1",
            agentName: "agent-1",
            lockToken: "tok-1",
            lockedUntil: "2025-01-01T00:00:00Z",
            doneAt: "2025-01-02T00:00:00Z",
            blockerReason: nil,
            unblockAction: nil,
            nextCheckAt: nil,
            parentTaskId: "PROJ-00",
            reason: nil
        )
        let data = try encoder.encode(task)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Verify all snake_case keys exist
        #expect(json["page_id"] as? String == "p1")
        #expect(json["task_id"] as? String == "T-1")
        #expect(json["class_of_service"] as? String == "EXPEDITE")
        #expect(json["acceptance_criteria"] as? String == "AC")
        #expect(json["claimed_by"] as? String == "AGENT")
        #expect(json["agent_run_id"] as? String == "run-1")
        #expect(json["agent_name"] as? String == "agent-1")
        #expect(json["lock_token"] as? String == "tok-1")
        #expect(json["locked_until"] as? String == "2025-01-01T00:00:00Z")
        #expect(json["done_at"] as? String == "2025-01-02T00:00:00Z")
        #expect(json["parent_task_id"] as? String == "PROJ-00")

        // Verify NO camelCase keys leak through
        #expect(json["pageId"] == nil)
        #expect(json["taskId"] == nil)
        #expect(json["classOfService"] == nil)
        #expect(json["parentTaskId"] == nil)
    }

    // MARK: - Doctor Checks Contract

    @Test("DoctorChecks encodes with correct field names")
    func doctorChecksFieldNames() throws {
        let checks = DoctorChecks(
            notionCli: NotionCliCheck(found: true, version: "0.6.0"),
            envNotionToken: true,
            envNotionTasksDbId: true,
            dbAccessible: true
        )
        let data = try encoder.encode(checks)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["notion_cli"] != nil)
        #expect(json["env_NOTION_TOKEN"] as? Bool == true)
        #expect(json["env_NOTION_TASKS_DB_ID"] as? Bool == true)
        #expect(json["db_accessible"] as? Bool == true)
    }

    @Test("DoctorChecks round-trips through JSON")
    func doctorChecksRoundTrip() throws {
        let checks = DoctorChecks(
            notionCli: NotionCliCheck(found: false, version: nil),
            envNotionToken: false,
            envNotionTasksDbId: true,
            dbAccessible: nil
        )
        let data = try encoder.encode(checks)
        let decoded = try decoder.decode(DoctorChecks.self, from: data)
        #expect(decoded.notionCli?.found == false)
        #expect(decoded.notionCli?.version == nil)
        #expect(decoded.envNotionToken == false)
        #expect(decoded.envNotionTasksDbId == true)
        #expect(decoded.dbAccessible == nil)
    }

    // MARK: - Version Info Contract

    @Test("VersionInfo has ok=true and version string")
    func versionInfoContract() throws {
        let info = VersionInfo(version: NTaskVersion.current)
        let data = try encoder.encode(info)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["ok"] as? Bool == true)
        #expect(json["version"] as? String == NTaskVersion.current)
    }

    @Test("VersionInfo round-trips through JSON")
    func versionInfoRoundTrip() throws {
        let info = VersionInfo(version: "1.2.3")
        let data = try encoder.encode(info)
        let decoded = try decoder.decode(VersionInfo.self, from: data)
        #expect(decoded.ok == true)
        #expect(decoded.version == "1.2.3")
    }

    // MARK: - Null task in success (next with no tasks)

    @Test("Success response with null task encodes correctly")
    func successNullTask() throws {
        let response = NTaskSuccessResponse<TaskSummary>(task: nil, message: "No ready tasks found")
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["ok"] as? Bool == true)
        #expect(json["message"] as? String == "No ready tasks found")
    }

    // MARK: - List Response Contract

    @Test("ListTasksResponse has ok=true, tasks array, and count")
    func listResponseContract() throws {
        let tasks = [
            TaskSummary(
                pageId: "p1", taskId: "T-1", status: "READY", priority: 5,
                classOfService: "STANDARD", acceptanceCriteria: nil,
                claimedBy: nil, agentRunId: nil, agentName: nil,
                lockToken: nil, lockedUntil: nil, doneAt: nil,
                blockerReason: nil, unblockAction: nil, nextCheckAt: nil,
                parentTaskId: nil, reason: nil
            ),
            TaskSummary(
                pageId: "p2", taskId: "T-2", status: "IN_PROGRESS", priority: 8,
                classOfService: "EXPEDITE", acceptanceCriteria: nil,
                claimedBy: "AGENT", agentRunId: "run-1", agentName: nil,
                lockToken: nil, lockedUntil: nil, doneAt: nil,
                blockerReason: nil, unblockAction: nil, nextCheckAt: nil,
                parentTaskId: nil, reason: nil
            )
        ]
        let response = ListTasksResponse(tasks: tasks)
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["ok"] as? Bool == true)
        #expect(json["count"] as? Int == 2)
        #expect((json["tasks"] as? [[String: Any]])?.count == 2)
    }

    @Test("ListTasksResponse round-trips through JSON")
    func listResponseRoundTrip() throws {
        let response = ListTasksResponse(tasks: [])
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(ListTasksResponse.self, from: data)
        #expect(decoded.ok == true)
        #expect(decoded.count == 0)
        #expect(decoded.tasks.isEmpty)
    }

    // MARK: - Comment Response Contract

    @Test("CommentResponse has ok=true, task_id, and comment")
    func commentResponseContract() throws {
        let response = CommentResponse(taskId: "PROJ-42", comment: "Started work")
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["ok"] as? Bool == true)
        #expect(json["task_id"] as? String == "PROJ-42")
        #expect(json["comment"] as? String == "Started work")
    }

    @Test("CommentResponse round-trips through JSON")
    func commentResponseRoundTrip() throws {
        let response = CommentResponse(taskId: "T-99", comment: "Test comment")
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(CommentResponse.self, from: data)
        #expect(decoded.ok == true)
        #expect(decoded.taskId == "T-99")
        #expect(decoded.comment == "Test comment")
    }

    // MARK: - TaskSummary with new fields

    // MARK: - Redaction

    @Test("redact replaces NOTION_TOKEN value with [REDACTED]")
    func redactReplacesToken() {
        let original = ProcessInfo.processInfo.environment["NOTION_TOKEN"]
        setenv("NOTION_TOKEN", "secret_ntn_abc123", 1)
        let result = NotionCLI.redact("Error: auth failed with token secret_ntn_abc123 on request")
        #expect(result == "Error: auth failed with token [REDACTED] on request")
        if let original { setenv("NOTION_TOKEN", original, 1) } else { unsetenv("NOTION_TOKEN") }
    }

    @Test("redact passes through when NOTION_TOKEN is not set")
    func redactPassthroughNoToken() {
        let original = ProcessInfo.processInfo.environment["NOTION_TOKEN"]
        unsetenv("NOTION_TOKEN")
        let input = "Some error message"
        #expect(NotionCLI.redact(input) == input)
        if let original { setenv("NOTION_TOKEN", original, 1) }
    }

    @Test("redact passes through when token not in string")
    func redactPassthroughTokenAbsent() {
        let original = ProcessInfo.processInfo.environment["NOTION_TOKEN"]
        setenv("NOTION_TOKEN", "secret_ntn_xyz789", 1)
        let input = "Connection timed out"
        #expect(NotionCLI.redact(input) == input)
        if let original { setenv("NOTION_TOKEN", original, 1) } else { unsetenv("NOTION_TOKEN") }
    }

    @Test("TaskSummary encodes parent_task_id and reason")
    func taskSummaryNewFields() throws {
        let task = TaskSummary(
            pageId: "p1", taskId: "T-1a", status: "CANCELED", priority: nil,
            classOfService: nil, acceptanceCriteria: nil,
            claimedBy: nil, agentRunId: nil, agentName: nil,
            lockToken: nil, lockedUntil: nil, doneAt: nil,
            blockerReason: nil, unblockAction: nil, nextCheckAt: nil,
            parentTaskId: "T-1", reason: "No longer needed"
        )
        let data = try encoder.encode(task)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["parent_task_id"] as? String == "T-1")
        #expect(json["reason"] as? String == "No longer needed")
    }
}
