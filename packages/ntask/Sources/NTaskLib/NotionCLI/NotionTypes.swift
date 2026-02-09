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
    case number(Double?)
    case uniqueId(NotionUniqueId)
    case date(NotionDate?)
    case rollup(NotionRollup)
    case unknown

    private enum CodingKeys: String, CodingKey {
        case type, title
        case richText = "rich_text"
        case select, number
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
        guard case .select(let sel) = properties["Status"] else { return nil }
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

    var dependenciesOpenCount: Int? {
        guard case .rollup(let rollup) = properties["Dependencies"] else { return nil }
        return rollup.number.flatMap { Int($0) }
    }

    var claimedBy: String? {
        guard case .select(let sel) = properties["Claimed By"] else { return nil }
        return sel?.name
    }

    var agentRunId: String? {
        switch properties["Agent Run"] {
        case .richText(let text): return text.isEmpty ? nil : text
        case .title(let text): return text.isEmpty ? nil : text
        default: return nil
        }
    }

    var agent: String? {
        guard case .select(let sel) = properties["Agent"] else { return nil }
        return sel?.name
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
        switch properties["BlockerReason"] {
        case .richText(let text): return text.isEmpty ? nil : text
        case .title(let text): return text.isEmpty ? nil : text
        default: return nil
        }
    }

    var unblockAction: String? {
        switch properties["UnblockAction"] {
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
        if let v = claimedBy { dict["claimed_by"] = v }
        if let v = agentRunId { dict["agent_run"] = v }
        if let v = agent { dict["agent"] = v }
        if let v = lockToken { dict["lock_token"] = v }
        if let v = lockExpires { dict["lock_expires"] = v }
        return dict
    }
}

enum ClassOfServiceRank {
    static func rank(for value: String?) -> Int {
        switch value?.uppercased() {
        case "EXPEDITE": return 1
        case "FIXED_DATE": return 2
        case "STANDARD": return 3
        case "INTANGIBLE": return 4
        default: return 3 // Default to STANDARD
        }
    }
}
