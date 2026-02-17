import Foundation

struct LockState: Codable, Sendable {
    let taskId: String
    let runId: String
    let lockToken: String
    let lockExpires: String
    let pageId: String

    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case runId = "run_id"
        case lockToken = "lock_token"
        case lockExpires = "lock_expires"
        case pageId = "page_id"
    }
}

enum LockStateManager {

    private static let stateDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".openclaw/state")
    }()

    static func stateFilePath() -> URL {
        stateDirectory.appendingPathComponent("current-task.json")
    }

    static func save(_ state: LockState) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: stateDirectory.path) {
            try fm.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: stateFilePath(), options: .atomic)
    }

    static func load() throws -> LockState {
        let path = stateFilePath()
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw NTaskError.misconfigured("No active task claim. Run 'ntask claim' first.")
        }
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(LockState.self, from: data)
    }

    static func load(expectedTaskId: String) throws -> LockState {
        let state = try load()
        guard state.taskId == expectedTaskId else {
            throw NTaskError.misconfigured(
                "Lock state is for \(state.taskId), not \(expectedTaskId)"
            )
        }
        return state
    }

    static func clear() throws {
        let path = stateFilePath()
        let fm = FileManager.default
        if fm.fileExists(atPath: path.path) {
            try fm.removeItem(at: path)
        }
    }
}
