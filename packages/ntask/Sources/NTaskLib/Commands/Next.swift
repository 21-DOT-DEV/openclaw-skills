import ArgumentParser
import Foundation

struct Next: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Get the highest-priority ready task"
    )

    func run() async throws {
        do {
            let pages = try await NotionCLI.queryReadyTasks()
            let eligible = pages.filter { page in
                PullPolicy.isEligible(page)
            }
            let sorted = PullPolicy.sort(eligible)

            if let best = sorted.first {
                JSONOut.success(["task": best.toSummary()])
            } else {
                JSONOut.success(["task": NSNull(), "message": "No ready tasks found"])
            }
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
