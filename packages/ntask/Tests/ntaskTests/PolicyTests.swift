import Testing
@testable import NTaskLib

@Suite("Pull Policy Sort Tests")
struct PullPolicySortTests {

    // MARK: - Helpers

    private func makePage(
        pageId: String = "page-1",
        taskId: String = "TASK-1",
        status: String = "READY",
        priority: Int = 5,
        classOfService: String = "STANDARD",
        claimedBy: String? = nil,
        lockToken: String? = nil,
        lockExpires: String? = nil,
        lastEditedTime: String = "2025-01-01T00:00:00Z"
    ) -> NotionPage {
        var props: [String: NotionPropertyValue] = [
            "ID": .uniqueId(NotionUniqueId(prefix: "TASK", number: 1)),
            "Status": .select(NotionSelect(name: status)),
            "Priority": .number(Double(priority)),
            "Class": .select(NotionSelect(name: classOfService))
        ]
        if let claimedBy {
            props["Claimed By"] = .select(NotionSelect(name: claimedBy))
        }
        if let lockToken {
            props["Lock Token"] = .richText(lockToken)
        }
        if let lockExpires {
            props["Lock Expires"] = .date(NotionDate(start: lockExpires))
        }
        return NotionPage(pageId: pageId, properties: props, lastEditedTime: lastEditedTime)
    }

    // MARK: - ClassOfService Rank Tests

    @Test("EXPEDITE ranks highest (1)")
    func expediteRank() {
        #expect(ClassOfServiceRank.rank(for: "EXPEDITE") == 1)
    }

    @Test("FIXED_DATE ranks second (2)")
    func fixedDateRank() {
        #expect(ClassOfServiceRank.rank(for: "FIXED_DATE") == 2)
    }

    @Test("STANDARD ranks third (3)")
    func standardRank() {
        #expect(ClassOfServiceRank.rank(for: "STANDARD") == 3)
    }

    @Test("INTANGIBLE ranks lowest (4)")
    func intangibleRank() {
        #expect(ClassOfServiceRank.rank(for: "INTANGIBLE") == 4)
    }

    @Test("nil defaults to STANDARD rank (3)")
    func nilDefaultsToStandard() {
        #expect(ClassOfServiceRank.rank(for: nil) == 3)
    }

    // MARK: - Sort Order Tests

    @Test("Sort by ClassOfService: EXPEDITE before STANDARD")
    func sortByClassOfService() {
        let expedite = makePage(pageId: "p1", classOfService: "EXPEDITE")
        let standard = makePage(pageId: "p2", classOfService: "STANDARD")
        let sorted = PullPolicy.sort([standard, expedite])
        #expect(sorted[0].pageId == "p1")
        #expect(sorted[1].pageId == "p2")
    }

    @Test("Sort by Priority descending within same ClassOfService")
    func sortByPriority() {
        let low = makePage(pageId: "p-low", priority: 3)
        let high = makePage(pageId: "p-high", priority: 8)
        let sorted = PullPolicy.sort([low, high])
        #expect(sorted[0].pageId == "p-high")
        #expect(sorted[1].pageId == "p-low")
    }

    @Test("Sort by last edited ascending as tiebreaker")
    func sortByLastEdited() {
        let older = makePage(pageId: "p-old", lastEditedTime: "2025-01-01T00:00:00Z")
        let newer = makePage(pageId: "p-new", lastEditedTime: "2025-01-02T00:00:00Z")
        let sorted = PullPolicy.sort([newer, older])
        #expect(sorted[0].pageId == "p-old")
        #expect(sorted[1].pageId == "p-new")
    }

    @Test("Full deterministic sort: ClassOfService > Priority > LastEdited")
    func fullDeterministicSort() {
        let a = makePage(pageId: "a", priority: 5, classOfService: "EXPEDITE",
                         lastEditedTime: "2025-01-03T00:00:00Z")
        let b = makePage(pageId: "b", priority: 10, classOfService: "STANDARD",
                         lastEditedTime: "2025-01-01T00:00:00Z")
        let c = makePage(pageId: "c", priority: 5, classOfService: "EXPEDITE",
                         lastEditedTime: "2025-01-01T00:00:00Z")
        let sorted = PullPolicy.sort([b, a, c])
        // EXPEDITE tasks first, then by priority desc, then by last edited asc
        #expect(sorted[0].pageId == "c") // EXPEDITE, prio 5, older
        #expect(sorted[1].pageId == "a") // EXPEDITE, prio 5, newer
        #expect(sorted[2].pageId == "b") // STANDARD, prio 10
    }

    // MARK: - Eligibility Tests

    @Test("Eligible: READY, no claim, lock empty")
    func eligibleTask() {
        let page = makePage()
        #expect(PullPolicy.isEligible(page) == true)
    }

    @Test("Not eligible: wrong status")
    func notEligibleWrongStatus() {
        let page = makePage(status: "IN_PROGRESS")
        #expect(PullPolicy.isEligible(page) == false)
    }

    @Test("Not eligible: claimed by HUMAN")
    func notEligibleHumanClaimed() {
        let page = makePage(claimedBy: "HUMAN")
        #expect(PullPolicy.isEligible(page) == false)
    }

    @Test("Not eligible: active lock (not expired)")
    func notEligibleActiveLock() {
        let future = Time.iso8601(Time.leaseExpiry(minutes: 30))
        let page = makePage(claimedBy: "AGENT", lockExpires: future)
        #expect(PullPolicy.isEligible(page) == false)
    }

    @Test("Eligible: expired lock")
    func eligibleExpiredLock() {
        let past = "2020-01-01T00:00:00Z"
        let page = makePage(claimedBy: "AGENT", lockExpires: past)
        #expect(PullPolicy.isEligible(page) == true)
    }
}

@Suite("Lock Verification Tests")
struct LockVerificationTests {

    private func makePage(
        lockToken: String?,
        lockExpires: String? = nil
    ) -> NotionPage {
        var props: [String: NotionPropertyValue] = [:]
        if let lockToken {
            props["Lock Token"] = .richText(lockToken)
        }
        if let lockExpires {
            props["Lock Expires"] = .date(NotionDate(start: lockExpires))
        }
        return NotionPage(pageId: "page-1", properties: props, lastEditedTime: nil)
    }

    @Test("Verify claim: matching token succeeds")
    func verifyClaimSuccess() {
        let page = makePage(lockToken: "token-abc")
        let result = LockVerifier.verifyClaim(page: page, expectedToken: "token-abc")
        #expect(result == .success)
    }

    @Test("Verify claim: mismatched token is conflict")
    func verifyClaimConflict() {
        let page = makePage(lockToken: "token-other")
        let result = LockVerifier.verifyClaim(page: page, expectedToken: "token-abc")
        #expect(result == .conflict)
    }

    @Test("Verify claim: nil token is conflict")
    func verifyClaimNilToken() {
        let page = makePage(lockToken: nil)
        let result = LockVerifier.verifyClaim(page: page, expectedToken: "token-abc")
        #expect(result == .conflict)
    }

    @Test("Verify lock: matching token and valid lease succeeds")
    func verifyLockSuccess() {
        let future = Time.iso8601(Time.leaseExpiry(minutes: 30))
        let page = makePage(lockToken: "token-abc", lockExpires: future)
        let result = LockVerifier.verifyLock(page: page, expectedToken: "token-abc")
        #expect(result == .success)
    }

    @Test("Verify lock: expired lease is lost lock")
    func verifyLockExpired() {
        let past = "2020-01-01T00:00:00Z"
        let page = makePage(lockToken: "token-abc", lockExpires: past)
        let result = LockVerifier.verifyLock(page: page, expectedToken: "token-abc")
        #expect(result == .lostLock)
    }

    @Test("Verify lock: wrong token is lost lock")
    func verifyLockWrongToken() {
        let future = Time.iso8601(Time.leaseExpiry(minutes: 30))
        let page = makePage(lockToken: "token-other", lockExpires: future)
        let result = LockVerifier.verifyLock(page: page, expectedToken: "token-abc")
        #expect(result == .lostLock)
    }
}

@Suite("NTaskError Mapping Tests")
struct NTaskErrorMappingTests {

    @Test("CONFLICT maps to exit code 2")
    func conflictExitCode() {
        let err = NTaskError.conflict("test")
        #expect(err.exitCode == 2)
        #expect(err.code == "CONFLICT")
        #expect(err.message == "test")
    }

    @Test("MISCONFIGURED maps to exit code 3")
    func misconfiguredExitCode() {
        let err = NTaskError.misconfigured("bad config")
        #expect(err.exitCode == 3)
        #expect(err.code == "MISCONFIGURED")
    }

    @Test("CLI_MISSING maps to exit code 3")
    func cliMissingExitCode() {
        let err = NTaskError.cliMissing("not found")
        #expect(err.exitCode == 3)
        #expect(err.code == "CLI_MISSING")
    }

    @Test("LOST_LOCK maps to exit code 4")
    func lostLockExitCode() {
        let err = NTaskError.lostLock("stolen")
        #expect(err.exitCode == 4)
        #expect(err.code == "LOST_LOCK")
    }

    @Test("API_ERROR maps to exit code 5")
    func apiErrorExitCode() {
        let err = NTaskError.apiError("timeout")
        #expect(err.exitCode == 5)
        #expect(err.code == "API_ERROR")
    }

    @Test("ExitCodes constants match NTaskError values")
    func exitCodesConsistency() {
        #expect(ExitCodes.success == 0)
        #expect(ExitCodes.conflict == NTaskError.conflict("").exitCode)
        #expect(ExitCodes.misconfigured == NTaskError.misconfigured("").exitCode)
        #expect(ExitCodes.lostLock == NTaskError.lostLock("").exitCode)
        #expect(ExitCodes.apiError == NTaskError.apiError("").exitCode)
    }
}
