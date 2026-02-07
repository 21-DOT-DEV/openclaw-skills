import ArgumentParser
import Foundation

struct Claim: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Claim a task for this agent run"
    )

    @Argument(help: "TaskID to claim")
    var taskId: String

    @Option(name: .long, help: "Unique run identifier")
    var runId: String

    @Option(name: .long, help: "Agent name")
    var agentName: String

    @Option(name: .long, help: "Lease duration in minutes")
    var leaseMin: Int = 20

    func run() async throws {
        do {
            let page = try await NotionCLI.resolveTaskIdToPage(taskId)
            let lockToken = UUID().uuidString
            let lockedUntil = Time.iso8601(Time.leaseExpiry(minutes: leaseMin))

            try await NotionCLI.updateForClaim(
                pageId: page.pageId,
                runId: runId,
                agentName: agentName,
                lockToken: lockToken,
                lockedUntil: lockedUntil
            )

            // Verify claim by re-reading
            let verified = try await NotionCLI.retrievePage(page.pageId)
            let verifyResult = LockVerifier.verifyClaim(
                page: verified,
                expectedToken: lockToken
            )

            switch verifyResult {
            case .success:
                var summary = verified.toSummary()
                summary["lock_token"] = lockToken
                summary["locked_until"] = lockedUntil
                JSONOut.success(["task": summary])
            case .conflict:
                JSONOut.error(
                    code: "CONFLICT",
                    message: "Task was claimed by another agent",
                    task: verified.toSummary(),
                    exitCode: ExitCodes.conflict
                )
            case .lostLock:
                JSONOut.error(
                    code: "LOST_LOCK",
                    message: "Lock was lost during claim verification",
                    task: verified.toSummary(),
                    exitCode: ExitCodes.lostLock
                )
            }
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
