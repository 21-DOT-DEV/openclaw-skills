# Examples — ntask Command Lines and JSON Outputs

> **Contract alignment**: These docs align to ntask CLI Contract v1.0.0.
> Binary v0.4.0 shipped 2026-02-17 — all documented commands now match the binary.

All commands output JSON by default. No flags needed. The binary path shown
assumes the skill is installed at `<workspace>/skills/notion-task-skill/bin/ntask`.

## Task Summary Fields

Every command that returns a `task` object uses the same field set. Not all fields
are present in every response — only populated fields are included.

| Field                | Type    | Always Present | Description                          |
|----------------------|---------|----------------|--------------------------------------|
| `page_id`            | string  | ✓              | Notion page UUID                     |
| `task_id`            | string  | ✓              | Human-readable task ID (e.g., TASK-42) |
| `status`             | string  | ✓              | Current lifecycle status             |
| `priority`           | number  |                | Numeric priority                     |
| `class`              | string  |                | Expedite/Fixed Date/Standard/Intangible |
| `agent_run`          | string  |                | Current agent's run identifier       |
| `lock_token`         | string  |                | UUID lock token                      |
| `lock_expires`       | string  |                | ISO 8601 lock expiry                 |
| `started_at`         | string  |                | ISO 8601 when work began             |
| `done_at`            | string  |                | ISO 8601 when work completed         |
| `blocker_reason`     | string  |                | Why the task is blocked              |
| `unblock_action`     | string  |                | What needs to happen to unblock      |
| `completed_subtasks` | number  |                | Count of completed sub-tasks         |
| `parent_task_id`     | string  |                | Parent task ID (subtasks only)       |
| `reason`             | string  |                | Cancellation/block reason            |

## doctor

Check environment readiness:

```bash
ntask doctor
```

### Output Fields

| Field | Type | Description |
|-------|------|-------------|
| `checks.notion_cli.found` | boolean | Whether the `ntn` binary is in PATH |
| `checks.notion_cli.version` | string | `ntn` version string (e.g., `"ntn 0.5.23 (commit: ...)"`) |
| `checks.notion_token.available` | boolean | Whether a Notion API token is accessible |
| `checks.notion_token.source` | string | Token source: `"environment"` (env var) or `"system keyring"` (OS keychain) |
| `checks.env_NOTION_TASKS_DB_ID` | boolean | Whether `NOTION_TASKS_DB_ID` env var is set |
| `checks.env_NOTION_AGENT_USER_ID` | boolean | Whether `NOTION_AGENT_USER_ID` env var is set |
| `checks.db_accessible` | boolean | Whether the Notion database is reachable (only checked if token + DB ID are present) |

### Success

```json
{
  "ok": true,
  "checks": {
    "notion_cli": { "found": true, "version": "ntn 0.5.23 (commit: 45ff02c, built: 2026-02-16T05:34:25Z)" },
    "notion_token": { "available": true, "source": "system keyring" },
    "env_NOTION_TASKS_DB_ID": true,
    "env_NOTION_AGENT_USER_ID": true,
    "db_accessible": true
  }
}
```

### Failure (CLI missing)

```json
{
  "ok": false,
  "error": { "code": "MISCONFIGURED", "message": "ntn binary not found in PATH" },
  "checks": {
    "notion_cli": { "found": false },
    "notion_token": { "available": true, "source": "environment" },
    "env_NOTION_TASKS_DB_ID": true,
    "env_NOTION_AGENT_USER_ID": true
  }
}
```

### Failure (missing env vars)

```json
{
  "ok": false,
  "error": { "code": "MISCONFIGURED", "message": "Environment check failed: NOTION_TASKS_DB_ID not configured" },
  "checks": {
    "notion_cli": { "found": true, "version": "ntn 0.5.23 (commit: 45ff02c, built: 2026-02-16T05:34:25Z)" },
    "notion_token": { "available": true, "source": "system keyring" },
    "env_NOTION_TASKS_DB_ID": false,
    "env_NOTION_AGENT_USER_ID": false
  }
}
```

## next

Get the highest-priority ready task:

```bash
ntask next
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "Ready",
    "priority": 2,
    "class": "Standard"
  }
}
```

### No Tasks Available (exit 10)

```json
{
  "ok": false,
  "error": { "code": "NO_TASKS", "message": "No eligible tasks in queue" }
}
```

## claim

Claim a task for this agent run:

```bash
ntask claim PROJ-42
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "In Progress",
    "lock_token": "550e8400-e29b-41d4-a716-446655440000",
    "lock_expires": "2025-01-15T14:50:00Z",
    "agent_run": "run-abc-123"
  }
}
```

### Conflict (exit 20)

```json
{
  "ok": false,
  "error": { "code": "CONFLICT", "message": "Task was claimed by another agent" },
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "In Progress",
    "agent_run": "run-other-456"
  }
}
```

## heartbeat

Extend the lease on a claimed task:

```bash
ntask heartbeat PROJ-42
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "lock_expires": "2025-01-15T15:10:00Z"
  }
}
```

### Lost Lock (exit 21)

```json
{
  "ok": false,
  "error": { "code": "LOST_LOCK", "message": "Lock token does not match; lock was stolen or expired" },
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "agent_run": "run-other-789"
  }
}
```

## block

Mark a task as blocked:

```bash
ntask block PROJ-42 \
  --reason "Waiting for API credentials from vendor" \
  --unblock-action "User must provide API key in project settings"
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "Blocked",
    "blocker_reason": "Waiting for API credentials from vendor",
    "unblock_action": "User must provide API key in project settings"
  }
}
```

## create

Create a new top-level task:

```bash
ntask create --title "Implement auth flow" \
  --priority 2 --class Standard
```

Create an EXPEDITE task (highest priority class — sorts above all other classes):

```bash
ntask create --title "Fix critical auth regression" \
  --priority 1 --class-of-service Expedite
```

```json
{
  "ok": true,
  "task": {
    "page_id": "new-page-id",
    "task_id": "TASK-211",
    "status": "Ready",
    "class": "EXPEDITE",
    "priority": 1
  }
}
```

> **Note**: The `--class-of-service` flag accepts case-insensitive values:
> `Expedite`, `expedite`, `EXPEDITE` all work. The JSON output uses
> SCREAMING_SNAKE (`EXPEDITE`, `STANDARD`, etc.).

Create a subtask linked to a parent:

```bash
ntask create --title "Setup OAuth provider" \
  --parent "TASK-99" --priority 2 --class Standard
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "new-page-id",
    "task_id": "TASK-100",
    "status": "Backlog",
    "parent_task_id": "TASK-99"
  }
}
```

## list

List all tasks:

```bash
ntask list
```

List only Ready tasks:

```bash
ntask list --status Ready --limit 10
```

### Success

```json
{
  "ok": true,
  "tasks": [
    {
      "page_id": "abc123",
      "task_id": "PROJ-42",
      "status": "Ready",
      "priority": 2
    },
    {
      "page_id": "def456",
      "task_id": "PROJ-43",
      "status": "Ready",
      "priority": 1
    }
  ],
  "count": 2
}
```

## get

Get full details of a task:

```bash
ntask get PROJ-42
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "Ready",
    "priority": 2,
    "class": "Standard"
  }
}
```

## comment

Add a comment to a task:

```bash
ntask comment PROJ-42 --text "Started investigating OAuth provider options"
```

### Success

```json
{
  "ok": true,
  "task_id": "PROJ-42",
  "comment": "Started investigating OAuth provider options"
}
```

## review

Move a task to Review for human inspection:

```bash
ntask review PROJ-42 --summary "Implemented OAuth provider integration with token refresh"
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "Review"
  }
}
```

## approve

Approve a reviewed task:

```bash
ntask approve PROJ-42
```

With an approval summary:

```bash
ntask approve PROJ-42 --summary "LGTM, clean implementation"
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "Done",
    "done_at": "2026-02-11T10:00:00Z"
  }
}
```

### Wrong Status

```json
{
  "ok": false,
  "error": { "code": "MISCONFIGURED", "message": "Task must be in Review status to approve (current: In Progress)" },
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "In Progress"
  }
}
```

## rework

Send a reviewed task back for rework:

```bash
ntask rework PROJ-42 --reason "Needs markdown formatting in README"
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "In Progress",
    "reason": "Needs markdown formatting in README"
  }
}
```

### Wrong Status

```json
{
  "ok": false,
  "error": { "code": "MISCONFIGURED", "message": "Task must be in Review status to rework (current: Done)" },
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "Done"
  }
}
```

## cancel

Cancel a task:

```bash
ntask cancel PROJ-42 \
  --reason "Requirements changed, feature no longer needed"
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "Canceled",
    "reason": "Requirements changed, feature no longer needed"
  }
}
```

## update

Update task priority:

```bash
ntask update PROJ-42 --priority 3
```

Unblock a task (move from Blocked to In Progress):

```bash
ntask unblock PROJ-42
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "Ready",
    "priority": 3,
    "class": "Standard"
  }
}
```

## version

Print version information:

```bash
ntask version
```

### Success

```json
{
  "ok": true,
  "version": "0.1.0"
}
```
