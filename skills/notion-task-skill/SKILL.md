---
name: notion-task-skill
description: >
  Manage Notion-backed tasks via the ntask CLI. All task operations are
  performed exclusively by executing the ntask binary—never by calling the
  Notion API directly or editing tasks through other tools.
version: 0.1.0
author: openclaw-skills
tags:
  - notion
  - tasks
  - project-management
---

# Notion Task Skill

This skill gives an OpenClaw agent the ability to pull, claim, work on, and
complete tasks stored in a Notion database. Every interaction with Notion goes
through the **ntask** command-line tool, ensuring deterministic, auditable,
JSON-only communication.

## How to Use This Skill

### The Only Allowed Task Operations

All task operations **MUST** be performed by running the `ntask` binary located
at the skill's `bin/` directory:

```bash
<workspace>/skills/notion-task-skill/bin/ntask <command> [flags]
```

**You MUST NOT:**
- Directly edit Notion tasks using other tools, APIs, or browser automation.
- Parse or construct Notion API payloads yourself.
- Modify task properties outside of ntask commands.

### Available Commands

| Command     | Purpose                                        |
|-------------|------------------------------------------------|
| `doctor`    | Validate environment, credentials, and CLI     |
| `next`      | Get the highest-priority ready task            |
| `claim`     | Lock a task for this agent run                 |
| `heartbeat` | Extend the lock lease on a claimed task        |
| `complete`  | Mark a task as DONE and record artifacts       |
| `block`     | Mark a task as BLOCKED with reason             |
| `create`    | Create a new task or subtask                   |
| `list`      | List tasks with optional status filter         |
| `get`       | Get full details of a specific task            |
| `comment`   | Add a comment to a task                        |
| `review`    | Move task to REVIEW for human inspection       |
| `cancel`    | Cancel a task with reason                      |
| `update`    | Update task properties (priority, status, etc) |
| `version`   | Print version information                      |

### Lock Rule

All status-changing commands that transition a task through the work lifecycle
require a valid lock token (`--run-id` + `--lock-token`): **claim**, **heartbeat**,
**complete**, **block**, **review**, and **cancel**. Commands that do not require a
lock: **doctor**, **next**, **create**, **list**, **get**, **comment**, **update**,
and **version**.

### Output Contract

Every command **always** prints JSON to stdout. No flags needed. No logs, no human text.

- **Success:** `{ "ok": true, ... }`
- **Error:** `{ "ok": false, "error": { "code": "...", "message": "..." }, "task": <optional> }`

### Error Handling

| Exit Code | Meaning        | Agent Action                                         |
|-----------|----------------|------------------------------------------------------|
| 0         | Success        | Parse JSON, proceed                                  |
| 2         | CONFLICT       | Run `next` for a different task                      |
| 3         | MISCONFIGURED  | Run `doctor`, surface issue to user                  |
| 4         | LOST_LOCK      | Stop current work, run `next`                        |
| 5         | API_ERROR      | Retry 3x (2s/4s/8s backoff), then `block` the task  |

**On CONFLICT or LOST_LOCK:** always re-run `next` to obtain a fresh task or
surface the issue to the user. Never retry the same claim blindly.

### Always Parse JSON Output

Every response from ntask is structured JSON. Always parse it programmatically.
Do not attempt to regex-match or string-split the output.

## References

- **[Workflow](references/workflow.md)** — Full agent lifecycle, retry policy, error recovery matrix
- **[Task Schema](references/schema.md)** — Required Notion database properties
- **[Pull Policy](references/pull_policy.md)** — Deterministic task selection and locking rules
- **[Examples](references/examples.md)** — Example command lines and JSON outputs
- **[First-Run Setup](references/prereqs.md)** — Complete walkthrough from install to first task
