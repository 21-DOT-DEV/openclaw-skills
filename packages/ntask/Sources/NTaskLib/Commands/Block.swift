import ArgumentParser

struct Block: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Mark a task as BLOCKED with reason"
    )

    @Argument(help: "TaskID to block")
    var taskId: String

    @Option(name: .long, help: "Reason the task is blocked")
    var reason: String

    @Option(name: .long, help: "What needs to happen to unblock")
    var unblockAction: String

    @Option(name: .long, help: "ISO 8601 timestamp for next check (optional)")
    var nextCheck: String?

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

            try await NotionCLI.updateForBlock(
                pageId: page.pageId,
                reason: reason,
                unblockAction: unblockAction,
                nextCheck: nextCheck
            )

            try LockStateManager.clear()

            JSONOut.printEncodable(NTaskSuccessResponse(task: TaskSummary(
                pageId: page.pageId,
                taskId: taskId,
                status: "Blocked",
                blockerReason: reason,
                unblockAction: unblockAction,
                nextCheckAt: nextCheck
            )))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
