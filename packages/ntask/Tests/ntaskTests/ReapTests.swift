import Testing
import Foundation
@testable import NTaskLib

@Suite("Reap Tests")
struct ReapTests {

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    // MARK: - Helpers

    private func makePage(
        pageId: String = "page-1",
        status: String = "In Progress",
        lockToken: String? = nil,
        lockExpires: String? = nil
    ) -> NotionPage {
        var props: [String: NotionPropertyValue] = [
            "ID": .uniqueId(NotionUniqueId(prefix: "TASK", number: 1)),
            "Status": .status(NotionSelect(name: status)),
            "Priority": .number(2.0)
        ]
        if let lockToken {
            props["Lock Token"] = .richText(lockToken)
        }
        if let lockExpires {
            props["Lock Expires"] = .date(NotionDate(start: lockExpires))
        }
        return NotionPage(pageId: pageId, properties: props, lastEditedTime: nil)
    }

    // MARK: - Time.isExpired Tests

    @Test("Time.isExpired returns true for past timestamp")
    func isExpiredPastTimestamp() {
        #expect(Time.isExpired("2020-01-01T00:00:00Z") == true)
    }

    @Test("Time.isExpired returns false for future timestamp")
    func isExpiredFutureTimestamp() {
        let future = Time.iso8601(Time.leaseExpiry(minutes: 30))
        #expect(Time.isExpired(future) == false)
    }

    @Test("Time.isExpired returns true for unparseable string")
    func isExpiredUnparseableString() {
        #expect(Time.isExpired("not-a-date") == true)
    }

    // MARK: - Orphan Detection Tests

    @Test("Page with In Progress, non-nil lockToken, and expired lockExpires is an orphan")
    func orphanDetection() {
        let page = makePage(
            status: "In Progress",
            lockToken: "tok-123",
            lockExpires: "2020-01-01T00:00:00Z"
        )
        let isOrphan = page.lockToken != nil
            && page.lockExpires != nil
            && Time.isExpired(page.lockExpires!)
        #expect(isOrphan == true)
    }

    @Test("Page with In Progress but no lockToken is NOT an orphan")
    func notOrphanNoLockToken() {
        let page = makePage(
            status: "In Progress",
            lockToken: nil,
            lockExpires: "2020-01-01T00:00:00Z"
        )
        let isOrphan = page.lockToken != nil
            && page.lockExpires != nil
            && Time.isExpired(page.lockExpires!)
        #expect(isOrphan == false)
    }

    @Test("Page with In Progress and future lockExpires is NOT an orphan")
    func notOrphanFutureLock() {
        let future = Time.iso8601(Time.leaseExpiry(minutes: 30))
        let page = makePage(
            status: "In Progress",
            lockToken: "tok-123",
            lockExpires: future
        )
        let isOrphan = page.lockToken != nil
            && page.lockExpires != nil
            && Time.isExpired(page.lockExpires!)
        #expect(isOrphan == false)
    }

    @Test("Page with In Progress, lockToken, but no lockExpires is NOT an orphan")
    func notOrphanNoLockExpires() {
        let page = makePage(
            status: "In Progress",
            lockToken: "tok-123",
            lockExpires: nil
        )
        let isOrphan = page.lockToken != nil
            && page.lockExpires != nil
        #expect(isOrphan == false)
    }

    // MARK: - ReapResponse Contract Tests

    @Test("ReapResponse has ok=true, reaped array, and count")
    func reapResponseContract() throws {
        let response = ReapResponse(reaped: [
            ReapedTask(taskId: "TASK-1", lockExpiredAt: "2020-01-01T00:00:00Z"),
            ReapedTask(taskId: "TASK-2", lockExpiredAt: "2020-01-02T00:00:00Z")
        ])
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["ok"] as? Bool == true)
        #expect(json["count"] as? Int == 2)
        let reaped = json["reaped"] as! [[String: Any]]
        #expect(reaped.count == 2)
        #expect(reaped[0]["task_id"] as? String == "TASK-1")
        #expect(reaped[0]["lock_expired_at"] as? String == "2020-01-01T00:00:00Z")
        #expect(reaped[1]["task_id"] as? String == "TASK-2")
    }

    @Test("ReapResponse with empty reaped array")
    func reapResponseEmpty() throws {
        let response = ReapResponse(reaped: [])
        let data = try encoder.encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["ok"] as? Bool == true)
        #expect(json["count"] as? Int == 0)
        #expect((json["reaped"] as? [[String: Any]])?.isEmpty == true)
    }

    @Test("ReapResponse round-trips through JSON")
    func reapResponseRoundTrip() throws {
        let response = ReapResponse(reaped: [
            ReapedTask(taskId: "TASK-42", lockExpiredAt: "2020-06-15T12:00:00Z")
        ])
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(ReapResponse.self, from: data)
        #expect(decoded.ok == true)
        #expect(decoded.count == 1)
        #expect(decoded.reaped[0].taskId == "TASK-42")
        #expect(decoded.reaped[0].lockExpiredAt == "2020-06-15T12:00:00Z")
    }

    @Test("ReapedTask uses snake_case JSON keys")
    func reapedTaskSnakeCaseKeys() throws {
        let task = ReapedTask(taskId: "TASK-1", lockExpiredAt: "2020-01-01T00:00:00Z")
        let data = try encoder.encode(task)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["task_id"] as? String == "TASK-1")
        #expect(json["lock_expired_at"] as? String == "2020-01-01T00:00:00Z")
        // No camelCase keys
        #expect(json["taskId"] == nil)
        #expect(json["lockExpiredAt"] == nil)
    }
}
