# Feature Specification: Agent-Ready Skill Enhancements

**Feature Branch**: `002-skill-enhancements`  
**Created**: 2026-02-07  
**Status**: Complete  
**Input**: User description: "Implement top 5 agent-readiness improvements: capability schema, verify-ready, risk level, structured examples, output parsing hints."

## User Scenarios & Testing

### User Story 1 - Capability Schema (Priority: P1)

As an agent runtime, I want each skill to declare its capabilities as structured metadata grouped by category, so I can route intents to the correct skill without parsing prose.

**Why this priority**: Capability discovery is the foundation for agent tool selection. Without structured capabilities, agents must parse markdown to understand what a skill can do.

**Independent Test**: Can be fully tested by adding `capabilities` to frontmatter and running `make lint-skills` to verify validation passes.

**Acceptance Scenarios**:

1. **Given** a SKILL.md with valid `capabilities` entries, **When** I run `make lint-skills`, **Then** validation passes with zero errors
2. **Given** a capability missing `id`, **When** I run `make lint-skills`, **Then** an error is reported for the missing field
3. **Given** duplicate capability `id` values, **When** I run `make lint-skills`, **Then** an error is reported
4. **Given** a SKILL.md without `capabilities`, **When** I run `make lint-skills`, **Then** no error (field is optional)

---

### User Story 2 - Two-Tier Verification (Priority: P1)

As an agent runtime, I want to distinguish between "binary installed" and "tool fully configured," so I don't attempt operations with unconfigured tools.

**Why this priority**: Equally critical — a tool on PATH with no credentials is a false positive that wastes agent cycles.

**Independent Test**: Can be fully tested by adding `verify_install`/`verify_ready` to frontmatter and verifying the linter accepts both fields.

**Acceptance Scenarios**:

1. **Given** a SKILL.md with `verify_install` and `verify_ready`, **When** I run `make lint-skills`, **Then** both are validated as non-empty lists
2. **Given** a SKILL.md with only legacy `verify`, **When** I run `make lint-skills`, **Then** no warning or error (backward compatible)
3. **Given** an empty `verify_install` list, **When** I run `make lint-skills`, **Then** an error is reported

---

### User Story 3 - Risk Level (Priority: P2)

As an agent sandbox, I want each skill to declare its risk level, so I can gate confirmation prompts appropriately.

**Why this priority**: Simple one-field addition with high safety value.

**Acceptance Scenarios**:

1. **Given** `risk_level: medium`, **When** I run `make lint-skills`, **Then** validation passes
2. **Given** `risk_level: extreme`, **When** I run `make lint-skills`, **Then** an error is reported with allowed values

---

### User Story 4 - Structured Examples (Priority: P2)

As an agent, I want machine-readable command/response examples in JSON, so I can learn tool usage from few-shot examples.

**Why this priority**: Few-shot examples are the highest-leverage way to teach agents tool use.

**Acceptance Scenarios**:

1. **Given** a valid `references/examples.json`, **When** I run `make lint-skills`, **Then** the file passes validation
2. **Given** an example missing `intent`, **When** I run `make lint-skills`, **Then** an error is reported for that entry
3. **Given** no `references/examples.json`, **When** I run `make lint-skills`, **Then** no error (file is optional)

---

### User Story 5 - Output Parsing Hints (Priority: P3)

As an agent, I want the skill to declare its output format and parsing hints, so I can parse responses without guessing.

**Acceptance Scenarios**:

1. **Given** `output_format: json`, **When** I run `make lint-skills`, **Then** validation passes
2. **Given** `output_format: xml`, **When** I run `make lint-skills`, **Then** an error is reported with allowed values

---

### Edge Cases

- What if `capabilities` is present but empty? → Error: must be non-empty if present.
- What if `output_parsing` keys are unrecognized? → Allowed (free-form map for extensibility).
- What if `examples.json` is not valid JSON? → Error with parse failure message.

## Requirements

### Functional Requirements

- **FR-001**: Linter MUST validate `capabilities` entries (id, description, destructive required; id unique)
- **FR-002**: Linter MUST validate `risk_level` if present (allowed: low, medium, high, critical)
- **FR-003**: Linter MUST validate `verify_install` and `verify_ready` if present (non-empty lists)
- **FR-004**: Linter MUST validate `output_format` if present (allowed: json, line_based, table, freeform)
- **FR-005**: Linter MUST validate `references/examples.json` if present (required keys per entry)
- **FR-006**: All new fields MUST be optional (no breaking changes to existing skills)
- **FR-007**: Legacy `verify` field MUST still be accepted without warnings

## Success Criteria

- **SC-001**: `make lint-skills` passes with all 3 enhanced skills
- **SC-002**: All new linter tests pass (~22 new tests)
- **SC-003**: Each skill has capabilities, risk_level, verify_install, verify_ready, output_format
- **SC-004**: Each skill has references/examples.json
- **SC-005**: README documents all new schema fields
