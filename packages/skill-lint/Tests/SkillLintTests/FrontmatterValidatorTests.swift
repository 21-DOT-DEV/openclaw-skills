import Testing
@testable import SkillLintLib

@Suite("FrontmatterValidator Tests")
struct FrontmatterValidatorTests {
    let validator = FrontmatterValidator()

    @Test("valid frontmatter produces no diagnostics")
    func validFrontmatter() {
        let fm = SkillFrontmatter(
            name: "Test Skill",
            description: "A test skill",
            slug: "test-skill",
            type: "external_cli",
            requiresBinaries: ["mycli"],
            supportedOS: ["macos", "linux"],
            install: ["macos": "brew install mycli"],
            verify: ["mycli --version"],
            securityNotes: .single("Keep tokens safe")
        )
        let diags = validator.validate(frontmatter: fm, skill: "test-skill")
        #expect(diags.isEmpty)
    }

    @Test("missing name produces error")
    func missingName() {
        let fm = SkillFrontmatter(
            name: nil, slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x --help"], securityNotes: nil
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("'name'") && $0.severity == .error })
    }

    @Test("missing slug produces no warning")
    func missingSlug() {
        let fm = SkillFrontmatter(
            name: "N", description: "test", slug: nil, type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x --help"], securityNotes: nil
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(!diags.contains { $0.message.contains("'slug'") })
    }

    @Test("invalid type produces error")
    func invalidType() {
        let fm = SkillFrontmatter(
            name: "N", slug: "s", type: "python_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x --help"], securityNotes: nil
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("invalid 'type'") && $0.severity == .error })
    }

    @Test("empty requires_binaries produces error")
    func emptyBinaries() {
        let fm = SkillFrontmatter(
            name: "N", slug: "s", type: "swift_cli",
            requiresBinaries: [], supportedOS: ["macos"],
            install: nil, verify: ["x --help"], securityNotes: nil
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("'requires_binaries'") && $0.severity == .error })
    }

    @Test("invalid supported_os value produces error")
    func invalidOS() {
        let fm = SkillFrontmatter(
            name: "N", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["android"],
            install: nil, verify: ["x --help"], securityNotes: nil
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("invalid 'supported_os'") && $0.severity == .error })
    }

    @Test("missing verify produces no warning")
    func missingVerify() {
        let fm = SkillFrontmatter(
            name: "N", description: "test", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: nil, securityNotes: nil
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(!diags.contains { $0.message.contains("'verify'") })
    }

    @Test("all fields missing produces only required-key errors")
    func allMissing() {
        let fm = SkillFrontmatter(
            name: nil, slug: nil, type: nil,
            requiresBinaries: nil, supportedOS: nil,
            install: nil, verify: nil, securityNotes: nil
        )
        let diags = validator.validate(frontmatter: fm, skill: "empty")
        #expect(diags.count == 2)
        let errors = diags.filter { $0.severity == .error }
        let warnings = diags.filter { $0.severity == .warning }
        #expect(errors.count == 2)
        #expect(warnings.count == 0)
        #expect(errors.contains { $0.message.contains("'name'") })
        #expect(errors.contains { $0.message.contains("'description'") })
    }

    @Test("missing description produces error")
    func missingDescription() {
        let fm = SkillFrontmatter(
            name: "N", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x --help"], securityNotes: nil
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("'description'") && $0.severity == .error })
    }

    @Test("empty description produces error")
    func emptyDescription() {
        let fm = SkillFrontmatter(
            name: "N", description: "  ", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x --help"], securityNotes: nil
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("'description' must not be empty") && $0.severity == .error })
    }

    @Test("minimal frontmatter produces zero diagnostics")
    func minimalFrontmatter() {
        let fm = SkillFrontmatter(
            name: "N", description: "A skill", slug: nil, type: nil,
            requiresBinaries: nil, supportedOS: nil,
            install: nil, verify: nil, securityNotes: nil
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.isEmpty)
    }

    // MARK: - New fields

    @Test("valid capabilities produce no diagnostics")
    func validCapabilities() {
        let fm = SkillFrontmatter(
            name: "N", description: "test", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x -v"], securityNotes: nil,
            capabilities: [
                Capability(id: "query", description: "Read", destructive: false, requiresConfirmation: nil),
                Capability(id: "create", description: "Write", destructive: true, requiresConfirmation: true),
            ]
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.isEmpty)
    }

    @Test("capability missing id produces error")
    func capabilityMissingID() {
        let fm = SkillFrontmatter(
            name: "N", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x -v"], securityNotes: nil,
            capabilities: [
                Capability(id: nil, description: "Read", destructive: false, requiresConfirmation: nil),
            ]
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("missing required key 'id'") })
    }

    @Test("duplicate capability id produces error")
    func duplicateCapabilityID() {
        let fm = SkillFrontmatter(
            name: "N", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x -v"], securityNotes: nil,
            capabilities: [
                Capability(id: "query", description: "A", destructive: false, requiresConfirmation: nil),
                Capability(id: "query", description: "B", destructive: false, requiresConfirmation: nil),
            ]
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("duplicate capability id") })
    }

    @Test("empty capabilities list produces error")
    func emptyCapabilities() {
        let fm = SkillFrontmatter(
            name: "N", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x -v"], securityNotes: nil,
            capabilities: []
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("'capabilities' must not be empty") })
    }

    @Test("valid risk_level passes")
    func validRiskLevel() {
        let fm = SkillFrontmatter(
            name: "N", description: "test", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x -v"], securityNotes: nil,
            riskLevel: "high"
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.isEmpty)
    }

    @Test("invalid risk_level produces error")
    func invalidRiskLevel() {
        let fm = SkillFrontmatter(
            name: "N", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x -v"], securityNotes: nil,
            riskLevel: "extreme"
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("invalid 'risk_level'") })
    }

    @Test("empty verify_install produces error")
    func emptyVerifyInstall() {
        let fm = SkillFrontmatter(
            name: "N", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x -v"], securityNotes: nil,
            verifyInstall: []
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("'verify_install' must not be empty") })
    }

    @Test("invalid output_format produces error")
    func invalidOutputFormat() {
        let fm = SkillFrontmatter(
            name: "N", slug: "s", type: "swift_cli",
            requiresBinaries: ["x"], supportedOS: ["macos"],
            install: nil, verify: ["x -v"], securityNotes: nil,
            outputFormat: "xml"
        )
        let diags = validator.validate(frontmatter: fm, skill: "s")
        #expect(diags.contains { $0.message.contains("invalid 'output_format'") })
    }
}
