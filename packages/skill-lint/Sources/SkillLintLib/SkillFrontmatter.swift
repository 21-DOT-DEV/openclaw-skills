/// A structured capability group declared by a skill.
public struct Capability: Sendable {
    public let id: String?
    public let description: String?
    public let destructive: Bool?
    public let requiresConfirmation: Bool?

    public init(id: String?, description: String?, destructive: Bool?, requiresConfirmation: Bool?) {
        self.id = id
        self.description = description
        self.destructive = destructive
        self.requiresConfirmation = requiresConfirmation
    }
}

/// Parsed YAML frontmatter from a SKILL.md file.
public struct SkillFrontmatter: Sendable {
    public let name: String?
    public let slug: String?
    public let type: String?
    public let requiresBinaries: [String]?
    public let supportedOS: [String]?
    public let install: [String: String]?
    public let verify: [String]?
    public let securityNotes: SecurityNotes?
    public let capabilities: [Capability]?
    public let riskLevel: String?
    public let verifyInstall: [String]?
    public let verifyReady: [String]?
    public let outputFormat: String?
    public let outputParsing: [String: String]?

    /// Security notes can be a single string or a list of strings.
    public enum SecurityNotes: Sendable {
        case single(String)
        case list([String])
    }

    public init(
        name: String?,
        slug: String?,
        type: String?,
        requiresBinaries: [String]?,
        supportedOS: [String]?,
        install: [String: String]?,
        verify: [String]?,
        securityNotes: SecurityNotes?,
        capabilities: [Capability]? = nil,
        riskLevel: String? = nil,
        verifyInstall: [String]? = nil,
        verifyReady: [String]? = nil,
        outputFormat: String? = nil,
        outputParsing: [String: String]? = nil
    ) {
        self.name = name
        self.slug = slug
        self.type = type
        self.requiresBinaries = requiresBinaries
        self.supportedOS = supportedOS
        self.install = install
        self.verify = verify
        self.securityNotes = securityNotes
        self.capabilities = capabilities
        self.riskLevel = riskLevel
        self.verifyInstall = verifyInstall
        self.verifyReady = verifyReady
        self.outputFormat = outputFormat
        self.outputParsing = outputParsing
    }
}
