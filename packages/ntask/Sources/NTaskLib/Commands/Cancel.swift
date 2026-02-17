import ArgumentParser

struct Cancel: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Cancel a task with reason"
    )

    @Argument(help: "TaskID to cancel")
    var taskId: String

    @Option(name: .long, help: "Reason for cancellation")
    var reason: String

    func run() async throws {
        do {
            let page = try await NotionCLI.resolveTaskIdToPage(taskId)

            // Conditional lock behavior based on current status
            switch page.status {
            case "Done", "Canceled":
                // Idempotent: already in terminal state
                JSONOut.printEncodable(NTaskSuccessResponse(task: TaskSummary(
                    pageId: page.pageId,
                    taskId: taskId,
                    status: page.status,
                    reason: reason
                )))
                return
            case "In Progress":
                // Must verify lock when canceling from In Progress
                let state = try LockStateManager.load(expectedTaskId: taskId)
                let lockCheck = LockVerifier.verifyLock(page: page, expectedToken: state.lockToken)
                guard case .success = lockCheck else {
                    JSONOut.error(
                        code: "LOST_LOCK",
                        message: "Lock token does not match; lock was stolen or expired",
                        task: page.toTaskSummary(),
                        exitCode: ExitCodes.lostLock
                    )
                }
            default:
                // Lock-free cancel from Ready, Blocked, Review, Backlog
                break
            }

            try await NotionCLI.updateForCancel(
                pageId: page.pageId,
                reason: reason
            )

            // Clear state file if we were holding a lock
            if page.status == "In Progress" {
                try LockStateManager.clear()
            }

            JSONOut.printEncodable(NTaskSuccessResponse(task: TaskSummary(
                pageId: page.pageId,
                taskId: taskId,
                status: "Canceled",
                reason: reason
            )))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
