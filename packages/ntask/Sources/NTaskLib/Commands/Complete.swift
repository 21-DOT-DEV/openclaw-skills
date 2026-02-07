import ArgumentParser
import Foundation

struct Complete: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Mark a task as DONE and record artifacts"
    )

    @Argument(help: "TaskID to complete")
    var taskId: String

    @Option(name: .long, help: "Unique run identifier")
    var runId: String

    @Option(name: .long, help: "Lock token from claim")
    var lockToken: String

    @Option(name: .long, help: "Artifacts description")
    var artifacts: String

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

            let doneAt = Time.iso8601(Time.now())
            try await NotionCLI.updateForComplete(
                pageId: page.pageId,
                artifacts: artifacts,
                doneAt: doneAt
            )

            JSONOut.success([
                "task": [
                    "page_id": page.pageId,
                    "task_id": taskId,
                    "status": "DONE",
                    "done_at": doneAt
                ]
            ])
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
