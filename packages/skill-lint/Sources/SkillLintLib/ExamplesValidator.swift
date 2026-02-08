import Foundation

/// Validates the structure of a references/examples.json file.
public struct ExamplesValidator: Sendable {

    public init() {}

    /// Allowed values for `output_format` in examples.
    public static let allowedOutputFormats: Set<String> = ["json", "line_based", "table", "freeform"]

    /// Required keys in each example entry.
    public static let requiredKeys: Set<String> = ["intent", "command", "output_format", "example_output", "exit_code"]

    /// Validate examples JSON data and return diagnostics.
    public func validate(data: Data, skill: String) -> [LintDiagnostic] {
        var diagnostics: [LintDiagnostic] = []

        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            diagnostics.append(.init(
                skill: skill, severity: .error,
                message: "examples.json: failed to parse JSON: \(error.localizedDescription)"
            ))
            return diagnostics
        }

        guard let array = parsed as? [[String: Any]] else {
            diagnostics.append(.init(
                skill: skill, severity: .error,
                message: "examples.json: expected a JSON array of objects"
            ))
            return diagnostics
        }

        if array.isEmpty {
            diagnostics.append(.init(
                skill: skill, severity: .error,
                message: "examples.json: array must not be empty"
            ))
            return diagnostics
        }

        for (index, entry) in array.enumerated() {
            for key in Self.requiredKeys {
                if entry[key] == nil {
                    diagnostics.append(.init(
                        skill: skill, severity: .error,
                        message: "examples.json[\(index)]: missing required key '\(key)'"
                    ))
                }
            }

            if let fmt = entry["output_format"] as? String {
                if !Self.allowedOutputFormats.contains(fmt) {
                    diagnostics.append(.init(
                        skill: skill, severity: .error,
                        message: "examples.json[\(index)]: invalid 'output_format' value '\(fmt)'"
                    ))
                }
            }
        }

        return diagnostics
    }
}
