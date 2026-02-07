# openclaw-skills

A monorepo of [OpenClaw](https://openclaw.dev) skills — installable agent capabilities backed by Swift CLI tools.

## Repository Layout

```
openclaw-skills/
├── Makefile                         # Build orchestration (make help)
├── skills/                          # Skill definitions
│   └── notion-task-skill/           # Notion task management skill
│       ├── SKILL.md                 # Skill definition (YAML frontmatter)
│       ├── references/              # Schema, policy, examples, prereqs
│       └── bin/                     # Built binaries (gitignored)
└── packages/                        # SwiftPM packages
    └── ntask/                       # Notion task CLI wrapper
```

## Quick Start

### Prerequisites

- **Swift 6.1+** (Xcode 16.4+ or swift.org toolchain)
- **make** (ships with Xcode Command Line Tools)
- **[notion-cli](https://github.com/salmonumbrella/notion-cli)** (for runtime)

### Build All Skills

```bash
make build-all
```

### Build a Single Skill

```bash
make build SKILL=notion-task-skill
```

### Install into an OpenClaw Workspace

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

### notion-task-skill

Manages Notion-backed tasks via the `ntask` CLI. The agent interacts with Notion exclusively through `ntask` commands — never directly via the API.

**Commands:** `doctor`, `next`, `claim`, `heartbeat`, `complete`, `block`, `create`, `list`, `get`, `comment`, `review`, `cancel`, `update`, `version`

All commands output JSON only. See [SKILL.md](skills/notion-task-skill/SKILL.md) for full usage and [references/](skills/notion-task-skill/references/) for schema, policy, and examples.

**Required environment variables:**
- `NOTION_TOKEN` — Notion API integration token
- `NOTION_TASKS_DB_ID` — Notion tasks database ID

## Architecture

Each skill follows the **Library + Executable** pattern:

- **NTaskLib** — All business logic, fully unit-testable
- **ntask** — Thin executable wrapper

Skills are mapped to their backing packages via the root `Makefile`. Run `make help` to see available targets.

## Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with YAML frontmatter
2. Create a SwiftPM package in `packages/<package-name>/`
3. Add the mapping to the `Makefile` (`SKILL_<name>` variable and add to `SKILLS`/`PACKAGES` lists)
4. Run `make build SKILL=<skill-name>` to verify

## License

See [LICENSE](LICENSE) for details.