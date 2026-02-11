# Agent Workflow

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
                    ┌────▼─────┐    null    ┌──────────┐
              ┌────►│   next   ├───────────►│  wait &  │
              │     └────┬─────┘            │  retry   │
              │          │ task found       └──────────┘
              │     ┌────▼─────┐
              │     │  claim   │
              │     └────┬─────┘
              │          │ claimed
              │     ┌────▼─────────────┐
              │     │   work loop      │
              │     │  (heartbeat)     │
              │     └──┬────┬────┬─────┘
              │        │    │    │
              │   ┌────▼┐ ┌▼───┐│┌──────┐┌──────┐
              │   │done │ │blck│││review││cancel│
              │   └──┬──┘ └─┬──┘│└──┬───┘└──┬───┘
              │      │      │   │   │       │
              └──────┴──────┴───┴───┴───────┘
                      loop back to next
```

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

If any check fails (exit code 3), surface the issue to the user. Do not proceed.

### 2. Next (find a task)

```bash
ntask next
```

- **Task found:** proceed to claim.
- **No tasks (`task: null`):** wait and retry using the backoff schedule below.

**Next retry schedule (no tasks available):**

| Attempt | Wait    |
|---------|---------|
| 1       | 30s     |
| 2       | 60s     |
| 3       | 120s    |
| 4       | 240s    |
| 5       | Surface to user: "No tasks available" |

### 3. Claim

```bash
ntask claim <task-id> --run-id <run-id> --agent-name <name> --lease-min 20
```

- **Success:** save the `lock_token` and `lock_expires` from the response.
- **CONFLICT (exit 2):** immediately re-run `next` for a different task. Do not retry the same task.
- **API_ERROR (exit 5):** Retry the same claim up to 3× with 2s/4s/8s backoff
  (you don't yet hold a lock, so retrying is safe). If all retries fail, fall
  back to `next` for a different task.

### 4. Work Loop

Perform the work described in the task's sub-tasks.

**During work, heartbeat on a fixed cadence:**

```bash
ntask heartbeat <task-id> --run-id <run-id> --lock-token <token> --lease-min 20
```

**Heartbeat cadence:** every `lease_min / 2` minutes (default: every 10 minutes).

- **Success:** continue working. Note the updated `lock_expires`.
- **LOST_LOCK (exit 4):** **stop work immediately**. Run `next` to get a new task.
- **API_ERROR (exit 5):** follow the API error retry policy. If all retries fail, stop work and run `next`.

### 5a. Complete (work succeeded)

```bash
ntask complete <task-id> --run-id <run-id> --lock-token <token>
```

After completion, loop back to step 2 (`next`).

### 5b. Block (work cannot proceed)

```bash
ntask block <task-id> --run-id <run-id> --lock-token <token> \
  --reason "<why>" --unblock-action "<what needs to happen>"
```

Optionally include `--next-check <ISO8601>` to suggest when to revisit.

After blocking, loop back to step 2 (`next`).

## Error Recovery Matrix

| Exit Code | Error          | Agent Action                                         |
|-----------|----------------|------------------------------------------------------|
| 0         | (none)         | Parse JSON, continue                                 |
| 2         | CONFLICT       | Run `next` for a different task                      |
| 3         | MISCONFIGURED  | Run `doctor`, surface issue to user                  |
| 4         | LOST_LOCK      | Stop current work, run `next`                        |
| 5         | API_ERROR      | Retry 3x (2s/4s/8s backoff), then `block` the task  |

## API Error Retry Policy

For any exit code 5 (API_ERROR):

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

# 3. Work subtasks via the normal claim→work→complete loop
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
- `ntask review PROJ-42 ...` — request human review instead of completing
- `ntask cancel PROJ-42 ...` — abandon if requirements changed

## Key Rules

1. **Never retry a CONFLICT.** Always get a fresh task via `next`.
2. **Never continue work after LOST_LOCK.** Another agent may have claimed the task.
3. **Always heartbeat during work.** A missed heartbeat lets other agents steal the lock.
4. **Always include reason + unblock_action on block.** This tells humans what to fix.
5. **Always include reason on cancel.** Explains why work was abandoned.
6. **Decompose complex tasks.** Use `create --parent` to break work into subtasks.
7. **Record idempotency keys for side effects.** Write `Agent Run` value to task comments before triggering external actions.
