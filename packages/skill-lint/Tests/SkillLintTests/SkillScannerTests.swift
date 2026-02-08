import Testing
import Foundation
@testable import SkillLintLib

@Suite("SkillScanner Tests")
struct SkillScannerTests {
    let scanner = SkillScanner()

    /// Create a temporary skills directory with subdirectories and SKILL.md files.
    private func makeTempSkillsDir(
        skills: [(name: String, content: String?)]
    ) throws -> String {
        let base = NSTemporaryDirectory()
            .appending("skill-lint-tests-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(atPath: base, withIntermediateDirectories: true)
        for skill in skills {
            let dir = (base as NSString).appendingPathComponent(skill.name)
            try fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
            if let content = skill.content {
                let file = (dir as NSString).appendingPathComponent("SKILL.md")
                try content.write(toFile: file, atomically: true, encoding: .utf8)
            }
        }
        return base
    }

    private func cleanup(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Discovery

    @Test("discovers skills by SKILL.md presence")
    func discoverSkills() throws {
        let dir = try makeTempSkillsDir(skills: [
            ("alpha", "---\nname: A\ndescription: Alpha skill\n---\n# Alpha"),
            ("beta", "---\nname: B\ndescription: Beta skill\n---\n# Beta"),
        ])
        defer { cleanup(dir) }

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        #expect(results.count == 2)
        #expect(results[0].directory == "alpha")
        #expect(results[1].directory == "beta")
    }

    @Test("skips directories without SKILL.md")
    func skipNonSkillDirs() throws {
        let dir = try makeTempSkillsDir(skills: [
            ("has-skill", "---\nname: X\ndescription: test\n---\n"),
            ("no-skill", nil),
        ])
        defer { cleanup(dir) }

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        #expect(results.count == 1)
        #expect(results[0].directory == "has-skill")
    }

    @Test("returns sorted results by directory name")
    func sortedResults() throws {
        let dir = try makeTempSkillsDir(skills: [
            ("zebra", "---\nname: Z\ndescription: test\n---\n"),
            ("apple", "---\nname: A\ndescription: test\n---\n"),
        ])
        defer { cleanup(dir) }

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        #expect(results[0].directory == "apple")
        #expect(results[1].directory == "zebra")
    }

    // MARK: - Missing frontmatter

    @Test("warns on missing frontmatter in default mode")
    func warnMissingFrontmatter() throws {
        let dir = try makeTempSkillsDir(skills: [
            ("bare", "# Just a heading\nNo frontmatter here."),
        ])
        defer { cleanup(dir) }

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        #expect(results.count == 1)
        #expect(results[0].hasFrontmatter == false)
        #expect(results[0].diagnostics.count == 1)
        #expect(results[0].diagnostics[0].severity == .warning)
    }

    @Test("errors on missing frontmatter in strict mode")
    func errorMissingFrontmatterStrict() throws {
        let dir = try makeTempSkillsDir(skills: [
            ("bare", "# No frontmatter"),
        ])
        defer { cleanup(dir) }

        let results = try scanner.scan(skillsDirectory: dir, strict: true)
        #expect(results[0].diagnostics[0].severity == .error)
    }

    // MARK: - Validation integration

    @Test("valid frontmatter produces zero diagnostics")
    func validFrontmatter() throws {
        let content = """
        ---
        name: Good Skill
        description: A good skill
        ---
        # Good Skill
        """
        let dir = try makeTempSkillsDir(skills: [("good-skill", content)])
        defer { cleanup(dir) }

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        let errors = results[0].diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    @Test("invalid frontmatter surfaces validation errors")
    func invalidFrontmatter() throws {
        let content = """
        ---
        name: Bad
        type: unknown_type
        ---
        """
        let dir = try makeTempSkillsDir(skills: [("bad", content)])
        defer { cleanup(dir) }

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        #expect(!results[0].diagnostics.isEmpty)
        #expect(results[0].diagnostics.contains { $0.message.contains("'description'") && $0.severity == .error })
        #expect(results[0].diagnostics.contains { $0.message.contains("invalid 'type'") && $0.severity == .error })
    }

    @Test("malformed YAML reports parse error")
    func malformedYAML() throws {
        let content = "---\n: [invalid yaml\n---\n"
        let dir = try makeTempSkillsDir(skills: [("broken", content)])
        defer { cleanup(dir) }

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        #expect(results[0].diagnostics.count == 1)
        #expect(results[0].diagnostics[0].severity == .error)
        #expect(results[0].diagnostics[0].message.contains("parse") || results[0].diagnostics[0].message.contains("YAML"))
    }

    // MARK: - examples.json validation

    @Test("valid examples.json produces no extra diagnostics")
    func validExamplesJSON() throws {
        let content = "---\nname: X\ndescription: test\n---\n"
        let dir = try makeTempSkillsDir(skills: [("ex-skill", content)])
        defer { cleanup(dir) }

        let refsDir = (dir as NSString).appendingPathComponent("ex-skill/references")
        try FileManager.default.createDirectory(atPath: refsDir, withIntermediateDirectories: true)
        let json = """
        [{"intent":"test","command":"x","output_format":"json","example_output":{},"exit_code":0}]
        """
        try json.write(toFile: (refsDir as NSString).appendingPathComponent("examples.json"), atomically: true, encoding: .utf8)

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        let errors = results[0].diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    @Test("invalid examples.json surfaces errors")
    func invalidExamplesJSON() throws {
        let content = "---\nname: X\ndescription: test\n---\n"
        let dir = try makeTempSkillsDir(skills: [("bad-ex", content)])
        defer { cleanup(dir) }

        let refsDir = (dir as NSString).appendingPathComponent("bad-ex/references")
        try FileManager.default.createDirectory(atPath: refsDir, withIntermediateDirectories: true)
        try "not json".write(toFile: (refsDir as NSString).appendingPathComponent("examples.json"), atomically: true, encoding: .utf8)

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        #expect(results[0].diagnostics.contains { $0.message.contains("examples.json") })
    }

    @Test("missing examples.json is fine")
    func missingExamplesJSON() throws {
        let content = "---\nname: X\ndescription: test\n---\n"
        let dir = try makeTempSkillsDir(skills: [("no-ex", content)])
        defer { cleanup(dir) }

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        let errors = results[0].diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    // MARK: - commands.json validation

    @Test("valid commands.json produces no extra errors")
    func validCommandsJSON() throws {
        let content = "---\nname: X\ndescription: test\n---\n"
        let dir = try makeTempSkillsDir(skills: [("cmd-skill", content)])
        defer { cleanup(dir) }

        let refsDir = (dir as NSString).appendingPathComponent("cmd-skill/references")
        try FileManager.default.createDirectory(atPath: refsDir, withIntermediateDirectories: true)
        let json = """
        {"skill":"cmd-skill","commands":[{"name":"run","binary":"x","description":"do thing","output_format":"json","examples":[{"intent":"x","command":"x run","output_format":"json","example_output":{},"exit_code":0}]}]}
        """
        try json.write(toFile: (refsDir as NSString).appendingPathComponent("commands.json"), atomically: true, encoding: .utf8)

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        let errors = results[0].diagnostics.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    @Test("invalid commands.json surfaces errors")
    func invalidCommandsJSON() throws {
        let content = "---\nname: X\ndescription: test\n---\n"
        let dir = try makeTempSkillsDir(skills: [("bad-cmd", content)])
        defer { cleanup(dir) }

        let refsDir = (dir as NSString).appendingPathComponent("bad-cmd/references")
        try FileManager.default.createDirectory(atPath: refsDir, withIntermediateDirectories: true)
        try "not json".write(toFile: (refsDir as NSString).appendingPathComponent("commands.json"), atomically: true, encoding: .utf8)

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        #expect(results[0].diagnostics.contains { $0.message.contains("commands.json") && $0.severity == .error })
    }

    @Test("commands.json takes precedence over examples.json")
    func commandsPrecedence() throws {
        let content = "---\nname: X\ndescription: test\n---\n"
        let dir = try makeTempSkillsDir(skills: [("both", content)])
        defer { cleanup(dir) }

        let refsDir = (dir as NSString).appendingPathComponent("both/references")
        try FileManager.default.createDirectory(atPath: refsDir, withIntermediateDirectories: true)
        let commandsJson = """
        {"skill":"both","commands":[{"name":"run","binary":"x","description":"do thing","output_format":"json","examples":[{"intent":"x","command":"x run","output_format":"json","example_output":{},"exit_code":0}]}]}
        """
        try commandsJson.write(toFile: (refsDir as NSString).appendingPathComponent("commands.json"), atomically: true, encoding: .utf8)
        try "[]".write(toFile: (refsDir as NSString).appendingPathComponent("examples.json"), atomically: true, encoding: .utf8)

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        #expect(results[0].diagnostics.contains { $0.message.contains("both commands.json and examples.json") && $0.severity == .warning })
        // Should NOT have examples.json errors since commands.json takes precedence
        #expect(!results[0].diagnostics.contains { $0.message.contains("examples.json: array must not be empty") })
    }

    @Test("capability cross-validation warns on unknown capability")
    func capabilityCrossValidation() throws {
        let content = """
        ---
        name: X
        description: test
        capabilities:
          - id: read
            description: Read data
            destructive: false
        ---
        """
        let dir = try makeTempSkillsDir(skills: [("cap-skill", content)])
        defer { cleanup(dir) }

        let refsDir = (dir as NSString).appendingPathComponent("cap-skill/references")
        try FileManager.default.createDirectory(atPath: refsDir, withIntermediateDirectories: true)
        let json = """
        {"skill":"cap-skill","commands":[{"name":"run","binary":"x","description":"do thing","output_format":"json","capability":"write","examples":[{"intent":"x","command":"x run","output_format":"json","example_output":{},"exit_code":0}]}]}
        """
        try json.write(toFile: (refsDir as NSString).appendingPathComponent("commands.json"), atomically: true, encoding: .utf8)

        let results = try scanner.scan(skillsDirectory: dir, strict: false)
        #expect(results[0].diagnostics.contains { $0.message.contains("capability 'write' not found in frontmatter") && $0.severity == .warning })
    }

    // MARK: - Error handling

    @Test("throws on nonexistent directory")
    func nonexistentDirectory() throws {
        #expect(throws: ScanError.self) {
            _ = try scanner.scan(skillsDirectory: "/nonexistent/path", strict: false)
        }
    }
}
