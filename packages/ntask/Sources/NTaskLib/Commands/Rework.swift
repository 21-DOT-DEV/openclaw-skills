import ArgumentParser

struct Rework: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Send a reviewed task back for rework"
    )

    @Argument(help: "TaskID to send back (e.g. TASK-42)")
    var taskId: String

    @Option(name: .long, help: "Reason for rework (feedback for the worker)")
    var reason: String

    func run() async throws {
        do {
            let page = try await NotionCLI.resolveTaskIdToPage(taskId)

            // Validate current status is Review
            guard page.status == "Review" else {
                JSONOut.error(
                    code: "MISCONFIGURED",
                    message: "Task must be in Review status to rework (current: \(page.status ?? "unknown"))",
                    task: page.toTaskSummary(),
                    exitCode: ExitCodes.misconfigured
                )
            }

            try await NotionCLI.updateForRework(pageId: page.pageId)
            try await NotionCLI.addComment(pageId: page.pageId, text: reason)

            JSONOut.printEncodable(NTaskSuccessResponse(task: TaskSummary(
                pageId: page.pageId,
                taskId: taskId,
                status: "Ready",
                reason: reason
            )))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
