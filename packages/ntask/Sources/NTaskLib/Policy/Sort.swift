import Foundation

enum PullPolicy {

    /// Check if a page is eligible for selection per pull_policy.md rules.
    static func isEligible(_ page: NotionPage) -> Bool {
        // 1. Status must be READY
        guard page.status == "READY" else { return false }

        // 2. Lock must be empty or expired
        if let claimedBy = page.claimedBy, claimedBy == "HUMAN" {
            return false // Rule 5: never auto-pull human-claimed
        }
        if let claimedBy = page.claimedBy, !claimedBy.isEmpty {
            // Has a claim — check if lock expired.
            // If Lock Expires is nil (inconsistent state from a failed mid-update),
            // fall through and treat as claimable.
            if let lockExpires = page.lockExpires, !Time.isExpired(lockExpires) {
                return false // Lock still active
            }
        }

        return true
    }

    /// Sort eligible pages per deterministic pull policy.
    /// Order: ClassOfService rank ASC, Priority DESC, last_edited_time ASC.
    static func sort(_ pages: [NotionPage]) -> [NotionPage] {
        pages.sorted { a, b in
            let rankA = ClassOfServiceRank.rank(for: a.classOfService)
            let rankB = ClassOfServiceRank.rank(for: b.classOfService)
            if rankA != rankB { return rankA < rankB }

            let prioA = a.priority ?? 0
            let prioB = b.priority ?? 0
            if prioA != prioB { return prioA > prioB }

            let editA = a.lastEditedTime ?? ""
            let editB = b.lastEditedTime ?? ""
            return editA < editB
        }
    }
}
