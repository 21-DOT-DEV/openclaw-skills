import ArgumentParser

struct Heartbeat: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Extend the lock lease on a claimed task"
    )

    @Argument(help: "TaskID to heartbeat")
    var taskId: String

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

            let newExpiry = Time.iso8601(Time.leaseExpiry(minutes: 15))
            try await NotionCLI.updateForHeartbeat(
                pageId: page.pageId,
                lockedUntil: newExpiry
            )

            // Update state file with new expiry
            try LockStateManager.save(LockState(
                taskId: state.taskId,
                runId: state.runId,
                lockToken: state.lockToken,
                lockExpires: newExpiry,
                pageId: state.pageId
            ))

            JSONOut.printEncodable(NTaskSuccessResponse(task: TaskSummary(
                pageId: page.pageId,
                taskId: taskId,
                lockExpires: newExpiry
            )))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
