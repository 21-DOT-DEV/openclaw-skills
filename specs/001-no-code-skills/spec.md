# Feature Specification: No-Code External CLI Skills

**Feature Branch**: `001-no-code-skills`  
**Created**: 2026-02-07  
**Status**: Complete  
**Input**: User description: "Update the openclaw-skills repo to support no-code skills that rely on existing external CLI apps (no Swift wrapper required), while keeping existing Swift CLI-backed skills working."

## User Scenarios & Testing

### User Story 1 - External CLI Skill Discovery (Priority: P1)

As a skill author, I want to create a docs-only skill by adding a directory with a SKILL.md file under `skills/`, so I can make external CLI tools available to agents without writing any Swift code.

**Why this priority**: This is the core value proposition — enabling no-code skills alongside existing Swift skills. Without discovery, nothing else works.

**Independent Test**: Can be fully tested by creating a directory with a SKILL.md under `skills/` and running `make list-skills` to verify it appears.

**Acceptance Scenarios**:

1. **Given** a directory `skills/my-tool/` containing a `SKILL.md` file, **When** I run `make list-skills`, **Then** `my-tool` appears in the output
2. **Given** both Swift-backed and external CLI skill directories exist, **When** I run `make list-skills`, **Then** all skills are listed regardless of type
3. **Given** a directory under `skills/` without a `SKILL.md`, **When** I run `make list-skills`, **Then** that directory is not listed

---

### User Story 2 - Build Isolation (Priority: P1)

As a developer, I want `make build-all` to build only Swift-backed skills, so external CLI skills don't cause build failures and existing workflows remain unbroken.

**Why this priority**: Equally critical to US1 — breaking existing Swift builds would block all development. Build isolation is a safety requirement.

**Independent Test**: Can be fully tested by adding an external_cli skill directory and running `make build-all`, verifying it succeeds without attempting to build the new skill.

**Acceptance Scenarios**:

1. **Given** external_cli skill directories exist alongside Swift skills, **When** I run `make build-all`, **Then** only Swift-backed skills are built
2. **Given** no changes to Swift skills, **When** I run `make build-all`, **Then** build succeeds with the same output as before
3. **Given** an external_cli skill has no `bin/` directory, **When** I run `make build-all`, **Then** no error is raised for that skill

---

### User Story 3 - YAML Frontmatter Validation (Priority: P2)

As a skill author, I want a linter that validates my SKILL.md frontmatter against a defined schema, so I catch schema errors before they reach CI or users.

**Why this priority**: Validation ensures consistency across all skills. Less critical than discovery and build isolation, but essential for quality at scale.

**Independent Test**: Can be fully tested by creating SKILL.md files with valid and invalid frontmatter, running `make lint-skills`, and verifying correct pass/fail/warn behavior.

**Acceptance Scenarios**:

1. **Given** a SKILL.md with all required frontmatter fields, **When** I run `make lint-skills`, **Then** the skill passes validation with no errors
2. **Given** a SKILL.md missing a required field (e.g. `type`), **When** I run `make lint-skills`, **Then** an error is reported for that specific field
3. **Given** a SKILL.md with an invalid `type` value, **When** I run `make lint-skills`, **Then** an error is reported with allowed values
4. **Given** a SKILL.md with no frontmatter at all, **When** I run `make lint-skills` (default mode), **Then** a warning is emitted but the linter does not fail
5. **Given** a SKILL.md with no frontmatter, **When** I run `skill-lint --strict`, **Then** an error is emitted and the linter fails

---

### User Story 4 - Install All Skills (Priority: P2)

As an OpenClaw workspace operator, I want `make install` to copy all skill directories (both Swift and external CLI) into my workspace, so agents have access to every skill.

**Why this priority**: Install is the delivery mechanism. Without it, external CLI skills can't reach agents. Depends on US1 (discovery) and US2 (build isolation).

**Independent Test**: Can be fully tested by running `make install WORKSPACE=/tmp/test` and verifying all skill directories are copied, including external_cli ones.

**Acceptance Scenarios**:

1. **Given** Swift and external CLI skills exist, **When** I run `make install WORKSPACE=/tmp/test`, **Then** all skill directories are copied to the workspace
2. **Given** an external_cli skill, **When** install runs, **Then** the skill's SKILL.md and any references/ are copied without errors
3. **Given** `MODE=symlink`, **When** I run install, **Then** external_cli skills are symlinked like Swift skills

---

### User Story 5 - Example External CLI Skills (Priority: P3)

As a contributor, I want reference implementations of external CLI skills (notion-cli and proton-mail-bridge), so I have templates to follow when creating new skills.

**Why this priority**: Examples are essential for adoption but don't block technical functionality.

**Independent Test**: Can be fully tested by verifying each example skill has a SKILL.md with valid frontmatter, passes `make lint-skills`, and contains installation, verification, usage, and security documentation.

**Acceptance Scenarios**:

1. **Given** the notion-cli skill, **When** I read its SKILL.md, **Then** it contains valid frontmatter with `type: external_cli`, installation instructions, verify commands, usage examples, and security notes
2. **Given** the proton-mail-bridge skill, **When** I read its SKILL.md, **Then** it contains valid frontmatter with `type: external_cli`, installation instructions, verify commands, usage examples, and security notes about paid plan requirements and local-only ports
3. **Given** both example skills, **When** I run `make lint-skills`, **Then** both pass validation with zero errors

---

### Edge Cases

- What happens when a SKILL.md has frontmatter delimiters but invalid YAML inside? → Linter reports a parse error with the skill name.
- What happens when a skill directory contains only a SKILL.md with no body content? → Linter validates frontmatter only; body content is not checked.
- What happens when `supported_os` contains an unrecognized value? → Linter reports an error listing allowed values.
- What happens when `requires_binaries` is present but empty? → Linter reports an error (must be non-empty).
- What happens when `security_notes` is a string vs a list? → Both forms are accepted.

## Requirements

### Functional Requirements

- **FR-001**: System MUST discover skills by filesystem presence of `SKILL.md` in directories under `skills/`
- **FR-002**: System MUST build only Swift-backed skills during `make build-all` (no changes to existing SKILLS/PACKAGES lists)
- **FR-003**: System MUST provide a `skill-lint` CLI tool that validates YAML frontmatter against the defined schema
- **FR-004**: System MUST validate required frontmatter keys: `name`, `slug`, `type`, `requires_binaries`, `supported_os`, `verify`
- **FR-005**: System MUST accept optional frontmatter keys: `install`, `security_notes`
- **FR-006**: System MUST support warn-first policy: missing frontmatter emits warning (not error) unless `--strict`
- **FR-007**: System MUST install all discovered skills (both types) via `make install`
- **FR-008**: System MUST include lint validation in CI pipeline
- **FR-009**: System MUST document both skill types in README with separate "Adding a New Skill" instructions

### Key Entities

- **Skill**: A directory under `skills/` containing a `SKILL.md` file. Has a type (`swift_cli` or `external_cli`).
- **SKILL.md**: The single source of truth for a skill. Contains YAML frontmatter (schema) and markdown body (documentation for agents).
- **Frontmatter**: YAML between `---` delimiters at the top of SKILL.md. Defines metadata validated by `skill-lint`.

## Success Criteria

### Measurable Outcomes

- **SC-001**: `make build-all` succeeds without attempting to build external_cli skills
- **SC-002**: `make list-skills` lists all 3 skills (notion-task-skill, notion-cli, proton-mail-bridge)
- **SC-003**: `make lint-skills` validates all 3 skills with 0 errors and 0 warnings
- **SC-004**: `make install WORKSPACE=/tmp/test` copies all 3 skill directories
- **SC-005**: `make doctor` shows all discovered skills
- **SC-006**: `skill-lint` unit tests pass (15/15)
- **SC-007**: README documents both skill types, YAML schema, and two "Adding a Skill" paths

## Validation Steps

- [x] `make build-all` succeeds (Swift skills only)
- [x] `make list-skills` outputs all 3 skills
- [x] `make lint-skills` passes with 0 errors, 0 warnings
- [x] `make install WORKSPACE=/tmp/test` copies all 3 skill directories
- [x] `make doctor` shows discovered skills section
- [x] `make test` runs skill-lint tests (15/15 pass)
- [x] README documents both skill types and schema
