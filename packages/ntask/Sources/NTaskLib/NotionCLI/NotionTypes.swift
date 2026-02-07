import Foundation

struct NotionPage {
    let pageId: String
    let properties: [String: Any]

    var taskId: String? {
        stringProperty("TaskID")
    }

    var status: String? {
        selectProperty("Status")
    }

    var priority: Int? {
        numberProperty("Priority")
    }

    var classOfService: String? {
        selectProperty("ClassOfService")
    }

    var acceptanceCriteria: String? {
        richTextProperty("AcceptanceCriteria")
    }

    var dependenciesOpenCount: Int? {
        numberProperty("DependenciesOpenCount")
    }

    var claimedBy: String? {
        selectProperty("ClaimedBy")
    }

    var agentRunId: String? {
        stringProperty("AgentRunID")
    }

    var agentName: String? {
        stringProperty("AgentName")
    }

    var lockToken: String? {
        stringProperty("LockToken")
    }

    var lockedUntil: String? {
        dateProperty("LockedUntil")
    }

    var blockerReason: String? {
        stringProperty("BlockerReason")
    }

    var unblockAction: String? {
        stringProperty("UnblockAction")
    }

    var lastEditedTime: String? {
        properties["last_edited_time"] as? String
    }

    func toSummary() -> [String: Any] {
        var dict: [String: Any] = ["page_id": pageId]
        if let v = taskId { dict["task_id"] = v }
        if let v = status { dict["status"] = v }
        if let v = priority { dict["priority"] = v }
        if let v = classOfService { dict["class_of_service"] = v }
        if let v = acceptanceCriteria { dict["acceptance_criteria"] = v }
        if let v = claimedBy { dict["claimed_by"] = v }
        if let v = agentRunId { dict["agent_run_id"] = v }
        if let v = agentName { dict["agent_name"] = v }
        if let v = lockToken { dict["lock_token"] = v }
        if let v = lockedUntil { dict["locked_until"] = v }
        return dict
    }

    // MARK: - Property extraction helpers

    private func stringProperty(_ name: String) -> String? {
        guard let prop = properties[name] as? [String: Any] else { return nil }
        if let titleArr = prop["title"] as? [[String: Any]] {
            return titleArr.compactMap { $0["plain_text"] as? String }.joined()
        }
        if let rtArr = prop["rich_text"] as? [[String: Any]] {
            return rtArr.compactMap { $0["plain_text"] as? String }.joined()
        }
        return nil
    }

    private func selectProperty(_ name: String) -> String? {
        guard let prop = properties[name] as? [String: Any],
              let select = prop["select"] as? [String: Any],
              let value = select["name"] as? String else { return nil }
        return value
    }

    private func numberProperty(_ name: String) -> Int? {
        guard let prop = properties[name] as? [String: Any] else { return nil }
        if let num = prop["number"] as? Int { return num }
        if let num = prop["number"] as? Double { return Int(num) }
        if let rollup = prop["rollup"] as? [String: Any],
           let num = rollup["number"] as? Int { return num }
        if let rollup = prop["rollup"] as? [String: Any],
           let num = rollup["number"] as? Double { return Int(num) }
        return nil
    }

    private func richTextProperty(_ name: String) -> String? {
        guard let prop = properties[name] as? [String: Any],
              let rtArr = prop["rich_text"] as? [[String: Any]] else { return nil }
        let text = rtArr.compactMap { $0["plain_text"] as? String }.joined()
        return text.isEmpty ? nil : text
    }

    private func dateProperty(_ name: String) -> String? {
        guard let prop = properties[name] as? [String: Any],
              let dateObj = prop["date"] as? [String: Any],
              let start = dateObj["start"] as? String else { return nil }
        return start
    }

    static func from(json: [String: Any]) -> NotionPage? {
        guard let id = json["id"] as? String else { return nil }
        let props = json["properties"] as? [String: Any] ?? [:]
        var merged = props
        if let let_ = json["last_edited_time"] as? String {
            merged["last_edited_time"] = let_
        }
        return NotionPage(pageId: id, properties: merged)
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
