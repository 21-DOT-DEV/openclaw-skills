import Testing
@testable import SkillLintLib

@Suite("FrontmatterParser Tests")
struct FrontmatterParserTests {
    let parser = FrontmatterParser()

    @Test("extracts raw YAML between --- delimiters")
    func extractValidFrontmatter() {
        let content = """
        ---
        name: test-skill
        type: swift_cli
        ---

        # Body content
        """
        let yaml = parser.extractRawFrontmatter(from: content)
        #expect(yaml != nil)
        #expect(yaml!.contains("name: test-skill"))
        #expect(yaml!.contains("type: swift_cli"))
    }

    @Test("returns nil when no frontmatter delimiters")
    func noFrontmatter() {
        let content = "# Just a heading\nSome body text."
        #expect(parser.extractRawFrontmatter(from: content) == nil)
    }

    @Test("returns nil when only opening delimiter")
    func unclosedFrontmatter() {
        let content = "---\nname: test\nno closing delimiter"
        #expect(parser.extractRawFrontmatter(from: content) == nil)
    }

    @Test("parses all required fields")
    func parseRequiredFields() throws {
        let yaml = """
        name: My Skill
        slug: my-skill
        type: external_cli
        requires_binaries:
          - mycli
        supported_os:
          - macos
          - linux
        verify:
          - "mycli --version"
        """
        let fm = try parser.parse(yaml: yaml)
        #expect(fm.name == "My Skill")
        #expect(fm.slug == "my-skill")
        #expect(fm.type == "external_cli")
        #expect(fm.requiresBinaries == ["mycli"])
        #expect(fm.supportedOS == ["macos", "linux"])
        #expect(fm.verify == ["mycli --version"])
    }

    @Test("parses install map")
    func parseInstallMap() throws {
        let yaml = """
        name: test
        slug: test
        type: swift_cli
        requires_binaries:
          - test
        supported_os:
          - macos
        verify:
          - "test --version"
        install:
          macos: "brew install test"
          linux: "apt install test"
        """
        let fm = try parser.parse(yaml: yaml)
        #expect(fm.install?["macos"] == "brew install test")
        #expect(fm.install?["linux"] == "apt install test")
    }

    @Test("parses security_notes as string")
    func parseSecurityNotesString() throws {
        let yaml = """
        name: test
        slug: test
        type: swift_cli
        requires_binaries:
          - test
        supported_os:
          - macos
        verify:
          - "test --version"
        security_notes: "Keep tokens secret"
        """
        let fm = try parser.parse(yaml: yaml)
        if case .single(let note) = fm.securityNotes {
            #expect(note == "Keep tokens secret")
        } else {
            Issue.record("Expected single security note")
        }
    }

    @Test("parses security_notes as list")
    func parseSecurityNotesList() throws {
        let yaml = """
        name: test
        slug: test
        type: swift_cli
        requires_binaries:
          - test
        supported_os:
          - macos
        verify:
          - "test --version"
        security_notes:
          - "Note one"
          - "Note two"
        """
        let fm = try parser.parse(yaml: yaml)
        if case .list(let notes) = fm.securityNotes {
            #expect(notes == ["Note one", "Note two"])
        } else {
            Issue.record("Expected list of security notes")
        }
    }

    @Test("parses capabilities list")
    func parseCapabilities() throws {
        let yaml = """
        name: test
        slug: test
        type: swift_cli
        requires_binaries:
          - test
        supported_os:
          - macos
        verify:
          - "test -v"
        capabilities:
          - id: query
            description: "Read data"
            destructive: false
          - id: create
            description: "Create items"
            destructive: true
            requires_confirmation: true
        """
        let fm = try parser.parse(yaml: yaml)
        #expect(fm.capabilities?.count == 2)
        #expect(fm.capabilities?[0].id == "query")
        #expect(fm.capabilities?[0].destructive == false)
        #expect(fm.capabilities?[1].id == "create")
        #expect(fm.capabilities?[1].requiresConfirmation == true)
    }

    @Test("parses risk_level")
    func parseRiskLevel() throws {
        let yaml = """
        name: test
        slug: test
        type: swift_cli
        requires_binaries:
          - test
        supported_os:
          - macos
        verify:
          - "test -v"
        risk_level: high
        """
        let fm = try parser.parse(yaml: yaml)
        #expect(fm.riskLevel == "high")
    }

    @Test("parses verify_install and verify_ready")
    func parseVerifyTwoTier() throws {
        let yaml = """
        name: test
        slug: test
        type: swift_cli
        requires_binaries:
          - test
        supported_os:
          - macos
        verify:
          - "test -v"
        verify_install:
          - "test --version"
        verify_ready:
          - "test doctor"
        """
        let fm = try parser.parse(yaml: yaml)
        #expect(fm.verifyInstall == ["test --version"])
        #expect(fm.verifyReady == ["test doctor"])
    }

    @Test("parses output_format")
    func parseOutputFormat() throws {
        let yaml = """
        name: test
        slug: test
        type: swift_cli
        requires_binaries:
          - test
        supported_os:
          - macos
        verify:
          - "test -v"
        output_format: json
        """
        let fm = try parser.parse(yaml: yaml)
        #expect(fm.outputFormat == "json")
    }

    @Test("parses output_parsing map")
    func parseOutputParsing() throws {
        let yaml = """
        name: test
        slug: test
        type: swift_cli
        requires_binaries:
          - test
        supported_os:
          - macos
        verify:
          - "test -v"
        output_parsing:
          success_json_path: ".ok"
          error_json_path: ".error.message"
        """
        let fm = try parser.parse(yaml: yaml)
        #expect(fm.outputParsing?["success_json_path"] == ".ok")
        #expect(fm.outputParsing?["error_json_path"] == ".error.message")
    }

    @Test("nil for absent new fields")
    func absentNewFields() throws {
        let yaml = """
        name: test
        slug: test
        type: swift_cli
        requires_binaries:
          - test
        supported_os:
          - macos
        verify:
          - "test -v"
        """
        let fm = try parser.parse(yaml: yaml)
        #expect(fm.capabilities == nil)
        #expect(fm.riskLevel == nil)
        #expect(fm.verifyInstall == nil)
        #expect(fm.verifyReady == nil)
        #expect(fm.outputFormat == nil)
        #expect(fm.outputParsing == nil)
    }
}
