import ArgumentParser

struct Version: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print version information"
    )

    func run() async throws {
        JSONOut.success(["version": NTaskCommand.configuration.version])
    }
}
