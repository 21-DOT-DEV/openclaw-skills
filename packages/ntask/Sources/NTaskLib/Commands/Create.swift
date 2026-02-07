import ArgumentParser
import Foundation

struct Create: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Create a new task or subtask"
    )

    @Option(name: .long, help: "Unique task identifier")
    var taskId: String

    @Option(name: .long, help: "Task title")
    var title: String

    @Option(name: .long, help: "Numeric priority (higher = more urgent)")
    var priority: Int = 5

    @Option(name: .long, help: "Class of service: EXPEDITE, FIXED_DATE, STANDARD, INTANGIBLE")
    var classOfService: String = "STANDARD"

    @Option(name: .long, help: "Acceptance criteria / definition of done")
    var acceptanceCriteria: String?

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
            var properties: [String: Any] = [
                "TaskID": ["rich_text": [["text": ["content": taskId]]]],
                "title": ["title": [["text": ["content": title]]]],
                "Status": ["select": ["name": status.uppercased()]],
                "Priority": ["number": priority],
                "ClassOfService": ["select": ["name": classOfService.uppercased()]]
            ]
            if let ac = acceptanceCriteria {
                properties["AcceptanceCriteria"] = ["rich_text": [["text": ["content": ac]]]]
            }

            // If parent specified, validate it exists before creating
            var parentTaskId: String? = nil
            var parentPage: NotionPage? = nil
            if let parentId = parent {
                parentPage = try await NotionCLI.resolveTaskIdToPage(parentId)
                parentTaskId = parentId
            }

            let page = try await NotionCLI.createPage(properties: properties)

            // Update parent's DependenciesOpenCount after child creation
            var warning: String? = nil
            if let parentPage, let parentId = parentTaskId {
                do {
                    let currentCount = parentPage.dependenciesOpenCount ?? 0
                    let newCount = currentCount + 1
                    try await NotionCLI.updateProperties(
                        pageId: parentPage.pageId,
                        properties: ["DependenciesOpenCount": ["number": newCount]]
                    )
                } catch {
                    warning = "Task created but failed to update parent '\(parentId)' DependenciesOpenCount. Update it manually."
                }
            }

            var result: [String: Any] = [:]
            var summary = page.toSummary()
            if let pid = parentTaskId {
                summary["parent_task_id"] = pid
            }
            result["task"] = summary
            if let w = warning {
                result["warning"] = w
            }

            JSONOut.success(result)
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
