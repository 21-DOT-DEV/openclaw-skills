import Foundation

/// Validates the structure of a references/commands.json file.
public struct CommandsValidator: Sendable {

    public init() {}

    /// Allowed values for `output_format`.
    public static let allowedOutputFormats: Set<String> = ExamplesValidator.allowedOutputFormats

    /// Required keys in the top-level object.
    public static let requiredTopLevelKeys: Set<String> = ["skill", "commands"]

    /// Required keys in each command entry.
    public static let requiredCommandKeys: Set<String> = ["name", "binary", "description", "output_format", "examples"]

    /// Required keys in each example entry.
    public static let requiredExampleKeys: Set<String> = ExamplesValidator.requiredKeys

    /// Allowed values for `retry.backoff`.
    public static let allowedBackoffStrategies: Set<String> = ["none", "linear", "exponential"]

    /// Validate commands.json data and return diagnostics.
    public func validate(data: Data, skill: String) -> [LintDiagnostic] {
        var diagnostics: [LintDiagnostic] = []

        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            diagnostics.append(.init(
                skill: skill, severity: .error,
                message: "commands.json: failed to parse JSON: \(error.localizedDescription)"
            ))
            return diagnostics
        }

        guard let root = parsed as? [String: Any] else {
            diagnostics.append(.init(
                skill: skill, severity: .error,
                message: "commands.json: expected a JSON object at top level"
            ))
            return diagnostics
        }

        // Validate top-level required keys
        for key in Self.requiredTopLevelKeys {
            if root[key] == nil {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "commands.json: missing required key '\(key)'"
                ))
            }
        }

        // Validate skill is a non-empty string
        if let skillValue = root["skill"] as? String {
            if skillValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "commands.json: 'skill' must not be empty"
                ))
            }
        } else if root["skill"] != nil {
            diagnostics.append(.init(
                skill: skill, severity: .error,
                message: "commands.json: 'skill' must be a string"
            ))
        }

        // Validate commands array
        guard let commands = root["commands"] as? [[String: Any]] else {
            if root["commands"] != nil {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "commands.json: 'commands' must be an array of objects"
                ))
            }
            return diagnostics
        }

        if commands.isEmpty {
            diagnostics.append(.init(
                skill: skill, severity: .error,
                message: "commands.json: 'commands' array must not be empty"
            ))
            return diagnostics
        }

        var seenNames: Set<String> = []

        for (index, command) in commands.enumerated() {
            diagnostics += validateCommand(command, index: index, skill: skill, seenNames: &seenNames)
        }

        return diagnostics
    }

    private func validateCommand(_ command: [String: Any], index: Int, skill: String, seenNames: inout Set<String>) -> [LintDiagnostic] {
        var diagnostics: [LintDiagnostic] = []
        let prefix = "commands.json[\(index)]"

        // Check required keys
        for key in Self.requiredCommandKeys {
            if command[key] == nil {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): missing required key '\(key)'"
                ))
            }
        }

        // Validate name uniqueness
        if let name = command["name"] as? String {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): 'name' must not be empty"
                ))
            } else if seenNames.contains(name) {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): duplicate command name '\(name)'"
                ))
            } else {
                seenNames.insert(name)
            }
        }

        // Validate output_format
        if let fmt = command["output_format"] as? String {
            if !Self.allowedOutputFormats.contains(fmt) {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): invalid 'output_format' value '\(fmt)'"
                ))
            }
        }

        // Validate parameters (if present, must be an object with "properties")
        if let params = command["parameters"] {
            if let paramsObj = params as? [String: Any] {
                if paramsObj["properties"] == nil {
                    diagnostics.append(.init(
                        skill: skill, severity: .error,
                        message: "\(prefix): 'parameters' must contain 'properties'"
                    ))
                }
            } else {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): 'parameters' must be an object"
                ))
            }
        }

        // Validate examples
        let binary = command["binary"] as? String
        let commandOutputFormat = command["output_format"] as? String

        if let examples = command["examples"] as? [[String: Any]] {
            if examples.isEmpty {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): 'examples' array must not be empty"
                ))
            }
            for (exIdx, example) in examples.enumerated() {
                diagnostics += validateExample(
                    example, commandIndex: index, exampleIndex: exIdx,
                    binary: binary, commandOutputFormat: commandOutputFormat, skill: skill
                )
            }
        } else if command["examples"] != nil {
            diagnostics.append(.init(
                skill: skill, severity: .error,
                message: "\(prefix): 'examples' must be an array of objects"
            ))
        }

        // Validate rate_limit (if present)
        if let rateLimit = command["rate_limit"] as? [String: Any] {
            if let max = rateLimit["max"] as? Int, max <= 0 {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): 'rate_limit.max' must be greater than 0"
                ))
            }
            if let window = rateLimit["window_seconds"] as? Int, window <= 0 {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): 'rate_limit.window_seconds' must be greater than 0"
                ))
            }
        }

        // Validate retry (if present)
        if let retry = command["retry"] as? [String: Any] {
            if let maxAttempts = retry["max_attempts"] as? Int, maxAttempts <= 0 {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): 'retry.max_attempts' must be greater than 0"
                ))
            }
            if let backoff = retry["backoff"] as? String {
                if !Self.allowedBackoffStrategies.contains(backoff) {
                    diagnostics.append(.init(
                        skill: skill, severity: .error,
                        message: "\(prefix): invalid 'retry.backoff' value '\(backoff)' (allowed: \(Self.allowedBackoffStrategies.sorted().joined(separator: ", ")))"
                    ))
                }
            }
        }

        // P2: Warn if destructive but requires_confirmation key is missing
        if let destructive = command["destructive"] as? Bool, destructive {
            if command["requires_confirmation"] == nil {
                diagnostics.append(.init(
                    skill: skill, severity: .warning,
                    message: "\(prefix): destructive command without 'requires_confirmation'"
                ))
            }
        }

        // P2: Warn if requires_confirmation but no confirmation_message
        if let confirm = command["requires_confirmation"] as? Bool, confirm {
            if command["confirmation_message"] == nil {
                diagnostics.append(.init(
                    skill: skill, severity: .warning,
                    message: "\(prefix): 'requires_confirmation' set but no 'confirmation_message' provided"
                ))
            }
        }


        return diagnostics
    }

    private func validateExample(
        _ example: [String: Any], commandIndex: Int, exampleIndex: Int,
        binary: String?, commandOutputFormat: String?, skill: String
    ) -> [LintDiagnostic] {
        var diagnostics: [LintDiagnostic] = []
        let prefix = "commands.json[\(commandIndex)].examples[\(exampleIndex)]"

        // Check required keys
        for key in Self.requiredExampleKeys {
            if example[key] == nil {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): missing required key '\(key)'"
                ))
            }
        }

        // Validate output_format
        if let fmt = example["output_format"] as? String {
            if !Self.allowedOutputFormats.contains(fmt) {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "\(prefix): invalid 'output_format' value '\(fmt)'"
                ))
            }
        }

        // Cross-validate: example command should reference binary (directly or via pipe)
        if let binary = binary, let cmd = example["command"] as? String {
            if !cmd.hasPrefix(binary) && !cmd.contains("| \(binary)") {
                diagnostics.append(.init(
                    skill: skill, severity: .warning,
                    message: "\(prefix): command '\(cmd)' does not reference binary '\(binary)'"
                ))
            }
        }

        // Cross-validate: example output_format should match command output_format
        if let commandFmt = commandOutputFormat, let exampleFmt = example["output_format"] as? String {
            if commandFmt != exampleFmt {
                diagnostics.append(.init(
                    skill: skill, severity: .warning,
                    message: "\(prefix): output_format '\(exampleFmt)' differs from command output_format '\(commandFmt)'"
                ))
            }
        }

        return diagnostics
    }
}
