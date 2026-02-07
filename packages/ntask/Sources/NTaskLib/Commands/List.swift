import ArgumentParser
import Foundation

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List tasks with optional status filter"
    )

    @Option(name: .long, help: "Filter by status (e.g., READY, IN_PROGRESS, BLOCKED)")
    var status: String?

    @Option(name: .long, help: "Maximum number of results")
    var limit: Int = 50

    func run() async throws {
        do {
            let pages = try await NotionCLI.queryTasks(
                status: status?.uppercased(),
                limit: limit
            )
            let summaries = pages.map { $0.toSummary() }
            JSONOut.success(["tasks": summaries, "count": summaries.count])
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
