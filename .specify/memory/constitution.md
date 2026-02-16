<!--
Sync Impact Report - Constitution v2.1.0
===============================================================================
Version Change: 2.0.0 -> 2.1.0 (Minor revision — materially expanded guidance)

Summary:
  Feedback-driven patch to v2.0.0. Added idempotency practices, skill
  API versioning, enforcement matrix (hybrid inline + governance table),
  error code taxonomy, rate limiting, audit logging, execution timeouts.
  Concrete deprecation timeline. Wording fixes for deps and credentials.
  Research-informed by MCP spec, Kubernetes deprecation policy, Terraform
  backward compatibility, Homebrew acceptable formulae.

Core Principles (7 — unchanged):
  I. Scope & Mission Boundaries
  II. Spec-First & Test-Driven Development
  III. JSON-Only Output Contract
  IV. Security by Layers
  V. Skill Portability, Discovery & Architecture
  VI. Deterministic Agent Behavior
  VII. CI, Quality Gates & Living Documentation

v2.1.0 Changes:
  - Item 1: Added idempotency practices to Principle VI (SHOULD)
  - Item 2: Added version field to SKILL.md frontmatter (MUST)
  - Item 3: Hybrid enforcement — per-principle inline + governance matrix
  - Item 5: Fixed deps wording in Principle I (swift-system added)
  - Item 6: Concrete deprecation timeline (>=3 releases / 6 months)
  - Item 7: Added health check pattern to Principle V (SHOULD)
  - Item 9: Reworded keychain to "OS-provided secret storage"
  - Item 10: Added error code taxonomy to Principle III (SHOULD)
  - G1: Added rate limiting practices to Principle VI (SHOULD)
  - G2: Added audit logging practices to Principle VII (SHOULD)
  - G3: Added execution timeout practices to Principle VI (SHOULD)
  Skipped: #4 (out of scope), #8 (already handled by MUST/SHOULD/MAY)

Enforcement: Three-tier model (MUST/SHOULD/MAY) with explicit MUST NOT
  Now with hybrid enforcement: per-principle inline + governance matrix
Governance: BDFL model with contract-change and security-change protocols

Template Alignment Status:
  N/A — Templates directory empty; no alignment needed

Deferred to v2.2 Roadmap (7 items):
  R1: Security Disclosure Protocol (OWASP-style)
  R2: Observability & Exit Code Ranges
  R3: Contract Breaking Definition (breaking vs non-breaking)
  R4: Test Coverage Minimum (snapshot testing)
  R5: Threat Model & Privilege Boundaries
  R6: Skill Maintenance & Sunset
  R7: Dependency Update Policy
===============================================================================
-->

# OpenClaw Skills Constitution

## Preamble

This constitution governs the **openclaw-skills** monorepo. It defines
the principles, practices, and quality standards for all development of
agent skills and their backing packages.

**Scope**: This repository only. Covers skill definitions (`skills/`),
backing Swift packages (`packages/`), the `skill-lint` tooling, and
build orchestration (`Makefile`). Does NOT govern the OpenClaw runtime,
workspace operator, or downstream consumers of installed skills.

**Philosophy**: Strict contracts and deterministic behavior take
precedence over feature breadth. Each skill is a sharp, focused
tool — narrow entry point, deep domain coverage — designed for agents
that parse output programmatically, not humans reading screens.
Principles are technology-agnostic where possible. Current technology
choices (Swift 6.1, SwiftPM, swift-argument-parser) are documented in
Package.swift and README.md to enable future migrations without
constitutional amendments.

---

## Core Principles

### I. Scope & Mission Boundaries

**Statement**: The repository MUST focus exclusively on agent skill
definitions and their backing packages. Skills bridge AI agents to
external systems via CLI tools with structured output contracts.

**Rationale**: Keeping scope tight prevents the repository from
absorbing runtime concerns, orchestration logic, or agent
decision-making. Clear boundaries reduce complexity and ensure every
artifact serves the single mission: give agents reliable, discoverable
tools.

**Practices**:
- **MUST** limit scope to skill definitions (`skills/`), backing
  Swift packages (`packages/`), skill linting tooling, and build
  orchestration
- **MUST** support two skill types: `swift_cli` (compiled binary)
  and `external_cli` (docs-only, no build)
- **MUST** maintain zero third-party runtime dependencies beyond
  Apple/Swift ecosystem packages (swift-argument-parser,
  swift-subprocess, swift-system)
- **MUST NOT** include agent runtime, orchestration, or
  decision-making logic
- **MUST NOT** include workspace operator or installation management
  beyond `make install`
- **MUST NOT** add dependencies without constitutional review and
  explicit justification
- **MAY** extend to `mcp_server` skill types (Model Context Protocol
  servers) pending constitutional review

**Compliance**:
- Code-review enforced: Reviewer rejects out-of-scope artifacts and
  unapproved dependency additions

---

### II. Spec-First & Test-Driven Development

**Statement**: Every feature MUST start with a specification. All Swift
code MUST follow test-driven development: tests written first, verified
to fail, then implementation proceeds.

**Rationale**: Specifications ensure alignment with user needs and
provide measurable success criteria. Small, independent specs enable
parallel work, reduce risk, and accelerate feedback. TDD prevents
regressions, enables confident refactoring, and documents expected
behavior.

**Practices - Specification Requirements**:
- **MUST** create `spec.md` under `specs/` for every feature before
  development
- **MUST** represent a single feature or small subfeature
- **MUST** be independently testable (no dependencies on incomplete
  specs)
- **MUST** define user scenarios with acceptance criteria in
  Given-When-Then format
- **MUST** include measurable success criteria
- **MUST** focus on behavior, not implementation details
- **MUST** prioritize user stories by importance (P1/P2/P3)
- **MUST NOT** combine multiple unrelated features in one spec

**Practices - Test-Driven Development**:
- **MUST** write tests first based on spec.md acceptance criteria
- **MUST** verify tests fail before any implementation
- **MUST** implement minimal code to pass the tests
- **MUST** refactor while keeping tests green
- **MUST** maintain separate unit and contract tests
- **SHOULD** develop outside-in (user's perspective first)

**Compliance**:
- CI-enforced: `make test` — See `.github/workflows/ci.yml`
- Code-review enforced: Reviewer verifies tests were written first
  (commit order) and specs are single-feature

---

### III. JSON-Only Output Contract

**Statement**: Every CLI skill binary MUST produce structured JSON on
stdout for all commands. No human-readable logs, no mixed formats,
no flags required.

**Rationale**: Agents parse CLI output programmatically. Mixed formats
(JSON interspersed with log lines, human-readable tables) cause parse
failures, silent data loss, and unpredictable agent behavior. A strict
JSON-only contract ensures deterministic, reliable agent-tool
interaction.

**Practices - Output Format**:
- **MUST** output JSON to stdout for every command (success and error)
- **MUST** use consistent envelope: `{ "ok": true, ... }` for success,
  `{ "ok": false, "error": { "code": "...", "message": "..." } }` for
  error
- **MUST** define documented exit codes per command (0 = success,
  non-zero = specific failure)
- **MUST** send diagnostic/debug output to stderr only
- **MUST NOT** emit logs, warnings, or human text to stdout
- **MUST NOT** require flags to enable JSON output (JSON is the only
  format)
- **SHOULD** include the triggering entity (e.g., task object) in
  error responses when available

**Practices - Contract Stability**:
- **MUST** maintain backward-compatible JSON schemas within a major
  version
- **MUST** document breaking schema changes in CHANGELOG.md
- **MUST** have contract tests validating JSON output structure
- **SHOULD** version the output contract alongside the binary

**Practices - Error Code Taxonomy**:
- **SHOULD** use standardized error categories across skills:
  `INVALID_INPUT`, `CONFLICT`, `TRANSIENT_ERROR`, `RATE_LIMIT`,
  `PERMISSION_DENIED`, `INTERNAL_ERROR`, plus domain-specific codes
- **MUST** document all error codes and their exit code mappings in
  commands.json `exit_codes`
- **MUST** distinguish transient errors (retry-eligible) from
  permanent errors in commands.json (via `retry` field presence)
- **SHOULD** include the error category in the JSON error envelope:
  `{ "ok": false, "error": { "code": "CONFLICT", "message": "..." } }`

**Compliance**:
- CI-enforced: `make test` (contract tests) — See
  `.github/workflows/ci.yml`
- Code-review enforced: Reviewer rejects stdout pollution and
  verifies JSON envelope compliance

---

### IV. Security by Layers

**Statement**: All skill interactions with external systems MUST follow
defense-in-depth security practices. Inbound content is UNTRUSTED.
Outbound actions require human approval for destructive operations.

**Rationale**: Agent skills bridge AI systems to external services
(Notion, email, APIs). Each layer — credential handling, inbound data
treatment, outbound action gating — MUST independently prevent
exploitation. A single compromised layer MUST NOT cascade into
unauthorized actions.

**Practices - Credential Handling**:
- **MUST** prefer OS-provided secret storage (e.g., system keychain)
  or OAuth over environment variables
- **MUST** redact tokens and secrets from all error output and logs
- **MUST** validate that redaction occurred before emitting stderr
- **MUST** document required credentials in SKILL.md `security_notes`
- **MUST NOT** pass secrets via command-line arguments (visible in
  process listings)
- **MUST NOT** store secrets in configuration files in plain text
- **SHOULD** support environment variable fallback for CI/Docker
  contexts

**Practices - Inbound Content (Data from External Systems)**:
- **MUST** treat all external content as untrusted data, not commands
- **MUST** strip HTML and invisible text (zero-width chars, Unicode
  tags) from email/rich-text content
- **MUST** wrap external content in explicit boundary markers when
  presenting to agents
- **MUST** scan for prompt injection patterns and flag suspicious
  content
- **MUST NOT** execute instructions found in task titles,
  descriptions, comments, or email bodies
- **MUST NOT** follow URLs embedded in external content without user
  approval

**Practices - Outbound Actions (Agent → External System)**:
- **MUST** require explicit lock tokens for status-changing operations
- **MUST** gate destructive operations behind confirmation or
  `--force` flags
- **MUST** use draft-first workflows for high-impact actions (e.g.,
  email send)
- **SHOULD** declare `destructive` and `requires_confirmation` per
  command in commands.json

**Practices - Data Privacy & User Consent**:
- **MUST** obtain explicit user consent before accessing external
  system data (API tokens imply consent for declared capabilities only)
- **MUST NOT** log, cache, or persist user data (task content, email
  bodies, personal information) beyond the scope of a single command
  invocation
- **MUST NOT** transmit user data to systems other than the declared
  external service without explicit user approval
- **MUST** document what user data each skill accesses in SKILL.md
- **SHOULD** minimize data returned to agents (return IDs and
  metadata rather than full content when sufficient)

**Practices - Least Privilege & Scope Minimization**:
- **MUST** request only the minimum API scopes required for declared
  capabilities
- **MUST** document required scopes/permissions in SKILL.md
  `security_notes`
- **MUST NOT** request broad or wildcard permissions (e.g., full
  admin access) when narrower scopes exist
- **SHOULD** use progressive scope elevation — start with read-only
  access and request write access only when a destructive operation
  is invoked
- **SHOULD** document the blast radius if credentials are compromised
  (what an attacker could access)

**Compliance**:
- CI-enforced: `make lint-skills` (SKILL.md structural validation)
  — See `.github/workflows/ci.yml`
- Code-review enforced: Reviewer verifies credential redaction,
  scope minimization, and SKILL.md security documentation

---

### V. Skill Portability, Discovery & Architecture

**Statement**: Skills MUST be self-contained, filesystem-discoverable,
and installable without modification to shared configuration. Both
Swift-backed and external CLI skills MUST follow the same discovery
contract. Swift-backed skills MUST separate business logic from CLI
entry points.

**Rationale**: A monorepo of agent skills must scale without
coordination overhead. Adding a new skill MUST NOT require editing
central registries, Makefile variables (for external CLI skills), or
shared configuration. Filesystem convention replaces manual
registration. Separating library from executable enables unit testing
of domain logic, reuse in other contexts, and clean dependency
boundaries.

**Practices - Discovery Contract**:
- **MUST** discover skills by filesystem presence of `SKILL.md` in
  directories under `skills/`
- **MUST** auto-discover external CLI skills without Makefile changes
- **MUST** install all discovered skills (both types) via
  `make install`
- **MUST NOT** require central registration for external CLI skills

**Practices - Skill Self-Containment**:
- **MUST** include `SKILL.md` with YAML frontmatter (`name` and
  `description` required)
- **MUST** declare `version` (SemVer) in SKILL.md frontmatter
- **MUST** include `references/commands.json` with structured command
  definitions
- **MUST** declare `capabilities` for agent tool routing
- **MUST** declare `risk_level` for sandbox gating
- **MUST** provide `verify_install` (binary on PATH) and
  `verify_ready` (tool configured) commands
- **SHOULD** provide a lightweight availability probe command (e.g.,
  `<binary> doctor` or `<binary> health`) returning
  `{"ok": true|false}` so agents can skip unavailable skills
- **SHOULD** include reference documentation in `references/` directory
- **SHOULD** provide `examples` in commands.json for few-shot agent
  learning

**Practices - Frontmatter Schema**:
- **MUST** validate all SKILL.md frontmatter via `skill-lint`
- **MUST** fail CI if linter reports errors
- **MUST** keep schema backward-compatible (new optional fields only)
- **SHOULD** emit warnings for missing recommended fields
- **SHOULD** declare `deprecated_commands` listing commands scheduled
  for removal with target removal version

**Practices - Package Architecture (Swift-backed skills)**:
- **MUST** define a library target (e.g., `NTaskLib`) containing all
  business logic
- **MUST** define an executable target (e.g., `ntask`) as a thin
  wrapper using swift-argument-parser
- **MUST** keep the executable entry point under 20 lines
- **MUST** place commands, domain types, and policies in the library
  target
- **MUST NOT** put business logic in the executable target

**Practices - Dependency Management**:
- **MUST** minimize external dependencies
- **MUST** pin dependency versions in Package.swift
- **MUST** use direct process execution with argument arrays (not
  shell string interpolation)
- **SHOULD** prefer Swift standard library solutions over external
  packages
- **SHOULD** use swift-subprocess for process execution

**Practices - Code Quality**:
- **MUST** use Swift 6.1+ strict concurrency checking
- **MUST** handle errors with typed error enums, not string messages
- **MUST** use Codable types for JSON serialization (not manual
  dictionary construction)
- **SHOULD** centralize shared constants (property names, error codes)
  to avoid magic strings

**Practices - Skill Authoring Standards**:
- **MUST** include YAML frontmatter with all required fields
- **MUST** document available commands in a table
- **MUST** document error handling with exit codes and agent actions
- **MUST** include security section for inbound content treatment
- **MUST** reference commands.json for structured command definitions
- **MUST** include `name`, `binary`, `description`, `output_format`,
  and `examples` per command in commands.json
- **MUST** declare `destructive`, `capability`, and `exit_codes`
  per command in commands.json
- **MUST** include at least one example per command with `intent`,
  `command`, `output_format`, `example_output`, and `exit_code`
- **SHOULD** include `parameters` with JSON Schema for agent
  validation
- **SHOULD** include workflow documentation (agent lifecycle, state
  machine)
- **SHOULD** include schema documentation (database properties, data
  model)
- **SHOULD** include prerequisite documentation (first-run setup)
- **MAY** include policy documentation (selection algorithms, triage
  rules)

**Compliance**:
- CI-enforced: `make lint-skills` (frontmatter + commands.json
  validation), `make build-all` (package architecture) — See
  `.github/workflows/ci.yml`
- Code-review enforced: Reviewer rejects business logic in executable
  targets and verifies discovery contract compliance

---

### VI. Deterministic Agent Behavior

**Statement**: Given the same inputs and environment, skill commands
MUST produce the same outputs and state transitions. Non-deterministic
elements (timestamps, UUIDs) MUST be documented and isolated.

**Rationale**: Agents rely on predictable tool behavior for planning,
retry logic, and error recovery. Non-deterministic commands make agent
behavior unreproducible, debugging impossible, and test coverage
unreliable.

**Practices - Deterministic Execution**:
- **MUST** produce identical results for identical inputs and state
- **MUST** document all sources of non-determinism (lock tokens,
  timestamps, API-generated IDs)
- **MUST** use deterministic sort orders for list/query commands
- **MUST** define explicit tiebreakers in sort algorithms (never rely
  on undefined order)
- **MUST** pre-validate prerequisites before mutating state

**Practices - Distributed Locking**:
- **MUST** use lock tokens (UUID v4) for all status-changing
  operations
- **MUST** verify lock ownership before and after mutations
- **MUST** expire locks after a documented lease period
- **MUST** return explicit conflict codes (CONFLICT, LOST_LOCK) when
  lock verification fails
- **MUST NOT** silently retry on conflict (agent decides retry
  strategy)

**Practices - Idempotency**:
- **MUST** declare `"idempotent": true|false` per command in
  commands.json
- **SHOULD** accept `--idempotency-key <UUID>` for non-idempotent
  mutation commands; same key + same params = identical result (no
  duplicate side effects)
- **SHOULD** use natural keys (e.g., `--run-id` + `<task-id>`) as
  implicit idempotency keys where the domain model supports it
- **MUST NOT** silently create duplicate state on retry of a
  non-idempotent command

**Practices - Error Recovery**:
- **MUST** define an error recovery matrix per skill (exit code →
  agent action)
- **MUST** distinguish transient errors (retry-eligible) from
  permanent errors (escalate to user)
- **MUST** document retry policy (max attempts, backoff strategy) in
  SKILL.md or workflow.md
- **SHOULD** include the failing entity in error responses for agent
  context
- **SHOULD** implement client-side rate limiting for API-calling
  commands to prevent agent retry loops from exhausting external
  service quotas during outages
- **SHOULD** document rate limit behavior (backoff, max requests/min)
  in SKILL.md or commands.json `retry` field
- **SHOULD** declare a `timeout_seconds` per command in commands.json
  so agents can set execution deadlines and avoid hanging indefinitely
  on unresponsive external services

**Compliance**:
- CI-enforced: `make test` (policy tests for sort determinism and
  lock behavior, contract tests for error structure) — See
  `.github/workflows/ci.yml`
- Code-review enforced: Reviewer rejects state mutations without
  lock verification; reviewer verifies idempotency declarations

---

### VII. CI, Quality Gates & Living Documentation

**Statement**: All code changes MUST pass automated quality gates
before merge. Documentation MUST be treated as a code artifact,
kept synchronized with the codebase, and maintained with the same
review rigor.

**Rationale**: Automated gates catch regressions before they reach
agents. Stale documentation is a silent failure mode — agents that
rely on outdated SKILL.md, commands.json, or README information will
malfunction without warning. Both code and docs require continuous
enforcement.

**Practices - Required CI Checks**:
- **MUST** build all Swift-backed skills (`make build-all`)
- **MUST** pass all unit and contract tests (`make test`)
- **MUST** pass skill frontmatter and commands.json linting
  (`make lint-skills`)
- **MUST** run on macOS (primary platform)
- **SHOULD** complete CI pipeline in under 10 minutes

**Practices - Failure Policy**:
- Merge is BLOCKED if any check fails
- Developer MUST fix root cause (no bypassing with `--no-verify`)
- Re-run full CI suite after fixes

**Practices - Living Documentation**:
- **MUST** update README when skills are added or removed
- **MUST** update CHANGELOG with breaking changes and migration notes
- **MUST** keep commands.json synchronized with actual CLI behavior
- **MUST** keep SKILL.md error tables matching implemented exit codes

**Practices - Mandatory Update Triggers**:
1. New skill added or removed
2. Command added, removed, or renamed
3. Exit code semantics changed
4. Database schema or property changes
5. YAML frontmatter schema changes

**Practices - Audit Trail**:
- **SHOULD** log command invocations (command name, key parameters,
  exit code, duration) to stderr for debugging agent behavior
- **MUST NOT** include secrets, tokens, or user content in audit logs

**Practices - Open Source Excellence**:
- **MUST** maintain clear README with setup instructions and usage
  examples
- **MUST** include LICENSE file (MIT)
- **MUST** write clear, human-readable code (readability over
  cleverness)
- **MUST** apply KISS and DRY principles
- **SHOULD** provide contribution guidelines (CONTRIBUTING.md)
- **SHOULD** maintain security disclosure process (SECURITY.md)
- **SHOULD** provide issue and PR templates
- **SHOULD** respond to community contributions promptly and
  respectfully

**Compliance**:
- CI-enforced: `make build-all`, `make test`, `make lint-skills`
  — See `.github/workflows/ci.yml`
- Code-review enforced: Reviewer verifies documentation is current,
  commands.json matches CLI behavior, README reflects skill additions

---

## Governance

### Authority

This constitution supersedes all other development practices for
openclaw-skills. Deviations MUST be explicitly justified and approved.

### Enforcement Matrix

Quick-reference mapping each principle to its enforcement mechanism.
For full details, see the Compliance section within each principle.

| Principle | CI-Enforced | Code-Review Enforced |
|-----------|-------------|----------------------|
| I. Scope & Mission | — | Out-of-scope artifacts, dependency additions |
| II. Spec-First & TDD | `make test` | Tests-first commit order, single-feature specs |
| III. JSON-Only Contract | `make test` | Stdout pollution, envelope compliance, error taxonomy |
| IV. Security by Layers | `make lint-skills` | Credential redaction, scope minimization, security docs |
| V. Portability & Architecture | `make lint-skills`, `make build-all` | Lib/exe separation, discovery contract, version field |
| VI. Deterministic Behavior | `make test` | Lock verification, idempotency declarations |
| VII. CI & Living Docs | `make build-all`, `make test`, `make lint-skills` | Doc currency, commands.json sync, README updates |

CI configuration: `.github/workflows/ci.yml`

### Amendment Process

1. Project owner proposes amendment with rationale and impact analysis
2. Version updated (semantic versioning):
   - **MAJOR**: Backward-incompatible changes, principle removals,
     or structural overhaul
   - **MINOR**: New principles added or materially expanded guidance
   - **PATCH**: Clarifications, wording improvements, non-semantic
     refinements
3. Update dependent templates in `.specify/templates/` if applicable
4. Document changes in Sync Impact Report
5. Commit with descriptive message

**Approval**: Project owner can amend directly. Community proposes via
issues.

### Contract-Breaking Change Protocol

Changes to agent-facing contracts (JSON output envelope, SKILL.md
frontmatter schema, commands.json structure) carry outsized downstream
risk because agents parse these surfaces programmatically.

- **MUST** include impact analysis identifying affected consumers
- **MUST** provide migration notes in CHANGELOG.md
- **MUST** deprecate before removal: ≥3 minor releases or 6 months
  (whichever is longer) before removal in the next major version
- **MUST** emit a stderr deprecation warning when deprecated commands
  or parameters are invoked
- **MUST** bump the relevant package major version for breaking
  schema changes

### Security-Relevant Change Protocol

Changes to credential handling, inbound content treatment, or
outbound action gating affect the trust boundary between agents and
external systems.

- **MUST** include explicit review of SKILL.md `security_notes`
- **MUST** verify credential redaction remains intact after changes
- **MUST** update threat model documentation if attack surface changes
- **SHOULD** include security-focused test cases in the PR

### Compliance Review

**Continuous Enforcement**:
- **MUST**: Blocks merge
- **SHOULD**: Warning, requires override justification
- **MAY**: Informational only

**Event-Driven Review**: Triggered by:
1. New skill additions
2. Breaking changes to output contracts or frontmatter schema
3. Repeated SHOULD overrides (3+ in 30 days)
4. Annual checkpoint

### Security Disclosure Process

A clear process for reporting vulnerabilities MUST be documented.

- **MUST** provide SECURITY.md with reporting instructions
- **MUST** include preferred contact method (email, encrypted if
  possible)
- **MUST** define expected response timeline (e.g., acknowledgment
  within 48 hours)
- **MUST** commit to coordinated disclosure timeline
- **SHOULD** provide PGP key for encrypted reports
- **SHOULD** acknowledge reporters in release notes (with permission)

### Versioning & Stability Signaling

Downstream agents depend on stable skill binaries and contracts.
Package versioning communicates stability expectations.

**Pre-1.0** (current):
- No stability guarantees
- Breaking changes acceptable with CHANGELOG documentation
- Users advised to pin exact versions

**Post-1.0** (future):
- Semantic versioning strictly enforced
- Deprecation period (≥3 minor releases or 6 months) before removal
- Breaking changes require major version bump
- Contract-Breaking Change Protocol applies to all changes

### Enforcement

- PR reviewers verify constitutional alignment
- CI pipeline enforces MUST-level checks (`make build-all`,
  `make test`, `make lint-skills`)
- SKILL.md linter validates structural requirements automatically
- See Enforcement Matrix above for per-principle detail

---

## Version History

**Version**: 2.1.0
**Ratified**: 2026-02-12
**Last Amended**: 2026-02-15

**Changelog**:
- **2.1.0** (2026-02-15): Feedback-driven minor revision. Added
  idempotency practices to Principle VI (SHOULD). Added `version`
  field requirement to SKILL.md frontmatter (MUST). Added hybrid
  enforcement: per-principle inline Compliance sections + Governance
  Enforcement Matrix table. Fixed deps wording in Principle I to
  include swift-system. Concrete deprecation timeline: ≥3 minor
  releases or 6 months (whichever is longer). Added health check
  pattern to Principle V (SHOULD). Reworded credential storage to
  "OS-provided secret storage" in Principle IV. Added error code
  taxonomy to Principle III (SHOULD). Added rate limiting and
  execution timeout practices to Principle VI (SHOULD). Added audit
  trail practices to Principle VII (SHOULD). Added `deprecated_commands`
  frontmatter field (SHOULD). Skipped: agent session scoping (out of
  scope by Principle I), MUST-level tiering (already handled by
  MUST/SHOULD/MAY). Research-informed by MCP spec, Kubernetes
  deprecation policy, Terraform backward compatibility, Homebrew
  acceptable formulae.
- **2.0.0** (2026-02-15): Major revision. Added Principle I (Scope &
  Mission Boundaries) with MCP MAY clause. Promoted CI & Quality Gates
  from Implementation Guidance to Principle VII, merged with Agent
  Maintenance Rules as Living Documentation. Merged Library + Executable
  Architecture into Principle V (Skill Portability, Discovery &
  Architecture). Absorbed Skill Authoring Standards into Principle V.
  Eliminated Implementation Guidance section. Added contract-breaking
  and security-relevant change protocols to Governance. Updated Preamble
  philosophy to prioritize agent reliability and Unix-style simplicity.
  Gap analysis addendum: added Data Privacy & User Consent practices,
  Least Privilege / Scope Minimization practices (Principle IV), Open
  Source Excellence practices (Principle VII), Security Disclosure
  Process, and Versioning & Stability Signaling (Governance). Research-
  informed by Kubernetes, MCP, Terraform, Homebrew, Rust, and Unix
  philosophy patterns.
- **1.0.0** (2026-02-12): Initial constitution. 6 core principles
  derived from established repository patterns: Spec-First & TDD,
  JSON-Only Output Contract, Security by Layers, Skill Portability &
  Discovery, Library + Executable Architecture, Deterministic Agent
  Behavior. Three implementation guidance sections: CI & Quality Gates,
  Skill Authoring Standards, Agent Maintenance Rules. Three-tier
  enforcement model (MUST/SHOULD/MAY).

---

## v2.2 Roadmap

The following items were identified during v2.1 review but deferred to
avoid scope creep. They are recorded here so they are not lost.

| # | Item | Target | Summary |
|---|------|--------|---------|
| R1 | Security Disclosure Protocol | Governance | Expand to full OWASP-style: private report → coordinated timeline → advisory |
| R2 | Observability & Exit Codes | Principle III | Standardized exit code ranges (0=success, 20-29=client, 30-39=server) |
| R3 | Contract Breaking Definition | Principle III | Define breaking (remove field, change type) vs non-breaking (add optional field) |
| R4 | Test Coverage Minimum | Principle II | Snapshot testing for JSON output, happy path + error cases documented |
| R5 | Threat Model & Privilege Boundaries | Principle IV | Skills document OS permissions, external APIs, shell input sanitization |
| R6 | Skill Maintenance & Sunset | Governance | Unmaintained skills (6+ months) marked deprecated; archive/delist process |
| R7 | Dependency Update Policy | Governance | When to update pinned deps, security patch cadence, update audit trail |
