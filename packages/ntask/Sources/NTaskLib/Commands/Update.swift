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

    @Option(name: .long, help: "New class of service")
    var classOfService: String?

    @Option(name: .long, help: "New status (cannot set to DONE — use complete)")
    var status: String?

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
            if let s = status?.uppercased() {
                // These statuses require dedicated commands with lock verification
                let commandForStatus: [String: String] = [
                    "DONE": "complete",
                    "IN_PROGRESS": "claim"
                ]
                if let cmd = commandForStatus[s] {
                    JSONOut.error(
                        code: "MISCONFIGURED",
                        message: "Cannot set status to \(s) via update — use the '\(cmd)' command instead",
                        exitCode: ExitCodes.misconfigured
                    )
                }
                let validStatuses = ["BACKLOG", "READY", "BLOCKED", "REVIEW", "CANCELED"]
                if !validStatuses.contains(s) {
                    JSONOut.error(
                        code: "MISCONFIGURED",
                        message: "Invalid status '\(s)'. Must be one of: \(validStatuses.joined(separator: ", "))",
                        exitCode: ExitCodes.misconfigured
                    )
                }
            }

            // Validate class of service
            if let cos = classOfService?.uppercased() {
                let validCos = ["EXPEDITE", "FIXED_DATE", "STANDARD", "INTANGIBLE"]
                if !validCos.contains(cos) {
                    JSONOut.error(
                        code: "MISCONFIGURED",
                        message: "Invalid class of service '\(cos)'. Must be one of: \(validCos.joined(separator: ", "))",
                        exitCode: ExitCodes.misconfigured
                    )
                }
            }

            let page = try await NotionCLI.resolveTaskIdToPage(taskId)

            // Build properties dict
            var properties: [String: Any] = [:]
            if let p = priority {
                properties["Priority"] = ["number": p]
            }
            if let cos = classOfService {
                properties["Class"] = ["select": ["name": cos.uppercased()]]
            }
            if let s = status {
                properties["Status"] = ["select": ["name": s.uppercased()]]
            }

            try await NotionCLI.updateProperties(
                pageId: page.pageId,
                properties: properties
            )

            // Re-read to get updated state
            let updated = try await NotionCLI.resolveTaskIdToPage(taskId)
            JSONOut.success(["task": updated.toSummary()])
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
