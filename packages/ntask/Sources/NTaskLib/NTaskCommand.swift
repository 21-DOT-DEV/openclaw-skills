import ArgumentParser

public enum NTaskVersion {
    public static let current = "0.4.0"
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
            Block.self,
            Unblock.self,
            Escalate.self,
            Create.self,
            List.self,
            Get.self,
            Comment.self,
            Review.self,
            Approve.self,
            Rework.self,
            Cancel.self,
            Update.self,
            Version.self,
        ]
    )

    public init() {}
}
