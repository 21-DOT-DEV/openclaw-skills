import Foundation

/// Discovers skill directories and lints their SKILL.md frontmatter.
public struct SkillScanner: Sendable {

    private let parser: FrontmatterParser
    private let validator: FrontmatterValidator
    private let examplesValidator: ExamplesValidator
    private let commandsValidator: CommandsValidator

    public init() {
        self.parser = FrontmatterParser()
        self.validator = FrontmatterValidator()
        self.examplesValidator = ExamplesValidator()
        self.commandsValidator = CommandsValidator()
    }

    /// A single skill's lint result.
    public struct SkillResult: Sendable {
        public let directory: String
        public let hasFrontmatter: Bool
        public let diagnostics: [LintDiagnostic]
    }

    /// Scan a skills directory and return lint results for each discovered skill.
    /// A skill is any subdirectory containing a SKILL.md file.
    public func scan(skillsDirectory: String, strict: Bool) throws -> [SkillResult] {
        let fm = FileManager.default
        let skillsURL = URL(fileURLWithPath: skillsDirectory)

        guard fm.fileExists(atPath: skillsDirectory) else {
            throw ScanError.directoryNotFound(skillsDirectory)
        }

        let contents = try fm.contentsOfDirectory(
            at: skillsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var results: [SkillResult] = []

        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }

            let skillMDPath = item.appendingPathComponent("SKILL.md").path
            guard fm.fileExists(atPath: skillMDPath) else {
                continue
            }

            let skillName = item.lastPathComponent
            let content = try String(contentsOfFile: skillMDPath, encoding: .utf8)

            guard let rawYAML = parser.extractRawFrontmatter(from: content) else {
                // No frontmatter found
                let severity: LintDiagnostic.Severity = strict ? .error : .warning
                results.append(SkillResult(
                    directory: skillName,
                    hasFrontmatter: false,
                    diagnostics: [
                        LintDiagnostic(skill: skillName, severity: severity, message: "no YAML frontmatter found in SKILL.md")
                    ]
                ))
                continue
            }

            do {
                let frontmatter = try parser.parse(yaml: rawYAML)
                var diagnostics = validator.validate(frontmatter: frontmatter, skill: skillName)

                let commandsPath = item.appendingPathComponent("references/commands.json").path
                let examplesPath = item.appendingPathComponent("references/examples.json").path
                let hasCommands = fm.fileExists(atPath: commandsPath)
                let hasExamples = fm.fileExists(atPath: examplesPath)

                if hasCommands {
                    let commandsData = try Data(contentsOf: URL(fileURLWithPath: commandsPath))
                    diagnostics += commandsValidator.validate(data: commandsData, skill: skillName)
                    diagnostics += crossValidateCapabilities(
                        commandsData: commandsData, frontmatter: frontmatter, skill: skillName
                    )
                    if hasExamples {
                        diagnostics.append(LintDiagnostic(
                            skill: skillName, severity: .warning,
                            message: "both commands.json and examples.json found; commands.json takes precedence"
                        ))
                    }
                } else if hasExamples {
                    let examplesData = try Data(contentsOf: URL(fileURLWithPath: examplesPath))
                    diagnostics += examplesValidator.validate(data: examplesData, skill: skillName)
                }

                results.append(SkillResult(
                    directory: skillName,
                    hasFrontmatter: true,
                    diagnostics: diagnostics
                ))
            } catch {
                results.append(SkillResult(
                    directory: skillName,
                    hasFrontmatter: true,
                    diagnostics: [
                        LintDiagnostic(skill: skillName, severity: .error, message: "failed to parse frontmatter: \(error)")
                    ]
                ))
            }
        }

        return results
    }

    /// Cross-validate capability fields in commands.json against frontmatter capabilities.
    private func crossValidateCapabilities(
        commandsData: Data, frontmatter: SkillFrontmatter, skill: String
    ) -> [LintDiagnostic] {
        guard let capabilities = frontmatter.capabilities, !capabilities.isEmpty else {
            return []
        }

        let capabilityIDs = Set(capabilities.compactMap { $0.id })
        guard !capabilityIDs.isEmpty else { return [] }

        var diagnostics: [LintDiagnostic] = []

        guard let parsed = try? JSONSerialization.jsonObject(with: commandsData, options: []),
              let root = parsed as? [String: Any],
              let commands = root["commands"] as? [[String: Any]] else {
            return []
        }

        for (index, command) in commands.enumerated() {
            if let capability = command["capability"] as? String {
                if !capabilityIDs.contains(capability) {
                    diagnostics.append(LintDiagnostic(
                        skill: skill, severity: .warning,
                        message: "commands.json[\(index)]: capability '\(capability)' not found in frontmatter capabilities"
                    ))
                }
            }
        }

        return diagnostics
    }
}

/// Errors from skill scanning.
public enum ScanError: Error, CustomStringConvertible {
    case directoryNotFound(String)

    public var description: String {
        switch self {
        case .directoryNotFound(let path):
            return "Skills directory not found: \(path)"
        }
    }
}
