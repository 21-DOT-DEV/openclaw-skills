import ArgumentParser

struct Comment: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a comment to a task"
    )

    @Argument(help: "TaskID to comment on")
    var taskId: String

    @Option(name: .long, help: "Comment text")
    var text: String

    func run() async throws {
        do {
            let page = try await NotionCLI.resolveTaskIdToPage(taskId)
            try await NotionCLI.addComment(pageId: page.pageId, text: text)
            JSONOut.printEncodable(CommentResponse(taskId: taskId, comment: text))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
