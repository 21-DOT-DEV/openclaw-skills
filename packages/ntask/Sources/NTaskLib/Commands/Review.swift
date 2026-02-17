import ArgumentParser

struct Review: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Move task to REVIEW for human inspection"
    )

    @Argument(help: "TaskID to move to review")
    var taskId: String

    @Option(name: .long, help: "Work summary for reviewer")
    var summary: String

    func run() async throws {
        do {
            let state = try LockStateManager.load(expectedTaskId: taskId)
            let page = try await NotionCLI.resolveTaskIdToPage(taskId)

            // Verify current lock
            let lockCheck = LockVerifier.verifyLock(page: page, expectedToken: state.lockToken)
            guard case .success = lockCheck else {
                JSONOut.error(
                    code: "LOST_LOCK",
                    message: "Lock token does not match; lock was stolen or expired",
                    task: page.toTaskSummary(),
                    exitCode: ExitCodes.lostLock
                )
            }

            // Check sub-tasks: block review if any are incomplete
            if let total = page.dependencies, total > 0 {
                let completed = page.completedSubtasks ?? 0
                if completed < total {
                    let open = total - completed
                    JSONOut.error(
                        code: "INCOMPLETE_SUBTASKS",
                        message: "Cannot review: \(open)/\(total) sub-tasks still open",
                        task: page.toTaskSummary(),
                        exitCode: ExitCodes.incompleteSubtasks
                    )
                }
            }

            // Write summary as comment
            try await NotionCLI.addComment(pageId: page.pageId, text: summary)

            try await NotionCLI.updateForReview(
                pageId: page.pageId
            )

            try LockStateManager.clear()

            JSONOut.printEncodable(NTaskSuccessResponse(task: TaskSummary(
                pageId: page.pageId,
                taskId: taskId,
                status: "Review"
            )))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
