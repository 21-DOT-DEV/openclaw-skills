import ArgumentParser

struct Unblock: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Unblock a blocked task (Blocked → In Progress)"
    )

    @Argument(help: "TaskID to unblock")
    var taskId: String

    func run() async throws {
        do {
            let page = try await NotionCLI.resolveTaskIdToPage(taskId)

            // Validate current status is Blocked
            guard page.status == "Blocked" else {
                JSONOut.error(
                    code: "MISCONFIGURED",
                    message: "Task must be in Blocked status to unblock (current: \(page.status ?? "unknown"))",
                    task: page.toTaskSummary(),
                    exitCode: ExitCodes.misconfigured
                )
            }

            try await NotionCLI.updateForUnblock(pageId: page.pageId)

            JSONOut.printEncodable(NTaskSuccessResponse(task: TaskSummary(
                pageId: page.pageId,
                taskId: taskId,
                status: "In Progress",
                blockerReason: page.blockerReason,
                unblockAction: page.unblockAction
            )))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
