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

            // SKILL.md line limit check
            let skillMDTrimmed = content.hasSuffix("\n") ? String(content.dropLast()) : content
            let skillMDLineCount = skillMDTrimmed.components(separatedBy: "\n").count
            var fileChecks: [LintDiagnostic] = []
            if skillMDLineCount > 200 {
                fileChecks.append(LintDiagnostic(
                    skill: skillName, severity: .warning,
                    message: "SKILL.md: \(skillMDLineCount) lines exceeds 200-line limit — keep the agent entry point concise"
                ))
            }

            // Broken reference link check
            fileChecks += validateMarkdownLinks(content: content, skillDir: item, skill: skillName)

            guard let rawYAML = parser.extractRawFrontmatter(from: content) else {
                // No frontmatter found
                let severity: LintDiagnostic.Severity = strict ? .error : .warning
                var noFMDiags = fileChecks
                noFMDiags.append(LintDiagnostic(skill: skillName, severity: severity, message: "no YAML frontmatter found in SKILL.md"))
                results.append(SkillResult(
                    directory: skillName,
                    hasFrontmatter: false,
                    diagnostics: noFMDiags
                ))
                continue
            }

            do {
                let frontmatter = try parser.parse(yaml: rawYAML)
                var diagnostics = fileChecks + validator.validate(frontmatter: frontmatter, skill: skillName)

                let commandsPath = item.appendingPathComponent("references/commands.json").path
                let examplesPath = item.appendingPathComponent("references/examples.json").path
                let hasCommands = fm.fileExists(atPath: commandsPath)
                let hasExamples = fm.fileExists(atPath: examplesPath)

                if hasCommands {
                    let commandsData = try Data(contentsOf: URL(fileURLWithPath: commandsPath))
                    let commandsContent = try String(contentsOfFile: commandsPath, encoding: .utf8)
                    let trimmed = commandsContent.hasSuffix("\n") ? String(commandsContent.dropLast()) : commandsContent
                    let lineCount = trimmed.components(separatedBy: "\n").count
                    if lineCount > 500 {
                        diagnostics.append(LintDiagnostic(
                            skill: skillName, severity: .warning,
                            message: "commands.json: \(lineCount) lines exceeds 500-line limit — split commands or reduce examples"
                        ))
                    }
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

    /// Check markdown links in SKILL.md for broken relative references.
    private func validateMarkdownLinks(content: String, skillDir: URL, skill: String) -> [LintDiagnostic] {
        var diagnostics: [LintDiagnostic] = []
        let fm = FileManager.default
        // Match [text](path) but skip URLs (http://, https://, mailto:)
        let pattern = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#)
        let matches = pattern.matches(in: content, range: NSRange(content.startIndex..., in: content))
        for match in matches {
            guard let pathRange = Range(match.range(at: 2), in: content) else { continue }
            let linkPath = String(content[pathRange])
            // Skip external URLs and anchors
            if linkPath.hasPrefix("http://") || linkPath.hasPrefix("https://") ||
               linkPath.hasPrefix("mailto:") || linkPath.hasPrefix("#") {
                continue
            }
            // Strip anchor fragments (e.g. "file.md#section")
            let filePath = linkPath.components(separatedBy: "#").first ?? linkPath
            let resolved = skillDir.appendingPathComponent(filePath).path
            if !fm.fileExists(atPath: resolved) {
                diagnostics.append(LintDiagnostic(
                    skill: skill, severity: .warning,
                    message: "SKILL.md: broken link '\(linkPath)' — target file not found"
                ))
            }
        }
        return diagnostics
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
