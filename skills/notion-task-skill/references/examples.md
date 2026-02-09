# Examples — ntask Command Lines and JSON Outputs

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
| `class`              | string  |                | EXPEDITE/FIXED_DATE/STANDARD/INTANGIBLE |
| `claimed_by`         | string  |                | AGENT or HUMAN                       |
| `agent_run`          | string  |                | Current agent's run identifier       |
| `agent`              | string  |                | Current agent's name                 |
| `lock_token`         | string  |                | UUID lock token                      |
| `lock_expires`       | string  |                | ISO 8601 lock expiry                 |
| `parent_task_id`     | string  |                | Parent task ID (subtasks only)       |
| `reason`             | string  |                | Cancellation/block reason            |

## doctor

Check environment readiness:

```bash
ntask doctor
```

### Success

```json
{
  "ok": true,
  "checks": {
    "notion_cli": { "found": true, "version": "0.6.0" },
    "notion_token": { "available": true, "source": "environment" },
    "env_NOTION_TASKS_DB_ID": true,
    "db_accessible": true
  }
}
```

### Failure (CLI missing)

```json
{
  "ok": false,
  "error": { "code": "CLI_MISSING", "message": "notion binary not found in PATH" },
  "checks": {
    "notion_cli": { "found": false },
    "notion_token": { "available": true, "source": "environment" },
    "env_NOTION_TASKS_DB_ID": true
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
    "status": "READY",
    "priority": 8,
    "class": "STANDARD"
  }
}
```

### No Tasks Available

```json
{
  "ok": true,
  "task": null,
  "message": "No ready tasks found"
}
```

## claim

Claim a task for this agent run:

```bash
ntask claim PROJ-42 \
  --run-id "run-abc-123" \
  --agent-name "coding-agent-1" \
  --lease-min 20
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "IN_PROGRESS",
    "lock_token": "550e8400-e29b-41d4-a716-446655440000",
    "lock_expires": "2025-01-15T14:50:00Z",
    "claimed_by": "AGENT",
    "agent_run": "run-abc-123",
    "agent": "coding-agent-1"
  }
}
```

### Conflict

```json
{
  "ok": false,
  "error": { "code": "CONFLICT", "message": "Task was claimed by another agent" },
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "IN_PROGRESS",
    "claimed_by": "AGENT",
    "agent_run": "run-other-456"
  }
}
```

## heartbeat

Extend the lease on a claimed task:

```bash
ntask heartbeat PROJ-42 \
  --run-id "run-abc-123" \
  --lock-token "550e8400-e29b-41d4-a716-446655440000" \
  --lease-min 20
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

### Lost Lock

```json
{
  "ok": false,
  "error": { "code": "LOST_LOCK", "message": "Lock token does not match; lock was stolen or expired" },
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "claimed_by": "AGENT",
    "agent_run": "run-other-789"
  }
}
```

## complete

Mark a task as done:

```bash
ntask complete PROJ-42 \
  --run-id "run-abc-123" \
  --lock-token "550e8400-e29b-41d4-a716-446655440000" \
  --artifacts "PR #123 merged, deployed to staging"
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "DONE",
    "done_at": "2025-01-15T15:05:00Z"
  }
}
```

## block

Mark a task as blocked:

```bash
ntask block PROJ-42 \
  --run-id "run-abc-123" \
  --lock-token "550e8400-e29b-41d4-a716-446655440000" \
  --reason "Waiting for API credentials from vendor" \
  --unblock-action "User must provide API key in project settings" \
  --next-check "2025-01-16T10:00:00Z"
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "BLOCKED",
    "blocker_reason": "Waiting for API credentials from vendor",
    "unblock_action": "User must provide API key in project settings",
    "next_check_at": "2025-01-16T10:00:00Z"
  }
}
```

## create

Create a new top-level task:

```bash
ntask create --title "Implement auth flow" \
  --priority 8 --class-of-service STANDARD
```

Create a subtask linked to a parent:

```bash
ntask create --title "Setup OAuth provider" \
  --parent "TASK-99" --priority 8 --class-of-service STANDARD
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "new-page-id",
    "task_id": "TASK-100",
    "status": "READY",
    "parent_task_id": "TASK-99"
  }
}
```

## list

List all tasks:

```bash
ntask list
```

List only READY tasks:

```bash
ntask list --status READY --limit 10
```

### Success

```json
{
  "ok": true,
  "tasks": [
    {
      "page_id": "abc123",
      "task_id": "PROJ-42",
      "status": "READY",
      "priority": 8
    },
    {
      "page_id": "def456",
      "task_id": "PROJ-43",
      "status": "READY",
      "priority": 5
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
    "status": "READY",
    "priority": 8,
    "class": "STANDARD"
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

Move a task to REVIEW for human inspection:

```bash
ntask review PROJ-42 --run-id "run-abc-123" \
  --lock-token "550e8400-e29b-41d4-a716-446655440000" \
  --artifacts "PR #456 ready for review"
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "REVIEW",
    "artifacts": "PR #456 ready for review"
  }
}
```

## cancel

Cancel a task:

```bash
ntask cancel PROJ-42 --run-id "run-abc-123" \
  --lock-token "550e8400-e29b-41d4-a716-446655440000" \
  --reason "Requirements changed, feature no longer needed"
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "CANCELED",
    "reason": "Requirements changed, feature no longer needed"
  }
}
```

## update

Update task priority:

```bash
ntask update PROJ-42 --priority 10
```

Unblock a task (move from BLOCKED to READY):

```bash
ntask update PROJ-42 --status READY
```

### Success

```json
{
  "ok": true,
  "task": {
    "page_id": "abc123-def456",
    "task_id": "PROJ-42",
    "status": "READY",
    "priority": 10,
    "class": "STANDARD"
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
