import ArgumentParser

// MARK: - Task Status

enum TaskStatus: String, CaseIterable, ExpressibleByArgument {
    case backlog = "Backlog"
    case ready = "Ready"
    case inProgress = "In Progress"
    case blocked = "Blocked"
    case review = "Review"
    case done = "Done"
    case canceled = "Canceled"

    init?(argument: String) {
        let upper = argument.trimmingCharacters(in: .whitespaces)
            .uppercased().replacingOccurrences(of: " ", with: "_")
        switch upper {
        case "BACKLOG": self = .backlog
        case "READY": self = .ready
        case "IN_PROGRESS": self = .inProgress
        case "BLOCKED": self = .blocked
        case "REVIEW": self = .review
        case "DONE": self = .done
        case "CANCELED": self = .canceled
        default: return nil
        }
    }

    static var allValueStrings: [String] {
        allCases.map(\.rawValue)
    }
}

// MARK: - Class of Service

enum ClassOfService: String, CaseIterable, ExpressibleByArgument {
    case expedite = "Expedite"
    case fixedDate = "Fixed Date"
    case standard = "Standard"
    case intangible = "Intangible"

    init?(argument: String) {
        let upper = argument.trimmingCharacters(in: .whitespaces)
            .uppercased().replacingOccurrences(of: " ", with: "_")
        switch upper {
        case "EXPEDITE": self = .expedite
        case "FIXED_DATE", "FIXEDDATE": self = .fixedDate
        case "STANDARD": self = .standard
        case "INTANGIBLE": self = .intangible
        default: return nil
        }
    }

    var rank: Int {
        switch self {
        case .expedite: return 1
        case .fixedDate: return 2
        case .standard: return 3
        case .intangible: return 4
        }
    }

    static var allValueStrings: [String] {
        allCases.map(\.rawValue)
    }
}
