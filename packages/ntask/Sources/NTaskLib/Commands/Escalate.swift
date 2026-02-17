import ArgumentParser

struct Escalate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Escalate a task to human attention (provisional — not yet available)"
    )

    @Argument(help: "TaskID to escalate")
    var taskId: String

    func run() async throws {
        JSONOut.error(
            code: "MISCONFIGURED",
            message: "escalate is not available in this version. Requires 'Escalated' status in Notion DB. See deferred.md.",
            exitCode: ExitCodes.misconfigured
        )
    }
}
