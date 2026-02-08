import Testing
@testable import SkillLintLib
import Foundation

@Suite("CommandsValidator Tests")
struct CommandsValidatorTests {
    let validator = CommandsValidator()

    private func jsonData(_ string: String) -> Data {
        string.data(using: .utf8)!
    }

    // MARK: - Top-level validation

    @Test("valid commands.json produces no errors")
    func validCommandsJSON() {
        let json = """
        {
            "skill": "test-skill",
            "commands": [
                {
                    "name": "doctor",
                    "binary": "mytool",
                    "description": "Check environment",
                    "output_format": "json",
                    "examples": [
                        {
                            "intent": "Check env",
                            "command": "mytool doctor",
                            "output_format": "json",
                            "example_output": {"ok": true},
                            "exit_code": 0
                        }
                    ]
                }
            ]
        }
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        let errors = diags.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    @Test("invalid JSON produces parse error")
    func invalidJSON() {
        let diags = validator.validate(data: jsonData("not json"), skill: "test")
        #expect(diags.contains { $0.message.contains("failed to parse JSON") })
    }

    @Test("non-object top level produces error")
    func nonObjectTopLevel() {
        let diags = validator.validate(data: jsonData("[1, 2, 3]"), skill: "test")
        #expect(diags.contains { $0.message.contains("expected a JSON object") })
    }

    @Test("missing skill key produces error")
    func missingSkill() {
        let json = """
        {"commands": [{"name": "x", "binary": "x", "description": "x", "output_format": "json", "examples": [{"intent": "x", "command": "x", "output_format": "json", "example_output": {}, "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("missing required key 'skill'") })
    }

    @Test("empty skill produces error")
    func emptySkill() {
        let json = """
        {"skill": "  ", "commands": [{"name": "x", "binary": "x", "description": "x", "output_format": "json", "examples": [{"intent": "x", "command": "x", "output_format": "json", "example_output": {}, "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("'skill' must not be empty") })
    }

    @Test("missing commands key produces error")
    func missingCommands() {
        let json = """
        {"skill": "test"}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("missing required key 'commands'") })
    }

    @Test("empty commands array produces error")
    func emptyCommands() {
        let json = """
        {"skill": "test", "commands": []}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("'commands' array must not be empty") })
    }

    // MARK: - Command-level validation

    @Test("missing command required keys produces errors")
    func missingCommandKeys() {
        let json = """
        {"skill": "test", "commands": [{}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        let errors = diags.filter { $0.severity == .error }
        #expect(errors.contains { $0.message.contains("'name'") })
        #expect(errors.contains { $0.message.contains("'binary'") })
        #expect(errors.contains { $0.message.contains("'description'") })
        #expect(errors.contains { $0.message.contains("'output_format'") })
        #expect(errors.contains { $0.message.contains("'examples'") })
    }

    @Test("duplicate command names produce error")
    func duplicateNames() {
        let json = """
        {
            "skill": "test",
            "commands": [
                {"name": "dup", "binary": "x", "description": "x", "output_format": "json", "examples": [{"intent": "x", "command": "x", "output_format": "json", "example_output": {}, "exit_code": 0}]},
                {"name": "dup", "binary": "x", "description": "x", "output_format": "json", "examples": [{"intent": "x", "command": "x", "output_format": "json", "example_output": {}, "exit_code": 0}]}
            ]
        }
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("duplicate command name 'dup'") })
    }

    @Test("invalid output_format on command produces error")
    func invalidCommandOutputFormat() {
        let json = """
        {"skill": "test", "commands": [{"name": "x", "binary": "x", "description": "x", "output_format": "xml", "examples": [{"intent": "x", "command": "x", "output_format": "xml", "example_output": {}, "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("invalid 'output_format' value 'xml'") })
    }

    @Test("parameters without properties produces error")
    func parametersMissingProperties() {
        let json = """
        {"skill": "test", "commands": [{"name": "x", "binary": "x", "description": "x", "output_format": "json", "parameters": {"type": "object"}, "examples": [{"intent": "x", "command": "x", "output_format": "json", "example_output": {}, "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("'parameters' must contain 'properties'") })
    }

    // MARK: - Example cross-validation

    @Test("example command not starting with binary produces warning")
    func exampleBinaryMismatch() {
        let json = """
        {"skill": "test", "commands": [{"name": "x", "binary": "mytool", "description": "x", "output_format": "json", "examples": [{"intent": "x", "command": "other-tool run", "output_format": "json", "example_output": {}, "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("does not start with binary") && $0.severity == .warning })
    }

    @Test("example output_format mismatch produces warning")
    func exampleFormatMismatch() {
        let json = """
        {"skill": "test", "commands": [{"name": "x", "binary": "x", "description": "x", "output_format": "json", "examples": [{"intent": "x", "command": "x run", "output_format": "line_based", "example_output": "text", "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("differs from command output_format") && $0.severity == .warning })
    }

    // MARK: - P2: Permission warnings

    @Test("destructive without requires_confirmation produces warning")
    func destructiveNoConfirmation() {
        let json = """
        {"skill": "test", "commands": [{"name": "x", "binary": "x", "description": "x", "output_format": "json", "destructive": true, "examples": [{"intent": "x", "command": "x", "output_format": "json", "example_output": {}, "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("destructive command without 'requires_confirmation'") && $0.severity == .warning })
    }

    @Test("requires_confirmation without confirmation_message produces warning")
    func confirmNoMessage() {
        let json = """
        {"skill": "test", "commands": [{"name": "x", "binary": "x", "description": "x", "output_format": "json", "destructive": true, "requires_confirmation": true, "examples": [{"intent": "x", "command": "x", "output_format": "json", "example_output": {}, "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("no 'confirmation_message' provided") && $0.severity == .warning })
    }

    // MARK: - P3: Operational metadata

    @Test("retry on non-idempotent command produces warning")
    func retryNonIdempotent() {
        let json = """
        {"skill": "test", "commands": [{"name": "x", "binary": "x", "description": "x", "output_format": "json", "idempotent": false, "retry": {"max_attempts": 3, "backoff": "exponential"}, "examples": [{"intent": "x", "command": "x", "output_format": "json", "example_output": {}, "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("'retry' specified on non-idempotent") && $0.severity == .warning })
    }

    @Test("invalid retry backoff produces error")
    func invalidBackoff() {
        let json = """
        {"skill": "test", "commands": [{"name": "x", "binary": "x", "description": "x", "output_format": "json", "retry": {"max_attempts": 3, "backoff": "random"}, "examples": [{"intent": "x", "command": "x", "output_format": "json", "example_output": {}, "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("invalid 'retry.backoff'") && $0.severity == .error })
    }

    @Test("rate_limit with zero max produces error")
    func rateLimitZeroMax() {
        let json = """
        {"skill": "test", "commands": [{"name": "x", "binary": "x", "description": "x", "output_format": "json", "rate_limit": {"max": 0, "window_seconds": 3600}, "examples": [{"intent": "x", "command": "x", "output_format": "json", "example_output": {}, "exit_code": 0}]}]}
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("'rate_limit.max' must be greater than 0") })
    }
}
