import ArgumentParser
import Foundation

struct Get: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Get full details of a specific task"
    )

    @Argument(help: "TaskID to look up")
    var taskId: String

    func run() async throws {
        do {
            let page = try await NotionCLI.resolveTaskIdToPage(taskId)
            JSONOut.success(["task": page.toSummary()])
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
