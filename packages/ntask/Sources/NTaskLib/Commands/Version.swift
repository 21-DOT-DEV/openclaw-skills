import ArgumentParser

struct Version: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print version information"
    )

    func run() async throws {
        JSONOut.printEncodable(VersionInfo(version: NTaskVersion.current))
    }
}
