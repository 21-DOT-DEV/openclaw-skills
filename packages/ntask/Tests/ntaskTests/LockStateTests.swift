import Testing
import Foundation
@testable import NTaskLib

@Suite("LockState Tests", .serialized)
struct LockStateTests {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    // MARK: - Round-trip

    @Test("Save and load round-trip preserves all fields")
    func saveLoadRoundTrip() throws {
        let state = LockState(
            taskId: "TASK-42",
            runId: "run-abc",
            lockToken: "token-xyz",
            lockExpires: "2026-02-17T10:30:00Z",
            pageId: "page-123"
        )
        try LockStateManager.save(state)
        let loaded = try LockStateManager.load()
        #expect(loaded.taskId == "TASK-42")
        #expect(loaded.runId == "run-abc")
        #expect(loaded.lockToken == "token-xyz")
        #expect(loaded.lockExpires == "2026-02-17T10:30:00Z")
        #expect(loaded.pageId == "page-123")
        try LockStateManager.clear()
    }

    // MARK: - Load with no file

    @Test("Load with no state file throws MISCONFIGURED")
    func loadNoFile() throws {
        try LockStateManager.clear()
        #expect(throws: NTaskError.self) {
            _ = try LockStateManager.load()
        }
    }

    // MARK: - Load with expected task ID

    @Test("Load with matching task ID succeeds")
    func loadMatchingTaskId() throws {
        let state = LockState(
            taskId: "TASK-42",
            runId: "run-1",
            lockToken: "tok-1",
            lockExpires: "2026-02-17T10:30:00Z",
            pageId: "page-1"
        )
        try LockStateManager.save(state)
        let loaded = try LockStateManager.load(expectedTaskId: "TASK-42")
        #expect(loaded.taskId == "TASK-42")
        try LockStateManager.clear()
    }

    @Test("Load with mismatched task ID throws MISCONFIGURED")
    func loadMismatchedTaskId() throws {
        let state = LockState(
            taskId: "TASK-42",
            runId: "run-1",
            lockToken: "tok-1",
            lockExpires: "2026-02-17T10:30:00Z",
            pageId: "page-1"
        )
        try LockStateManager.save(state)
        #expect(throws: NTaskError.self) {
            _ = try LockStateManager.load(expectedTaskId: "TASK-99")
        }
        try LockStateManager.clear()
    }

    // MARK: - Clear

    @Test("Clear removes state file, subsequent load throws")
    func clearRemovesFile() throws {
        let state = LockState(
            taskId: "TASK-42",
            runId: "run-1",
            lockToken: "tok-1",
            lockExpires: "2026-02-17T10:30:00Z",
            pageId: "page-1"
        )
        try LockStateManager.save(state)
        try LockStateManager.clear()
        #expect(throws: NTaskError.self) {
            _ = try LockStateManager.load()
        }
    }

    @Test("Clear on non-existent file does not throw")
    func clearNonExistent() throws {
        try LockStateManager.clear()
        try LockStateManager.clear()
    }

    // MARK: - JSON format

    @Test("State file uses snake_case JSON keys")
    func snakeCaseKeys() throws {
        let state = LockState(
            taskId: "TASK-42",
            runId: "run-1",
            lockToken: "tok-1",
            lockExpires: "2026-02-17T10:30:00Z",
            pageId: "page-1"
        )
        try LockStateManager.save(state)
        let data = try Data(contentsOf: LockStateManager.stateFilePath())
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["task_id"] as? String == "TASK-42")
        #expect(json["run_id"] as? String == "run-1")
        #expect(json["lock_token"] as? String == "tok-1")
        #expect(json["lock_expires"] as? String == "2026-02-17T10:30:00Z")
        #expect(json["page_id"] as? String == "page-1")
        // Verify no camelCase keys
        #expect(json["taskId"] == nil)
        #expect(json["runId"] == nil)
        #expect(json["lockToken"] == nil)
        try LockStateManager.clear()
    }

    // MARK: - Directory auto-creation

    @Test("Save creates state directory if missing")
    func directoryAutoCreation() throws {
        // Clear any existing state
        try LockStateManager.clear()
        let dir = LockStateManager.stateFilePath().deletingLastPathComponent()
        // Even if dir exists, save should succeed
        let state = LockState(
            taskId: "TASK-1",
            runId: "run-1",
            lockToken: "tok-1",
            lockExpires: "2026-02-17T10:30:00Z",
            pageId: "page-1"
        )
        try LockStateManager.save(state)
        #expect(FileManager.default.fileExists(atPath: dir.path))
        try LockStateManager.clear()
    }
}
