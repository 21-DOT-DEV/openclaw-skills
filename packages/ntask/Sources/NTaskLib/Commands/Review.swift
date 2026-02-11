import ArgumentParser
import Foundation

struct Review: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Move task to REVIEW for human inspection"
    )

    @Argument(help: "TaskID to move to review")
    var taskId: String

    @Option(name: .long, help: "Unique run identifier")
    var runId: String

    @Option(name: .long, help: "Lock token from claim")
    var lockToken: String

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

            try await NotionCLI.updateForReview(
                pageId: page.pageId
            )

            JSONOut.success(["task": [
                "page_id": page.pageId,
                "task_id": taskId,
                "status": "Review"
            ]])
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
