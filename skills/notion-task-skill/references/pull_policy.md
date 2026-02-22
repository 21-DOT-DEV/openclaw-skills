# Pull Policy — Deterministic Task Selection and Locking

> **Contract alignment**: These docs align to ntask CLI Contract v1.0.0.
> Binary v0.4.0 shipped 2026-02-17 — all documented commands now match the binary.

This document defines exactly how ntask selects, claims, and manages tasks.
These rules are **deterministic** — given the same database state, every agent
must make the same selection.

## Task Selection (next)

### Filter Criteria

A task is eligible for selection when **all** of the following are true:

1. **Status** equals `Ready`
2. **Lock is empty or expired:**
   - `Lock Token` is empty, **OR**
   - `Lock Expires` is empty or in the past (lock expired or inconsistent state)

That's it — no sub-task or dependency checks at claim time. Sub-task completion
is enforced at `done` time via the Dependencies rollup.

**Edge case — inconsistent state:** If `Lock Token` is set but `Lock Expires` is
empty, the task is treated as claimable (expired lock). This can happen if a
previous operation failed mid-update. The claiming agent should note this in the
task's comments for auditability.

### Sort Order (Deterministic)

Eligible tasks are sorted by the following keys, in order:

1. **Class rank** (ascending — lower rank = higher priority):
   - Expedite (1) > Fixed Date (2) > Standard (3) > Intangible (4)
   - Tasks missing Class are treated as Standard (rank 3)
2. **Priority** (descending — higher number = more urgent)
3. **Last edited time** (ascending — oldest-edited first, to prevent starvation)

The **first** task after sorting is returned by `ntask next`.

## Claim Protocol

### Claiming a Task (claim)

1. Generate a UUID v4 `Lock Token`.
2. Set the following properties atomically:
   - `Status` → `In Progress`
   - `Assignee` → agent's Notion user (from `NOTION_AGENT_USER_ID` env var)
   - `Agent Run` → provided run ID
   - `Lock Token` → generated token
   - `Lock Expires` → now + lease duration (default 15 minutes)
   - `Started At` → now (if property exists)
3. **Verify the claim** by re-reading the page immediately after update.
4. If the re-read shows a **different** `Lock Token`, return `CONFLICT`.
   Another agent claimed the task first.

### Heartbeat (heartbeat)

1. Read the page and verify `Lock Token` matches the stored token.
2. If token does not match → return `LOST_LOCK`.
3. If token matches, update:
   - `Lock Expires` → now + lease duration (default 15 minutes)
4. Return success with the new expiry time.

### Block (block)

1. Read the page and verify `Lock Token` matches the stored token.
2. If token does not match → return `LOST_LOCK`.
3. Update properties:
   - `Status` → `Blocked`
   - `Blocker Reason` → provided reason
   - `Unblock Action` → provided unblock action
   - Lock remains until natural expiry (not cleared on block).
4. Return success.

### Block → Unblock Lifecycle

> **Since v0.4.0 (2026-02-17)**: The `ntask unblock` command is fully implemented.

The block/unblock lifecycle allows agents to pause work when encountering obstacles
(missing requirements, external blockers, ambiguous acceptance criteria) and later
resume from the exact same state.

#### Block Command

**Lock required.** Transitions `In Progress → Blocked`.

```bash
ntask block <task-id> --reason "Missing API credentials" --unblock-action "Add credentials to .env"
```

**Behavior:**
1. Verifies lock ownership (returns `LOST_LOCK` if token mismatch)
2. Sets `Status` to `Blocked`
3. Sets `Blocker Reason` (required, describes the obstacle)
4. Sets `Unblock Action` (required, describes what's needed to proceed)
5. **Retains the lock** until natural expiry (not cleared on block)
6. Task remains assigned to the agent but is filtered out of `ntask next` results

**Fields set:**
- `Status`: `Blocked`
- `Blocker Reason`: provided reason text
- `Unblock Action`: provided action text
- Lock fields (`Lock Token`, `Lock Expires`, `Agent Run`) remain unchanged

#### Unblock Command

**No lock required.** Transitions `Blocked → In Progress`.

```bash
ntask unblock <task-id>
```

**Behavior:**
1. Validates `Status` is `Blocked` (returns `MISCONFIGURED` otherwise)
2. Sets `Status` to `In Progress`
3. **Preserves** `Blocker Reason` and `Unblock Action` as audit trail
4. Does **not** acquire a lock — task is In Progress but unlocked
5. Agent must re-claim to resume work

**Fields preserved:**
- `Blocker Reason`: kept for audit trail
- `Unblock Action`: kept for audit trail

**Fields changed:**
- `Status`: `In Progress`

> **Legacy workaround (pre-v0.4.0)**: `ntask update <id> --status Ready` was used to
> manually unblock. This still works but is no longer the canonical path.

#### Re-claim Requirement

After unblock, the task is `In Progress` but has **no active lock**. The agent
(or a different agent) must re-claim before resuming work:

```bash
ntask claim <task-id>
```

This re-acquires the lock, assigns the task, and allows work to continue. The
prior `Blocker Reason` and `Unblock Action` remain visible in the task properties
as context.

#### Full Lifecycle Example

```bash
# Agent claims task
ntask claim TASK-123
# → Status: In Progress, Lock acquired

# Agent encounters blocker (missing acceptance criteria)
ntask block TASK-123 \
  --reason "Missing Acceptance Criteria (standing rule)" \
  --unblock-action "Add AC defining done state"
# → Status: Blocked, Lock retained

# ...time passes, Chris adds Acceptance Criteria...

# Unblock (lock-free operation, can be run by anyone)
ntask unblock TASK-123
# → Status: In Progress, no lock

# Re-claim to resume work
ntask claim TASK-123
# → Status: In Progress, Lock re-acquired

# Complete work and submit for review
ntask review TASK-123 --summary "Completed all AC items"
# → Status: Review, Lock released
```

#### State Machine Diagram

```
┌─────────┐
│  Ready  │◄──────────────────────────┐
└────┬────┘                           │
     │ claim                          │ rework
     ▼                                │
┌──────────────┐  block        ┌─────┴─────┐
│ In Progress  │──────────────►│  Blocked  │
│  (locked)    │               │ (locked)* │
└──────┬───────┘               └─────┬─────┘
       │                             │
       │ review                      │ unblock
       ▼                             ▼
   ┌────────┐                ┌──────────────┐
   │ Review │                │ In Progress  │
   └────┬───┘                │ (unlocked)** │
        │                    └──────┬───────┘
        │ approve                   │
        ▼                           │ claim
    ┌──────┐                        │
    │ Done │                        │
    └──────┘                        │
                                    │
                                    └──────────┐
                                               │
         ┌─────────────────────────────────────┘
         │ (re-claim to resume work)
         ▼
    (back to In Progress, locked)

* Lock retained during block
** After unblock, lock is cleared — must re-claim
```

> **Important**: `Blocker Reason` and `Unblock Action` are preserved through the unblock
> transition as audit trail — they are only overwritten if `block` is called again.

### Review (review)

1. Read the page and verify `Lock Token` matches the stored token.
2. If token does not match → return `LOST_LOCK`.
3. Check sub-task completion guard: if `Completed Sub-tasks < Dependencies` → return `INCOMPLETE_SUBTASKS`.
4. Update properties:
   - `Status` → `Review`
   - `Summary` → provided summary text
   - Clear lock fields (set to null/empty):
     - `Agent Run` → `""` (empty string)
     - `Lock Token` → `""` (empty string)
     - `Lock Expires` → null (clear the Date)
5. Return success.

### Approve (approve) — no lock required

1. Read the page and validate `Status` is `Review`.
2. If status is not Review → return `MISCONFIGURED`.
3. Update properties:
   - `Status` → `Done`
   - `Done At` → now
   - Clear lock fields (set to null/empty):
     - `Agent Run` → `""` (empty string)
     - `Lock Token` → `""` (empty string)
     - `Lock Expires` → null (clear the Date)
4. If `--summary` provided, add a comment with the summary text.
5. Return success.

No sub-task completion guard — reviewer authority overrides mechanical checks.

### Rework (rework) — no lock required

1. Read the page and validate `Status` is `Review`.
2. If status is not Review → return `MISCONFIGURED`.
3. Update properties:
   - `Status` → `In Progress`
   - Clear lock fields (set to null/empty):
     - `Agent Run` → `""` (empty string)
     - `Lock Token` → `""` (empty string)
     - `Lock Expires` → null (clear the Date)
4. Add a comment with the `--reason` text (always, since reason is required).
5. Return success.

The task moves to In Progress with no active lock. Agent must re-claim via `ntask claim <task-id>` to resume work.

### Cancel (cancel) — conditional lock

Cancel from In Progress requires lock verification. Cancel from other non-terminal
statuses (Blocked, Needs Help, Review, Ready, Backlog) is lock-free.

1. If task is In Progress: verify `Lock Token` matches the stored token.
   If token does not match → return `LOST_LOCK`.
2. Update properties:
   - `Status` → `Canceled`
   - `Blocker Reason` → provided reason
   - Clear lock fields (set to null/empty):
     - `Agent Run` → `""` (empty string)
     - `Lock Token` → `""` (empty string)
     - `Lock Expires` → null (clear the Date)
4. Return success.

## Error Codes

| Code                | Exit | Meaning                                           |
|---------------------|------|---------------------------------------------------|
| SUCCESS             | 0    | Operation completed successfully                  |
| NO_TASKS            | 10   | No eligible tasks in queue (clean exit)           |
| CONFLICT            | 20   | Another agent claimed the task; re-run `next`     |
| LOST_LOCK           | 21   | Lock token mismatch; lock was stolen or expired   |
| API_ERROR           | 30   | Notion API call failed (network, rate limit, etc) |
| MISCONFIGURED       | 40   | Missing env vars, bad database schema, CLI missing, or missing/misnamed properties |
| INCOMPLETE_SUBTASKS | 41   | Sub-task completion guard failed                  |

## Invariants

- A task MUST NOT be worked on without a valid, verified lock.
- Lock verification MUST re-read the page — never trust cached state.
- On CONFLICT: the agent must run `next` again to find a different task.
- On LOST_LOCK: the agent must either run `next` for a new task or surface
  the issue to the user.
- Lease duration defaults to 15 minutes. Agents should heartbeat well before
  expiry (e.g., every 7 minutes).
