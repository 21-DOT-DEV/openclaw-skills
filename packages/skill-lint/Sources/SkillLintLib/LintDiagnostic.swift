/// A single lint finding for a skill.
public struct LintDiagnostic: Sendable {
    public enum Severity: String, Sendable {
        case error
        case warning
    }

    public let skill: String
    public let severity: Severity
    public let message: String

    public init(skill: String, severity: Severity, message: String) {
        self.skill = skill
        self.severity = severity
        self.message = message
    }
}
