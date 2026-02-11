import Foundation

// MARK: - Notion Property Value Types

struct NotionSelect: Decodable {
    let name: String
}

struct NotionUniqueId: Decodable {
    let prefix: String?
    let number: Int
}

struct NotionDate: Decodable {
    let start: String?
}

struct NotionRollup: Decodable {
    let number: Double?
}

struct RichTextItem: Decodable {
    let plainText: String

    enum CodingKeys: String, CodingKey {
        case plainText = "plain_text"
    }
}

// MARK: - Tagged Union for Notion Property Values

enum NotionPropertyValue: Decodable {
    case title(String)
    case richText(String)
    case select(NotionSelect?)
    case status(NotionSelect?)
    case number(Double?)
    case uniqueId(NotionUniqueId)
    case date(NotionDate?)
    case rollup(NotionRollup)
    case unknown

    private enum CodingKeys: String, CodingKey {
        case type, title
        case richText = "rich_text"
        case select, status, number
        case uniqueId = "unique_id"
        case date, rollup
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "title":
            let items = try container.decodeIfPresent([RichTextItem].self, forKey: .title) ?? []
            self = .title(items.map(\.plainText).joined())
        case "rich_text":
            let items = try container.decodeIfPresent([RichTextItem].self, forKey: .richText) ?? []
            self = .richText(items.map(\.plainText).joined())
        case "select":
            self = .select(try container.decodeIfPresent(NotionSelect.self, forKey: .select))
        case "status":
            self = .status(try container.decodeIfPresent(NotionSelect.self, forKey: .status))
        case "number":
            self = .number(try container.decodeIfPresent(Double.self, forKey: .number))
        case "unique_id":
            self = .uniqueId(try container.decode(NotionUniqueId.self, forKey: .uniqueId))
        case "date":
            self = .date(try container.decodeIfPresent(NotionDate.self, forKey: .date))
        case "rollup":
            self = .rollup(try container.decode(NotionRollup.self, forKey: .rollup))
        default:
            self = .unknown
        }
    }
}

// MARK: - Notion Page

struct NotionPage: Decodable {
    let pageId: String
    let properties: [String: NotionPropertyValue]
    let lastEditedTime: String?

    enum CodingKeys: String, CodingKey {
        case pageId = "id"
        case properties
        case lastEditedTime = "last_edited_time"
    }

    // MARK: - Typed property accessors

    var taskId: String? {
        guard case .uniqueId(let uid) = properties["ID"] else { return nil }
        let prefix = uid.prefix ?? ""
        return prefix.isEmpty ? "\(uid.number)" : "\(prefix)-\(uid.number)"
    }

    var status: String? {
        guard case .status(let sel) = properties["Status"] else { return nil }
        return sel?.name
    }

    var priority: Int? {
        guard case .number(let num) = properties["Priority"] else { return nil }
        return num.flatMap { Int($0) }
    }

    var classOfService: String? {
        guard case .select(let sel) = properties["Class"] else { return nil }
        return sel?.name
    }

    /// Total number of sub-tasks (Dependencies rollup counts all relations)
    var dependencies: Int? {
        guard case .rollup(let rollup) = properties["Dependencies"] else { return nil }
        return rollup.number.flatMap { Int($0) }
    }

    /// Number of sub-tasks in Complete group (Done + Canceled)
    var completedSubtasks: Int? {
        guard case .rollup(let rollup) = properties["Completed Sub-tasks"] else { return nil }
        return rollup.number.flatMap { Int($0) }
    }

    var agentRunId: String? {
        switch properties["Agent Run"] {
        case .richText(let text): return text.isEmpty ? nil : text
        case .title(let text): return text.isEmpty ? nil : text
        default: return nil
        }
    }

    var lockToken: String? {
        switch properties["Lock Token"] {
        case .richText(let text): return text.isEmpty ? nil : text
        case .title(let text): return text.isEmpty ? nil : text
        default: return nil
        }
    }

    var lockExpires: String? {
        guard case .date(let d) = properties["Lock Expires"] else { return nil }
        return d?.start
    }

    var blockerReason: String? {
        switch properties["Blocker Reason"] {
        case .richText(let text): return text.isEmpty ? nil : text
        case .title(let text): return text.isEmpty ? nil : text
        default: return nil
        }
    }

    var startedAt: String? {
        guard case .date(let d) = properties["Started At"] else { return nil }
        return d?.start
    }

    var doneAt: String? {
        guard case .date(let d) = properties["Done At"] else { return nil }
        return d?.start
    }

    var unblockAction: String? {
        switch properties["Unblock Action"] {
        case .richText(let text): return text.isEmpty ? nil : text
        case .title(let text): return text.isEmpty ? nil : text
        default: return nil
        }
    }

    func toSummary() -> [String: Any] {
        var dict: [String: Any] = ["page_id": pageId]
        if let v = taskId { dict["task_id"] = v }
        if let v = status { dict["status"] = v }
        if let v = priority { dict["priority"] = v }
        if let v = classOfService { dict["class"] = v }
        if let v = agentRunId { dict["agent_run"] = v }
        if let v = lockToken { dict["lock_token"] = v }
        if let v = lockExpires { dict["lock_expires"] = v }
        if let v = blockerReason { dict["blocker_reason"] = v }
        if let v = unblockAction { dict["unblock_action"] = v }
        if let v = startedAt { dict["started_at"] = v }
        if let v = doneAt { dict["done_at"] = v }
        if let v = completedSubtasks { dict["completed_subtasks"] = v }
        return dict
    }
}

