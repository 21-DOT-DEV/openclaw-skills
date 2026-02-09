import ArgumentParser
import Foundation

struct Heartbeat: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Extend the lock lease on a claimed task"
    )

    @Argument(help: "TaskID to heartbeat")
    var taskId: String

    @Option(name: .long, help: "Unique run identifier")
    var runId: String

    @Option(name: .long, help: "Lock token from claim")
    var lockToken: String

    @Option(name: .long, help: "Lease duration in minutes")
    var leaseMin: Int = 20

    func run() async throws {
        do {
            let page = try await NotionCLI.resolveTaskIdToPage(taskId)

            // Verify current lock
            let lockCheck = LockVerifier.verifyLock(page: page, expectedToken: lockToken)
            guard case .success = lockCheck else {
                JSONOut.error(
                    code: "LOST_LOCK",
                    message: "Lock token does not match; lock was stolen or expired",
                    task: page.toSummary(),
                    exitCode: ExitCodes.lostLock
                )
            }

            let newExpiry = Time.iso8601(Time.leaseExpiry(minutes: leaseMin))
            try await NotionCLI.updateForHeartbeat(
                pageId: page.pageId,
                lockedUntil: newExpiry
            )

            JSONOut.success([
                "task": [
                    "page_id": page.pageId,
                    "task_id": taskId,
                    "lock_expires": newExpiry
                ]
            ])
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
