# First-Run Setup Guide

Complete walkthrough from zero to a passing `ntask doctor`. Follow these steps
in order.

## 1. Install notion-cli

The ntask binary wraps [salmonumbrella/notion-cli](https://github.com/salmonumbrella/notion-cli),
a Go-based command-line interface for the Notion API.

### macOS (Homebrew)

```bash
brew install salmonumbrella/tap/notion-cli
```

### Go Install

```bash
go install github.com/salmonumbrella/notion-cli/cmd/notion@latest
```

Verify the binary is available:

```bash
notion --version
```

**Tested version:** ntask v0.1.0 is developed against notion-cli v0.6.x. Check
`notion --version` and consult the
[notion-cli repo](https://github.com/salmonumbrella/notion-cli) for compatibility
if using a different version.

## 2. Authenticate with Notion

notion-cli handles credential storage. Follow its auth instructions for your
platform. Choose one method:

### Option A: Integration Token (recommended for agents)

Best for automated/agent use. Works in headless environments.

1. Go to <https://www.notion.so/my-integrations>
2. Click **New integration**
3. Name it (e.g., "OpenClaw Agent"), select your workspace, click **Submit**
4. Copy the **Internal Integration Secret** (starts with `ntn_`)
5. Store the token in notion-cli's keychain:

```bash
notion auth add-token
# You will be prompted securely for the token — paste it and press Enter
```

6. Verify:

```bash
notion auth status
```

### Option B: Browser OAuth (personal use)

Better for individual developers. Requires a browser.

```bash
notion auth login
```

This opens your browser for Notion's OAuth flow. Approve access, then verify:

```bash
notion auth status
```

### Environment Variable Fallback

If you cannot use the keychain (e.g., CI/Docker), set the token as an
environment variable instead:

```bash
export NOTION_TOKEN="ntn_xxxxxxxxxxxxxxxxxxxx"
```

notion-cli and ntask will both read `NOTION_TOKEN` from the environment when
keychain credentials are not available.

## 3. Set Up Your Task Database

### Path A: Create a New Database

1. Open Notion and navigate to the workspace page where you want your task board
2. Type `/database` and select **Database - Full page**
3. Name it (e.g., "Agent Tasks")
4. Add each required property:

| Property               | Type      | Select Values (if applicable)                                          |
|------------------------|-----------|------------------------------------------------------------------------|
| ID                     | Unique ID | Auto-generated (e.g., TASK-42)                                         |
| Status                 | Status    | Backlog, Ready, In Progress, Blocked, Review, Done, Canceled           |
| Priority               | Number    | 1–3 (higher = more urgent)                                             |
| Class                  | Select    | Expedite, Fixed Date, Standard, Intangible                             |
| Claimed By             | Select    | Agent, Human                                                           |
| Agent Run              | Text      | —                                                                      |
| Agent                  | Select    | Agent name/identifier                                                  |
| Lock Token             | Text      | —                                                                      |
| Lock Expires           | Date      | —                                                                      |
| Dependencies           | Rollup    | Counts all sub-tasks (total count)                                     |
| Completed Sub-tasks    | Rollup    | Counts sub-tasks in Complete group (Done + Canceled)                   |

See [schema.md](schema.md) for the full property reference including optional
fields (Blocker Reason, Started At, Done At, etc.).

### Path B: Connect an Existing Database

If you already have a Notion task database, verify it has the required
properties. Open the database and check each one:

- [ ] **ID** — Unique ID property (auto-generated, e.g., TASK-42)
- [ ] **Status** — Native status with values: Backlog, Ready, In Progress, Blocked, Review, Done, Canceled
- [ ] **Priority** — Number 1–3 (higher = more urgent)
- [ ] **Class** — Select with values: Expedite, Fixed Date, Standard, Intangible
- [ ] **Claimed By** — Select with values: Agent, Human
- [ ] **Agent Run** — Text (can be empty initially)
- [ ] **Agent** — Select (agent name/identifier, can be empty initially)
- [ ] **Lock Token** — Text (can be empty initially)
- [ ] **Lock Expires** — Date (can be empty initially)
- [ ] **Dependencies** — Rollup on Sub-tasks relation (counts all sub-tasks)
- [ ] **Completed Sub-tasks** — Rollup on Sub-tasks relation (count_per_group, Complete group)

Add any missing properties. Property names must match **exactly** (case-sensitive).

## 4. Share the Database with Your Integration

**This step is critical.** Notion integrations can only access pages that have
been explicitly shared with them.

1. Open your task database in Notion
2. Click the **...** menu (top-right of the page)
3. Scroll to **Connections** (or **Add connections**)
4. Find your integration by name (e.g., "OpenClaw Agent")
5. Click **Confirm** to grant access

If you skip this step, ntask will fail with an API error when querying the
database.

## 5. Set the Database ID

Find your database ID from the Notion URL. Open the database in your browser:

```
https://www.notion.so/myworkspace/abc123def456789012345678abcdef12?v=...
                                  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
                                  This is the database ID
```

Set it as an environment variable:

```bash
export NOTION_TASKS_DB_ID="abc123def456789012345678abcdef12"
```

Add this to your shell profile (`.zshrc`, `.bashrc`, etc.) to persist it.

## 6. Build and Install the Skill

From the openclaw-skills repository root:

```bash
make build SKILL=notion-task-skill
```

This builds the ntask binary and copies it to
`skills/notion-task-skill/bin/ntask`.

## 7. Validate

Run the doctor command to verify everything is configured:

```bash
ntask doctor
```

Doctor checks (in order):
1. `notion` binary exists in PATH
2. `notion --version` succeeds
3. `NOTION_TOKEN` is available (keychain or environment)
4. `NOTION_TASKS_DB_ID` environment variable is set
5. A lightweight database query succeeds (verifies token + database access)

**All checks pass?** You're ready to go. Run `ntask next` to pull your first
task.

**A check failed?** The JSON output tells you which check failed. Common fixes:

| Check Failed          | Fix                                                     |
|-----------------------|---------------------------------------------------------|
| notion_cli not found  | Re-install notion-cli (step 1)                          |
| notion_token          | Run `notion auth login` or set NOTION_TOKEN (step 2)    |
| env_NOTION_TASKS_DB_ID| Set NOTION_TASKS_DB_ID in your environment (step 5)     |
| db_accessible = false | Share the database with your integration (step 4)       |

## Notes

- ntask automatically sets `NOTION_OUTPUT=json` when calling notion-cli. You do
  **not** need to set this yourself.
- If you want to use notion-cli directly for debugging, set
  `export NOTION_OUTPUT=json` in your shell.
