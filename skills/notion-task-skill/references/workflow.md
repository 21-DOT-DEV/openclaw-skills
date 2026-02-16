# Agent Workflow

> **Contract alignment**: These docs align to ntask CLI Contract v1.0.0.
> Binary update pending in Phase 1 Feature 1. Worker crons should remain
> disabled until the binary ships.

This document defines the complete agent lifecycle for working with Notion tasks
via the `ntask` CLI.

## Before You Start

Before entering the work loop, run through the triage checklist in
[task-triage.md](task-triage.md). The triage ensures you're working on
the right task, with clear criteria, and appropriate scope.

Flow: **triage (think) → workflow (execute)**

## Lifecycle State Machine

```
                    ┌──────────┐
                    │  doctor  │
                    └────┬─────┘
                         │ ok
                    ┌────▼─────┐  exit 10   ┌──────────┐
                    │   next   ├──────────►│   stop   │
                    └────┬─────┘            └──────────┘
                         │ task found
                    ┌────▼─────┐
                    │  claim   │
                    └────┬─────┘
                         │ claimed
                    ┌────▼─────────────┐
                    │   work loop      │
                    │  (heartbeat)     │
                    └──┬──────┬────┬─────┘
                       │      │    │
                  ┌────▼┐ ┌─▼──┐┌▼──────┐
                  │blck │ │rvw ││cancel│
                  └──┬──┘ └─┬──┘└──┬───┘
                     │      │      │
                     └──────┴──────┘
                        stop (one task per run)
```

> **Worker agents**: one task per run. Do not loop back for more tasks.

**Additional commands available at any time:**
- `list` — see available tasks
- `get` — read task details
- `create` — create tasks or subtasks (planning/decomposition)
- `comment` — add notes to any task
- `update` — change priority, status, or other properties

## Step-by-Step

### 1. Doctor (once per session)

```bash
ntask doctor
```

If any check fails (exit code 40 = MISCONFIGURED), surface the issue to the user. Do not proceed.

### 2. Next (find a task)

```bash
ntask next
```

- **Task found (exit 0):** proceed to claim.
- **No tasks (exit 10 = NO_TASKS):** exit cleanly — idle run, no error. Worker agents stop here (one task per run).

### 3. Claim

```bash
ntask claim <task-id>
```

Lock token, agent run UUID, and lease (default 15 minutes) are set internally by ntask.

- **Success:** the response includes `lock_token` and `lock_expires`.
- **CONFLICT (exit 20):** immediately re-run `next` for a different task. Do not retry the same task.
- **API_ERROR (exit 30):** Retry the same claim up to 3× with exponential backoff
  (you don't yet hold a lock, so retrying is safe). If all retries fail, fall
  back to `next` for a different task.
- **MISCONFIGURED (exit 40):** run `ntask doctor`, surface issue to user.

### 4. Work Loop

Perform the work described in the task's sub-tasks.

**During work, heartbeat on a fixed cadence:**

```bash
ntask heartbeat <task-id>
```

**Heartbeat cadence:** every 7 minutes (half of the default 15-minute lease).

- **Success:** continue working. Note the updated `lock_expires`.
- **LOST_LOCK (exit 21):** **stop work immediately**. Run `next` to get a new task.
- **API_ERROR (exit 30):** follow the API error retry policy. If all retries fail, stop work and run `next`.

### 5a. Review (work succeeded)

Workers always submit via `ntask review` — direct completion is not available.

```bash
ntask review <task-id> --summary "<what was done>"
```

- **Success:** task moves to Review. Lock is released. Worker stops (one task per run).
- **INCOMPLETE_SUBTASKS (exit 41):** stop, report to human — sub-tasks not all complete.
- **LOST_LOCK (exit 21):** stop work immediately.
- **API_ERROR (exit 30):** follow the API error retry policy.

### 5b. Block (work cannot proceed)

```bash
ntask block <task-id> --reason "<why>" --unblock-action "<what needs to happen>"
```

After blocking, worker stops (one task per run).

### 5c. Cancel (requirements changed)

```bash
ntask cancel <task-id> --reason "<why>"
```

Conditional lock: required from In Progress, lock-free from other statuses.
After canceling, worker stops (one task per run).

### 5d. Post-Review (human-driven, no lock required)

A human reviews the task and runs one of:

```bash
ntask approve <task-id>                          # Review → Done
ntask approve <task-id> --summary "LGTM"         # with comment
ntask rework <task-id> --reason "<feedback>"     # Review → In Progress
```

- **approve**: Marks the task Done. No sub-task guard — reviewer authority overrides.
- **rework**: Moves back to In Progress (no lock) with a comment. Agent must re-claim via `ntask claim <task-id>` to resume work.

## Error Recovery Matrix

| Exit Code | Error                | Agent Action                                         |
|-----------|----------------------|------------------------------------------------------|
| 0         | SUCCESS              | Parse JSON, continue                                 |
| 10        | NO_TASKS             | Exit cleanly — idle run, no error                    |
| 20        | CONFLICT             | Run `next` for a different task                      |
| 21        | LOST_LOCK            | Stop current work, run `next`                        |
| 30        | API_ERROR            | Retry 3× (exponential backoff), then `block` the task |
| 40        | MISCONFIGURED        | Run `doctor`, surface issue to user                  |
| 41        | INCOMPLETE_SUBTASKS  | Stop, report to human                                |

**Unknown exit codes:** treat as API_ERROR (transient, retry with backoff) and log a warning.

## API Error Retry Policy

For any exit code 30 (API_ERROR):

| Attempt | Wait Before Retry |
|---------|-------------------|
| 1       | 2 seconds         |
| 2       | 4 seconds         |
| 3       | 8 seconds         |

After 3 failed retries:
- If holding a task lock: `block` the task with reason "Repeated API failures after 3 retries"
- If not holding a lock (e.g., during `next`): surface the error to the user

**Rate limits:** The Notion API enforces 3 requests/second. HTTP 429 (Too Many
Requests) is a common cause of API_ERROR. The backoff schedule above handles
this automatically.

## Idempotency

If a task triggers external side effects (deployments, API calls, emails), the
agent **should** record an idempotency key in a task comment
before performing the action. Use the `Agent Run` value as the key. This prevents
duplicate side effects if the agent retries or another agent picks up the same
task.

```bash
# Before triggering a deployment:
ntask comment PROJ-42 --text "Deploying with idempotency key: run-abc-123"
# Then perform the deployment
```

## Planning & Decomposition

When a task is too complex for a single work session, decompose it into subtasks:

```bash
# 1. Read the parent task
ntask get PROJ-42

# 2. Create subtasks with --parent
ntask create --title "Design auth schema" \
  --parent "TASK-42" --priority 2

ntask create --title "Implement auth endpoints" \
  --parent "TASK-42" --priority 2

# 3. Work subtasks via the normal claim→work→review loop
# 4. Parent's Dependencies rollup tracks completion
```

**When to decompose:**
- Task contains multiple independent deliverables
- Estimated work exceeds a single agent session
- Task requires sequential phases (design → implement → test)

**Other useful commands during work:**
- `ntask list --status 'In Progress'` — see what's in flight
- `ntask comment PROJ-42 --text "Progress update: ..."` — leave audit trail
- `ntask update PROJ-42 --priority 3` — re-prioritize if needed
- `ntask review PROJ-42 --summary "..."` — submit for human review
- `ntask cancel PROJ-42 --reason "..."` — abandon if requirements changed

## Key Rules

1. **Never retry a CONFLICT.** Always get a fresh task via `next`.
2. **Never continue work after LOST_LOCK.** Another agent may have claimed the task.
3. **Always heartbeat during work.** A missed heartbeat lets other agents steal the lock.
4. **Always include reason + unblock_action on block.** This tells humans what to fix.
5. **Always include reason on cancel.** Explains why work was abandoned.
6. **Decompose complex tasks.** Use `create --parent` to break work into subtasks.
7. **Record idempotency keys for side effects.** Write `Agent Run` value to task comments before triggering external actions.
