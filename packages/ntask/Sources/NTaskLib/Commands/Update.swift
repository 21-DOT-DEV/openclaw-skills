import ArgumentParser
import Foundation

struct Update: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Update task properties (priority, status, etc)"
    )

    @Argument(help: "TaskID to update")
    var taskId: String

    @Option(name: .long, help: "New priority value")
    var priority: Int?

    @Option(name: [.long, .customLong("class")], help: "New class of service: Expedite, Fixed Date, Standard, Intangible")
    var classOfService: ClassOfService?

    @Option(name: .long, help: "New status (cannot set to Done — use complete)")
    var status: TaskStatus?

    func run() async throws {
        do {
            // Validate at least one property provided
            guard priority != nil || classOfService != nil || status != nil else {
                JSONOut.error(
                    code: "MISCONFIGURED",
                    message: "At least one property must be specified (--priority, --class-of-service, --status)",
                    exitCode: ExitCodes.misconfigured
                )
            }

            // Validate status transition
            if let s = status {
                let commandForStatus: [TaskStatus: String] = [
                    .done: "complete",
                    .inProgress: "claim",
                    .review: "review"
                ]
                if let cmd = commandForStatus[s] {
                    JSONOut.error(
                        code: "MISCONFIGURED",
                        message: "Cannot set status to \(s.rawValue) via update — use the '\(cmd)' command instead",
                        exitCode: ExitCodes.misconfigured
                    )
                }
            }

            // Validate priority range
            if let p = priority, !(1...3).contains(p) {
                JSONOut.error(
                    code: "MISCONFIGURED",
                    message: "Priority must be 1-3, got \(p)",
                    exitCode: ExitCodes.misconfigured
                )
            }

            let page = try await NotionCLI.resolveTaskIdToPage(taskId)

            // Build properties dict
            var properties: [String: Any] = [:]
            if let p = priority {
                properties["Priority"] = ["number": p]
            }
            if let cos = classOfService {
                properties["Class"] = ["select": ["name": cos.rawValue]]
            }
            if let s = status {
                properties["Status"] = ["status": ["name": s.rawValue]]
            }

            try await NotionCLI.updateProperties(
                pageId: page.pageId,
                properties: properties
            )

            // Re-read to get updated state
            let updated = try await NotionCLI.resolveTaskIdToPage(taskId)
            JSONOut.printEncodable(NTaskSuccessResponse(task: updated.toTaskSummary()))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
