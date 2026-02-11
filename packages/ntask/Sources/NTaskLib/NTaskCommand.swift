import ArgumentParser

public enum NTaskVersion {
    public static let current = "0.2.1"
}

public struct NTaskCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "ntask",
        abstract: "Notion task management CLI for OpenClaw agents",
        version: NTaskVersion.current,
        subcommands: [
            Doctor.self,
            Next.self,
            Claim.self,
            Heartbeat.self,
            Complete.self,
            Block.self,
            Create.self,
            List.self,
            Get.self,
            Comment.self,
            Review.self,
            Cancel.self,
            Update.self,
            Version.self,
        ]
    )

    public init() {}
}
