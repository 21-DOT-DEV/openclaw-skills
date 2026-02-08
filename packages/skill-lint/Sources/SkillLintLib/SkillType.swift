/// The type of skill — determines how it is built and installed.
public enum SkillType: String, Sendable {
    case swiftCLI = "swift_cli"
    case externalCLI = "external_cli"
}
