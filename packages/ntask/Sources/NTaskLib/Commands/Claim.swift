import ArgumentParser
import Foundation

struct Claim: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Claim a task for this agent run"
    )

    @Argument(help: "TaskID to claim")
    var taskId: String

    @Option(name: .long, help: "Lease duration in minutes")
    var leaseMin: Int = 15

    func run() async throws {
        do {
            let page = try await NotionCLI.resolveTaskIdToPage(taskId)
            let runId = UUID().uuidString
            let lockToken = UUID().uuidString
            let lockedUntil = Time.iso8601(Time.leaseExpiry(minutes: leaseMin))

            // Determine claim path based on current status
            let isReClaim: Bool
            switch page.status {
            case "Ready":
                isReClaim = false
            case "In Progress":
                // Re-claim: task is In Progress but lock is absent or expired
                if let token = page.lockToken, !token.isEmpty,
                   let expires = page.lockExpires, !Time.isExpired(expires) {
                    // Active lock held by someone — conflict
                    JSONOut.error(
                        code: "CONFLICT",
                        message: "Task is already claimed with an active lock",
                        task: page.toTaskSummary(),
                        exitCode: ExitCodes.conflict
                    )
                }
                isReClaim = true
            default:
                JSONOut.error(
                    code: "MISCONFIGURED",
                    message: "Task must be in Ready or In Progress status to claim (current: \(page.status ?? "unknown"))",
                    task: page.toTaskSummary(),
                    exitCode: ExitCodes.misconfigured
                )
            }

            if isReClaim {
                try await NotionCLI.updateForReClaim(
                    pageId: page.pageId,
                    runId: runId,
                    lockToken: lockToken,
                    lockedUntil: lockedUntil
                )
            } else {
                try await NotionCLI.updateForClaim(
                    pageId: page.pageId,
                    runId: runId,
                    lockToken: lockToken,
                    lockedUntil: lockedUntil
                )
            }

            // Verify claim by re-reading
            let verified = try await NotionCLI.retrievePage(page.pageId)
            let verifyResult = LockVerifier.verifyClaim(
                page: verified,
                expectedToken: lockToken
            )

            switch verifyResult {
            case .success:
                let summary = TaskSummary(
                    pageId: verified.pageId,
                    taskId: verified.taskId,
                    status: verified.status,
                    priority: verified.priority,
                    taskClass: verified.classOfService,
                    agentRun: verified.agentRunId,
                    lockToken: lockToken,
                    lockExpires: lockedUntil,
                    startedAt: verified.startedAt
                )
                try LockStateManager.save(LockState(
                    taskId: taskId,
                    runId: runId,
                    lockToken: lockToken,
                    lockExpires: lockedUntil,
                    pageId: verified.pageId
                ))
                JSONOut.printEncodable(NTaskSuccessResponse(task: summary))
            case .conflict:
                JSONOut.error(
                    code: "CONFLICT",
                    message: "Task was claimed by another agent",
                    task: verified.toTaskSummary(),
                    exitCode: ExitCodes.conflict
                )
            case .lostLock:
                JSONOut.error(
                    code: "LOST_LOCK",
                    message: "Lock was lost during claim verification",
                    task: verified.toTaskSummary(),
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
