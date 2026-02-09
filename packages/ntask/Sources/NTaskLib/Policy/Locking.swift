import Foundation

enum LockVerifyResult {
    case success
    case conflict
    case lostLock
}

enum LockVerifier {

    /// Verify a claim by checking if our lock token was written successfully.
    static func verifyClaim(page: NotionPage, expectedToken: String) -> LockVerifyResult {
        guard let pageToken = page.lockToken, pageToken == expectedToken else {
            return .conflict
        }
        return .success
    }

    /// Verify we still hold the lock on a page.
    static func verifyLock(page: NotionPage, expectedToken: String) -> LockVerifyResult {
        guard let pageToken = page.lockToken, pageToken == expectedToken else {
            return .lostLock
        }
        // Also check if lock is expired
        if let lockExpires = page.lockExpires, Time.isExpired(lockExpires) {
            return .lostLock
        }
        return .success
    }
}
