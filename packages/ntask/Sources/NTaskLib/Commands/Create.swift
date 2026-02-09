import ArgumentParser
import Foundation

struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a new task or subtask"
    )

    @Option(name: .long, help: "Task title")
    var title: String

    @Option(name: .long, help: "Numeric priority (higher = more urgent)")
    var priority: Int = 5

    @Option(name: .long, help: "Class of service: EXPEDITE, FIXED_DATE, STANDARD, INTANGIBLE")
    var classOfService: String = "STANDARD"

    @Option(name: .long, help: "Parent TaskID to create a subtask under")
    var parent: String?

    @Option(name: .long, help: "Initial status: BACKLOG or READY")
    var status: String = "READY"

    func run() async throws {
        do {
            // Validate status
            let validStatuses = ["BACKLOG", "READY"]
            guard validStatuses.contains(status.uppercased()) else {
                JSONOut.error(
                    code: "MISCONFIGURED",
                    message: "Initial status must be BACKLOG or READY, got '\(status)'",
                    exitCode: ExitCodes.misconfigured
                )
            }

            // Validate class of service
            let validCos = ["EXPEDITE", "FIXED_DATE", "STANDARD", "INTANGIBLE"]
            guard validCos.contains(classOfService.uppercased()) else {
                JSONOut.error(
                    code: "MISCONFIGURED",
                    message: "Class of service must be one of: \(validCos.joined(separator: ", "))",
                    exitCode: ExitCodes.misconfigured
                )
            }

            // Build properties
            let properties: [String: Any] = [
                "title": ["title": [["text": ["content": title]]]],
                "Status": ["select": ["name": status.uppercased()]],
                "Priority": ["number": priority],
                "Class": ["select": ["name": classOfService.uppercased()]]
            ]

            // If parent specified, validate it exists before creating
            var parentTaskId: String? = nil
            if let parentId = parent {
                _ = try await NotionCLI.resolveTaskIdToPage(parentId)
                parentTaskId = parentId
            }

            let page = try await NotionCLI.createPage(properties: properties)

            var result: [String: Any] = [:]
            var summary = page.toSummary()
            if let pid = parentTaskId {
                summary["parent_task_id"] = pid
            }
            result["task"] = summary

            JSONOut.success(result)
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
