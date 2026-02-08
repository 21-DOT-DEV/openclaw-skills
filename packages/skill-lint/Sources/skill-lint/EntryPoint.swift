import ArgumentParser
import Foundation
import SkillLintLib

@main
struct SkillLintCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skill-lint",
        abstract: "Validate YAML frontmatter in SKILL.md files.",
        version: "0.1.0"
    )

    @Argument(help: "Path to the skills/ directory to scan.")
    var skillsDirectory: String

    @Flag(name: .long, help: "Treat missing frontmatter as an error (default: warn).")
    var strict: Bool = false

    func run() throws {
        let scanner = SkillScanner()
        let results = try scanner.scan(skillsDirectory: skillsDirectory, strict: strict)

        if results.isEmpty {
            print("⚠️  No skills found in \(skillsDirectory)")
            throw ExitCode.failure
        }

        var errorCount = 0
        var warningCount = 0

        for result in results {
            let icon = result.diagnostics.isEmpty ? "✅" : (result.diagnostics.contains { $0.severity == .error } ? "❌" : "⚠️")
            print("\(icon) \(result.directory)")

            for diag in result.diagnostics {
                let prefix = diag.severity == .error ? "  ❌" : "  ⚠️"
                print("\(prefix) \(diag.message)")
                switch diag.severity {
                case .error: errorCount += 1
                case .warning: warningCount += 1
                }
            }
        }

        print("")
        print("Skills: \(results.count)  Errors: \(errorCount)  Warnings: \(warningCount)")

        if errorCount > 0 {
            throw ExitCode.failure
        }
    }
}
