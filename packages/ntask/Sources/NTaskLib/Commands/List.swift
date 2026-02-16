import ArgumentParser

struct List: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List tasks with optional status filter"
    )

    @Option(name: .long, help: "Filter by status (e.g., Ready, In Progress, Blocked)")
    var status: TaskStatus?

    @Option(name: .long, help: "Maximum number of results")
    var limit: Int = 50

    func run() async throws {
        do {
            let pages = try await NotionCLI.queryTasks(
                status: status?.rawValue,
                limit: limit
            )
            let summaries = pages.map { $0.toTaskSummary() }
            JSONOut.printEncodable(ListTasksResponse(tasks: summaries))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
