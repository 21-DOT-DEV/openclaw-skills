import ArgumentParser
import Foundation

struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a new task or subtask"
    )

    @Option(name: .long, help: "Task title")
    var title: String

    @Option(name: .long, help: "Numeric priority 1-3 (higher = more urgent)")
    var priority: Int = 2

    @Option(name: .long, help: "Class of service: Expedite, Fixed Date, Standard, Intangible")
    var classOfService: ClassOfService = .standard

    @Option(name: .long, help: "Parent TaskID to create a subtask under")
    var parent: String?

    @Option(name: .long, help: "Initial status: Backlog or Ready")
    var status: TaskStatus = .ready

    func run() async throws {
        do {
            // Validate status
            guard status == .backlog || status == .ready else {
                JSONOut.error(
                    code: "MISCONFIGURED",
                    message: "Initial status must be Backlog or Ready, got '\(status.rawValue)'",
                    exitCode: ExitCodes.misconfigured
                )
            }

            // Validate priority range
            guard (1...3).contains(priority) else {
                JSONOut.error(
                    code: "MISCONFIGURED",
                    message: "Priority must be 1-3, got \(priority)",
                    exitCode: ExitCodes.misconfigured
                )
            }

            // Build properties
            let properties: [String: Any] = [
                "title": ["title": [["text": ["content": title]]]],
                "Status": ["status": ["name": status.rawValue]],
                "Priority": ["number": priority],
                "Class": ["select": ["name": classOfService.rawValue]]
            ]

            // If parent specified, validate it exists before creating
            var parentTaskId: String? = nil
            if let parentId = parent {
                _ = try await NotionCLI.resolveTaskIdToPage(parentId)
                parentTaskId = parentId
            }

            let page = try await NotionCLI.createPage(properties: properties)

            let summary = TaskSummary(
                pageId: page.pageId,
                taskId: page.taskId,
                status: page.status,
                priority: page.priority,
                taskClass: page.classOfService,
                parentTaskId: parentTaskId
            )
            JSONOut.printEncodable(NTaskSuccessResponse(task: summary))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
