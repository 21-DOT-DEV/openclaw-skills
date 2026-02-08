import Testing
import Foundation
@testable import SkillLintLib

@Suite("ExamplesValidator Tests")
struct ExamplesValidatorTests {
    let validator = ExamplesValidator()

    private func jsonData(_ string: String) -> Data {
        string.data(using: .utf8)!
    }

    @Test("valid examples produce no diagnostics")
    func validExamples() {
        let json = """
        [
          {
            "intent": "Find tasks",
            "command": "ntask list",
            "output_format": "json",
            "example_output": {"ok": true},
            "exit_code": 0
          }
        ]
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.isEmpty)
    }

    @Test("missing required key produces error")
    func missingKey() {
        let json = """
        [
          {
            "intent": "Find tasks",
            "command": "ntask list",
            "output_format": "json",
            "exit_code": 0
          }
        ]
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("'example_output'") })
    }

    @Test("invalid output_format in example produces error")
    func invalidFormat() {
        let json = """
        [
          {
            "intent": "Test",
            "command": "test",
            "output_format": "xml",
            "example_output": "ok",
            "exit_code": 0
          }
        ]
        """
        let diags = validator.validate(data: jsonData(json), skill: "test")
        #expect(diags.contains { $0.message.contains("invalid 'output_format'") })
    }

    @Test("invalid JSON produces parse error")
    func invalidJSON() {
        let diags = validator.validate(data: jsonData("not json"), skill: "test")
        #expect(diags.count == 1)
        #expect(diags[0].message.contains("failed to parse JSON"))
    }

    @Test("empty array produces error")
    func emptyArray() {
        let diags = validator.validate(data: jsonData("[]"), skill: "test")
        #expect(diags.contains { $0.message.contains("must not be empty") })
    }

    @Test("non-array JSON produces error")
    func nonArray() {
        let diags = validator.validate(data: jsonData("{}"), skill: "test")
        #expect(diags.contains { $0.message.contains("expected a JSON array") })
    }
}
