import Foundation
import Yams

/// Extracts and parses YAML frontmatter from a SKILL.md file.
public struct FrontmatterParser: Sendable {

    public init() {}

    /// Extract raw YAML string between `---` delimiters at the top of the file.
    /// Returns `nil` if no frontmatter is found.
    public func extractRawFrontmatter(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)
        guard let first = lines.first, first.trimmingCharacters(in: .whitespaces) == "---" else {
            return nil
        }
        var yamlLines: [String] = []
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces) == "---" {
                return yamlLines.joined(separator: "\n")
            }
            yamlLines.append(line)
        }
        return nil
    }

    /// Parse YAML frontmatter string into a `SkillFrontmatter`.
    public func parse(yaml: String) throws -> SkillFrontmatter {
        guard let node = try Yams.compose(yaml: yaml), let mapping = node.mapping else {
            throw FrontmatterError.invalidYAML
        }

        let name = mapping["name"]?.string
        let slug = mapping["slug"]?.string
        let type = mapping["type"]?.string

        let requiresBinaries: [String]? = mapping["requires_binaries"]?.sequence?.compactMap { $0.string }
        let supportedOS: [String]? = mapping["supported_os"]?.sequence?.compactMap { $0.string }
        let verify: [String]? = mapping["verify"]?.sequence?.compactMap { $0.string }

        let install: [String: String]?
        if let installMapping = mapping["install"]?.mapping {
            var dict: [String: String] = [:]
            for pair in installMapping {
                if let key = pair.key.string, let value = pair.value.string {
                    dict[key] = value
                }
            }
            install = dict.isEmpty ? nil : dict
        } else {
            install = nil
        }

        let securityNotes: SkillFrontmatter.SecurityNotes?
        if let secNode = mapping["security_notes"] {
            if let str = secNode.string {
                securityNotes = .single(str)
            } else if let seq = secNode.sequence {
                securityNotes = .list(seq.compactMap { $0.string })
            } else {
                securityNotes = nil
            }
        } else {
            securityNotes = nil
        }

        let capabilities: [Capability]?
        if let capSeq = mapping["capabilities"]?.sequence {
            capabilities = capSeq.map { node in
                Capability(
                    id: node.mapping?["id"]?.string,
                    description: node.mapping?["description"]?.string,
                    destructive: node.mapping?["destructive"]?.bool,
                    requiresConfirmation: node.mapping?["requires_confirmation"]?.bool
                )
            }
        } else {
            capabilities = nil
        }

        let riskLevel = mapping["risk_level"]?.string
        let verifyInstall: [String]? = mapping["verify_install"]?.sequence?.compactMap { $0.string }
        let verifyReady: [String]? = mapping["verify_ready"]?.sequence?.compactMap { $0.string }
        let outputFormat = mapping["output_format"]?.string

        let outputParsing: [String: String]?
        if let opMapping = mapping["output_parsing"]?.mapping {
            var dict: [String: String] = [:]
            for pair in opMapping {
                if let key = pair.key.string, let value = pair.value.string {
                    dict[key] = value
                }
            }
            outputParsing = dict.isEmpty ? nil : dict
        } else {
            outputParsing = nil
        }

        return SkillFrontmatter(
            name: name,
            slug: slug,
            type: type,
            requiresBinaries: requiresBinaries,
            supportedOS: supportedOS,
            install: install,
            verify: verify,
            securityNotes: securityNotes,
            capabilities: capabilities,
            riskLevel: riskLevel,
            verifyInstall: verifyInstall,
            verifyReady: verifyReady,
            outputFormat: outputFormat,
            outputParsing: outputParsing
        )
    }
}

/// Errors from frontmatter parsing.
public enum FrontmatterError: Error, CustomStringConvertible {
    case invalidYAML

    public var description: String {
        switch self {
        case .invalidYAML:
            return "Could not parse YAML frontmatter"
        }
    }
}
