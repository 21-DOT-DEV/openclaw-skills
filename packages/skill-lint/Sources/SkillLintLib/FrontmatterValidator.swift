import Foundation

/// Validates a parsed `SkillFrontmatter` against the required schema.
public struct FrontmatterValidator: Sendable {

    public init() {}

    /// Allowed values for the `type` field.
    public static let allowedTypes: Set<String> = ["swift_cli", "external_cli"]

    /// Allowed values for `supported_os` entries.
    public static let allowedOS: Set<String> = ["macos", "linux", "windows"]

    /// Allowed values for the `risk_level` field.
    public static let allowedRiskLevels: Set<String> = ["low", "medium", "high", "critical"]

    /// Allowed values for the `output_format` field.
    public static let allowedOutputFormats: Set<String> = ["json", "line_based", "table", "freeform"]

    /// Validate frontmatter and return diagnostics.
    public func validate(frontmatter: SkillFrontmatter, skill: String) -> [LintDiagnostic] {
        var diagnostics: [LintDiagnostic] = []

        // name: required, non-empty string
        if let name = frontmatter.name {
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(.init(skill: skill, severity: .error, message: "'name' must not be empty"))
            }
        } else {
            diagnostics.append(.init(skill: skill, severity: .error, message: "missing required key 'name'"))
        }

        // description: required, non-empty string
        if let desc = frontmatter.description {
            if desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(.init(skill: skill, severity: .error, message: "'description' must not be empty"))
            }
        } else {
            diagnostics.append(.init(skill: skill, severity: .error, message: "missing required key 'description'"))
        }

        // slug: optional (warning if missing, error if empty)
        if let slug = frontmatter.slug {
            if slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                diagnostics.append(.init(skill: skill, severity: .error, message: "'slug' must not be empty"))
            }
        } else {
            diagnostics.append(.init(skill: skill, severity: .warning, message: "missing optional key 'slug'"))
        }

        // type: optional (warning if missing, error if invalid value)
        if let type = frontmatter.type {
            if !Self.allowedTypes.contains(type) {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "invalid 'type' value '\(type)' (allowed: \(Self.allowedTypes.sorted().joined(separator: ", ")))"
                ))
            }
        } else {
            diagnostics.append(.init(skill: skill, severity: .warning, message: "missing optional key 'type'"))
        }

        // requires_binaries: optional (warning if missing, error if empty)
        if let bins = frontmatter.requiresBinaries {
            if bins.isEmpty {
                diagnostics.append(.init(skill: skill, severity: .error, message: "'requires_binaries' must not be empty"))
            }
        } else {
            diagnostics.append(.init(skill: skill, severity: .warning, message: "missing optional key 'requires_binaries'"))
        }

        // supported_os: optional (warning if missing, error if invalid values)
        if let osList = frontmatter.supportedOS {
            if osList.isEmpty {
                diagnostics.append(.init(skill: skill, severity: .error, message: "'supported_os' must not be empty"))
            } else {
                for os in osList {
                    if !Self.allowedOS.contains(os) {
                        diagnostics.append(.init(
                            skill: skill, severity: .error,
                            message: "invalid 'supported_os' value '\(os)' (allowed: \(Self.allowedOS.sorted().joined(separator: ", ")))"
                        ))
                    }
                }
            }
        } else {
            diagnostics.append(.init(skill: skill, severity: .warning, message: "missing optional key 'supported_os'"))
        }

        // verify: optional (warning if missing, error if empty)
        if let verifyList = frontmatter.verify {
            if verifyList.isEmpty {
                diagnostics.append(.init(skill: skill, severity: .error, message: "'verify' must not be empty"))
            }
        } else {
            diagnostics.append(.init(skill: skill, severity: .warning, message: "missing optional key 'verify'"))
        }

        // install: optional, but if present must be a valid map
        // (structural validation is handled by parser; no extra checks needed)

        // security_notes: optional, no further validation needed

        // capabilities: optional, but if present must be non-empty with valid entries
        if let caps = frontmatter.capabilities {
            if caps.isEmpty {
                diagnostics.append(.init(skill: skill, severity: .error, message: "'capabilities' must not be empty if present"))
            } else {
                var seenIDs: Set<String> = []
                for (index, cap) in caps.enumerated() {
                    if let id = cap.id {
                        if !seenIDs.insert(id).inserted {
                            diagnostics.append(.init(skill: skill, severity: .error, message: "duplicate capability id '\(id)'"))
                        }
                    } else {
                        diagnostics.append(.init(skill: skill, severity: .error, message: "capability[\(index)] missing required key 'id'"))
                    }
                    if cap.description == nil {
                        diagnostics.append(.init(skill: skill, severity: .error, message: "capability '\(cap.id ?? "[\(index)]")' missing required key 'description'"))
                    }
                    if cap.destructive == nil {
                        diagnostics.append(.init(skill: skill, severity: .error, message: "capability '\(cap.id ?? "[\(index)]")' missing required key 'destructive'"))
                    }
                }
            }
        }

        // risk_level: optional, must be one of allowed values
        if let risk = frontmatter.riskLevel {
            if !Self.allowedRiskLevels.contains(risk) {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "invalid 'risk_level' value '\(risk)' (allowed: \(Self.allowedRiskLevels.sorted().joined(separator: ", ")))"
                ))
            }
        }

        // verify_install: optional, but if present must be non-empty
        if let vi = frontmatter.verifyInstall {
            if vi.isEmpty {
                diagnostics.append(.init(skill: skill, severity: .error, message: "'verify_install' must not be empty if present"))
            }
        }

        // verify_ready: optional, but if present must be non-empty
        if let vr = frontmatter.verifyReady {
            if vr.isEmpty {
                diagnostics.append(.init(skill: skill, severity: .error, message: "'verify_ready' must not be empty if present"))
            }
        }

        // output_format: optional, must be one of allowed values
        if let fmt = frontmatter.outputFormat {
            if !Self.allowedOutputFormats.contains(fmt) {
                diagnostics.append(.init(
                    skill: skill, severity: .error,
                    message: "invalid 'output_format' value '\(fmt)' (allowed: \(Self.allowedOutputFormats.sorted().joined(separator: ", ")))"
                ))
            }
        }

        return diagnostics
    }
}
