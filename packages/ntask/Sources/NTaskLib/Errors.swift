import Foundation

enum NTaskError: Error {
    case conflict(String)
    case misconfigured(String)
    case cliMissing(String)
    case lostLock(String)
    case apiError(String)
    case noTasks(String)
    case incompleteSubtasks(String)

    var code: String {
        switch self {
        case .conflict: "CONFLICT"
        case .misconfigured: "MISCONFIGURED"
        case .cliMissing: "CLI_MISSING"
        case .lostLock: "LOST_LOCK"
        case .apiError: "API_ERROR"
        case .noTasks: "NO_TASKS"
        case .incompleteSubtasks: "INCOMPLETE_SUBTASKS"
        }
    }

    var exitCode: Int32 {
        switch self {
        case .noTasks: ExitCodes.noTasks
        case .conflict: ExitCodes.conflict
        case .lostLock: ExitCodes.lostLock
        case .apiError: ExitCodes.apiError
        case .misconfigured, .cliMissing: ExitCodes.misconfigured
        case .incompleteSubtasks: ExitCodes.incompleteSubtasks
        }
    }

    var message: String {
        switch self {
        case .conflict(let m), .misconfigured(let m),
             .cliMissing(let m), .lostLock(let m), .apiError(let m),
             .noTasks(let m), .incompleteSubtasks(let m):
            m
        }
    }
}

struct ExitCodes {
    static let success: Int32 = 0
    static let noTasks: Int32 = 10
    static let conflict: Int32 = 20
    static let lostLock: Int32 = 21
    static let apiError: Int32 = 30
    static let misconfigured: Int32 = 40
    static let incompleteSubtasks: Int32 = 41
}
