import ArgumentParser
import Foundation

struct Approve: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Approve a reviewed task and mark as Done"
    )

    @Argument(help: "TaskID to approve (e.g. TASK-42)")
    var taskId: String

    @Option(name: .long, help: "Optional approval summary")
    var summary: String?

    func run() async throws {
        do {
            let page = try await NotionCLI.resolveTaskIdToPage(taskId)

            // Validate current status is Review
            guard page.status == "Review" else {
                JSONOut.error(
                    code: "MISCONFIGURED",
                    message: "Task must be in Review status to approve (current: \(page.status ?? "unknown"))",
                    task: page.toSummary(),
                    exitCode: ExitCodes.misconfigured
                )
            }

            let doneAt = Time.iso8601(Time.now())
            try await NotionCLI.updateForApprove(
                pageId: page.pageId,
                doneAt: doneAt
            )

            if let summary {
                try await NotionCLI.addComment(pageId: page.pageId, text: summary)
            }

            JSONOut.success([
                "task": [
                    "page_id": page.pageId,
                    "task_id": taskId,
                    "status": "Done",
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
