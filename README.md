# openclaw-skills

A monorepo of [OpenClaw](https://openclaw.dev) skills — installable agent capabilities backed by Swift CLI tools or existing external CLIs.

## Repository Layout

```
openclaw-skills/
├── Makefile                         # Build orchestration (make help)
├── skills/                          # Skill definitions
│   ├── notion-task-skill/           # Swift-backed skill (type: swift_cli)
│   │   ├── SKILL.md                 # Skill definition (YAML frontmatter)
│   │   ├── references/              # Schema, policy, examples, prereqs
│   │   └── bin/                     # Built binaries (gitignored)
│   ├── notion-cli/                  # External CLI skill (type: external_cli)
│   │   └── SKILL.md                 # Docs-only — no build required
│   └── proton-mail-bridge/          # External CLI skill (type: external_cli)
│       └── SKILL.md                 # Docs-only — no build required
└── packages/                        # SwiftPM packages
    ├── ntask/                       # Notion task CLI wrapper
    └── skill-lint/                  # SKILL.md frontmatter validator
```

## What Is a Skill?

A **skill** is any directory under `skills/` that contains a `SKILL.md` file. There are two types:

- **`swift_cli`** — Backed by a SwiftPM package in `packages/`. The Makefile builds the binary and copies it into the skill's `bin/` directory.
- **`external_cli`** — Wraps an existing CLI tool already installed on the system (e.g. via npm, brew, or a direct download). No Swift code or build step required — the skill is docs-only.

Both types use the same `SKILL.md` format with YAML frontmatter.

## Quick Start

### Prerequisites

- **Swift 6.1+** (Xcode 16.4+ or swift.org toolchain) — required for building `swift_cli` skills and the linter
- **make** (ships with Xcode Command Line Tools)
- External CLI tools are only needed at runtime for their respective skills

### Build Swift Skills

```bash
make build-all
```

### Build a Single Skill

```bash
make build SKILL=notion-task-skill
```

### List All Skills

```bash
make list-skills
```

### Lint SKILL.md Frontmatter

```bash
make lint-skills
```

### Install into an OpenClaw Workspace

Installs **all** skills (both `swift_cli` and `external_cli`) into a workspace:

```bash
# Copy skills into workspace (default)
make install WORKSPACE=/path/to/workspace

# Or symlink for development
make install WORKSPACE=/path/to/workspace MODE=symlink
```

### Run Tests

```bash
make test
```

### Check Environment

```bash
make doctor
```

### See All Available Commands

```bash
make help
```

## Skills

### notion-task-skill (swift_cli)

Manages Notion-backed tasks via the `ntask` CLI. The agent interacts with Notion exclusively through `ntask` commands — never directly via the API.

**Commands:** `doctor`, `next`, `claim`, `heartbeat`, `complete`, `block`, `create`, `list`, `get`, `comment`, `review`, `cancel`, `update`, `version`

All commands output JSON only. See [SKILL.md](skills/notion-task-skill/SKILL.md) for full usage and [references/](skills/notion-task-skill/references/) for schema, policy, and examples.

**Required environment variables:**
- `NOTION_TOKEN` — Notion API integration token
- `NOTION_TASKS_DB_ID` — Notion tasks database ID

### notion-cli (external_cli)

Wraps the [notion-cli](https://github.com/salmonumbrella/notion-cli) tool for searching, reading, and creating Notion pages and database entries from the terminal. No Swift build required — install `notion-cli` via npm.

See [SKILL.md](skills/notion-cli/SKILL.md) for installation, usage, and security notes.

### proton-mail-bridge (external_cli)

Wraps the [Proton Mail Bridge](https://proton.me/mail/bridge) CLI for managing Bridge accounts, checking status, and monitoring sync. Requires a paid Proton Mail plan. No Swift build required.

See [SKILL.md](skills/proton-mail-bridge/SKILL.md) for installation, usage, and security notes.

## Architecture

### Swift-backed skills

Each Swift skill follows the **Library + Executable** pattern:

- **NTaskLib** — All business logic, fully unit-testable
- **ntask** — Thin executable wrapper

Swift skills are mapped to their backing packages via the root `Makefile` (`SKILL_<name>` variables). Run `make help` to see available targets.

### External CLI skills

External CLI skills contain only a `SKILL.md` file (plus optional `references/` assets). They require no Swift code, no build step, and no entry in the `SKILLS`/`PACKAGES` Makefile lists. They are automatically discovered by `make list-skills`, `make install`, and `make lint-skills`.

## YAML Frontmatter Schema

Every `SKILL.md` must begin with YAML frontmatter between `---` delimiters.

### Required fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Human-readable skill name |
| `slug` | string | URL/directory-safe identifier |
| `type` | string | `swift_cli` or `external_cli` |
| `requires_binaries` | list | CLI commands expected on PATH |
| `supported_os` | list | `macos`, `linux`, and/or `windows` |
| `verify` | list | Non-destructive commands to confirm installation |

### Optional fields

| Field | Type | Description |
|-------|------|-------------|
| `install` | map | Per-OS installation instructions (keyed by OS) |
| `security_notes` | string or list | Credential handling and risk notes |
| `capabilities` | list of objects | Grouped capability declarations (see below) |
| `risk_level` | string | `low`, `medium`, `high`, or `critical` |
| `verify_install` | list | Commands to confirm the binary is on PATH |
| `verify_ready` | list | Commands to confirm the tool is fully configured |
| `output_format` | string | `json`, `line_based`, `table`, or `freeform` |
| `output_parsing` | map | Parsing hints (e.g. `success_json_path`, `error_stream`) |

Additional fields (e.g. `description`, `version`, `author`, `tags`) are allowed and ignored by the linter.

### Capability objects

Each entry in `capabilities` has:

| Key | Required | Type | Description |
|-----|----------|------|-------------|
| `id` | Yes | string | Machine-friendly identifier (unique within skill) |
| `description` | Yes | string | What this capability group does |
| `destructive` | Yes | bool | Whether it modifies state |
| `requires_confirmation` | No | bool | Agent should confirm with user (default: false) |

## Structured Examples

Each skill can include a `references/examples.json` file containing machine-readable command/response examples. The linter validates this file if present.

Each entry must have: `intent` (string), `command` (string), `output_format` (string), `example_output` (object or string), `exit_code` (int). Optional: `notes`, `destructive`.

## Adding a New Skill

### Add a Swift-backed skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter (set `type: swift_cli`)
2. Create a SwiftPM package in `packages/<package-name>/`
3. Add the mapping to the `Makefile` (`SKILL_<name>` variable and add to `SKILLS`/`PACKAGES` lists)
4. Run `make build SKILL=<skill-name>` to verify
5. Run `make lint-skills` to validate frontmatter
6. Optionally add `references/examples.json` with structured examples

### Add an external CLI skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter (set `type: external_cli`)
2. Include installation instructions, verify commands, usage examples, and security notes in the body
3. Add `references/examples.json` with structured command/response examples
4. Optionally add a `references/` directory for supplementary docs
5. Run `make lint-skills` to validate frontmatter and examples
6. No Makefile changes needed — the skill is automatically discovered

## License

See [LICENSE](LICENSE) for details.