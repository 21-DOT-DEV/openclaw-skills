import ArgumentParser

struct Reap: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Reap orphaned tasks with expired locks"
    )

    func run() async throws {
        do {
            let pages = try await NotionCLI.queryTasks(status: "In Progress")

            // Filter to orphans: In Progress with non-nil lock fields and expired lock
            let orphans = pages.filter { page in
                guard let _ = page.lockToken,
                      let lockExpires = page.lockExpires else {
                    return false
                }
                return Time.isExpired(lockExpires)
            }

            var reaped: [ReapedTask] = []
            for page in orphans {
                try await NotionCLI.updateForReap(pageId: page.pageId)
                reaped.append(ReapedTask(
                    taskId: page.taskId ?? page.pageId,
                    lockExpiredAt: page.lockExpires ?? ""
                ))
            }

            JSONOut.printEncodable(ReapResponse(reaped: reaped))
        } catch let error as NTaskError {
            JSONOut.error(code: error.code, message: error.message, exitCode: error.exitCode)
        } catch {
            JSONOut.error(code: "API_ERROR", message: NotionCLI.redact(error.localizedDescription), exitCode: ExitCodes.apiError)
        }
    }
}
