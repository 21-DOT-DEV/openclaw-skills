import ArgumentParser
import Foundation

struct Cancel: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Cancel a task with reason"
    )

    @Argument(help: "TaskID to cancel")
    var taskId: String

    @Option(name: .long, help: "Unique run identifier")
    var runId: String

    @Option(name: .long, help: "Lock token from claim")
    var lockToken: String

    @Option(name: .long, help: "Reason for cancellation")
    var reason: String

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

            try await NotionCLI.updateForCancel(
                pageId: page.pageId,
                reason: reason
            )

            JSONOut.success([
                "task": [
                    "page_id": page.pageId,
                    "task_id": taskId,
                    "status": "Canceled",
                    "reason": reason
                ]
            ])
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
