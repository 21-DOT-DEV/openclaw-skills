import Foundation

enum NTaskError: Error {
    case conflict(String)
    case misconfigured(String)
    case cliMissing(String)
    case lostLock(String)
    case apiError(String)

    var code: String {
        switch self {
        case .conflict: "CONFLICT"
        case .misconfigured: "MISCONFIGURED"
        case .cliMissing: "CLI_MISSING"
        case .lostLock: "LOST_LOCK"
        case .apiError: "API_ERROR"
        }
    }

    var exitCode: Int32 {
        switch self {
        case .conflict: 2
        case .misconfigured, .cliMissing: 3
        case .lostLock: 4
        case .apiError: 5
        }
    }

    var message: String {
        switch self {
        case .conflict(let m), .misconfigured(let m),
             .cliMissing(let m), .lostLock(let m), .apiError(let m):
            m
        }
    }
}

struct ExitCodes {
    static let success: Int32 = 0
    static let conflict: Int32 = 2
    static let misconfigured: Int32 = 3
    static let lostLock: Int32 = 4
    static let apiError: Int32 = 5
}
