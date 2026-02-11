# Pull Policy — Deterministic Task Selection and Locking

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
   - `Lock Expires` → now + lease duration (default 20 minutes)
   - `Started At` → now (if property exists)
3. **Verify the claim** by re-reading the page immediately after update.
4. If the re-read shows a **different** `Lock Token`, return `CONFLICT`.
   Another agent claimed the task first.

### Heartbeat (heartbeat)

1. Read the page and verify `Lock Token` matches the provided token.
2. If token does not match → return `LOST_LOCK`.
3. If token matches, update:
   - `Lock Expires` → now + lease duration (default 20 minutes)
4. Return success with the new expiry time.

### Complete (complete)

1. Read the page and verify `Lock Token` matches the provided token.
2. If token does not match → return `LOST_LOCK`.
3. Update properties:
   - `Status` → `Done`
   - `Done At` → now (if property exists)
   - Clear lock fields (set to null/empty):
     - `Agent Run` → `""` (empty string)
     - `Lock Token` → `""` (empty string)
     - `Lock Expires` → null (clear the Date)
4. Return success.

### Block (block)

1. Read the page and verify `Lock Token` matches the provided token.
2. If token does not match → return `LOST_LOCK`.
3. Update properties:
   - `Status` → `Blocked`
   - `Blocker Reason` → provided reason
   - `Unblock Action` → provided unblock action
   - `Next Check At` → provided ISO 8601 timestamp (optional)
   - Clear lock fields (set to null/empty):
     - `Agent Run` → `""` (empty string)
     - `Lock Token` → `""` (empty string)
     - `Lock Expires` → null (clear the Date)
4. Return success.

### Review (review)

1. Read the page and verify `Lock Token` matches the provided token.
2. If token does not match → return `LOST_LOCK`.
3. Update properties:
   - `Status` → `Review`
   - Clear lock fields (set to null/empty):
     - `Agent Run` → `""` (empty string)
     - `Lock Token` → `""` (empty string)
     - `Lock Expires` → null (clear the Date)
4. Return success.

### Cancel (cancel)

1. Read the page and verify `Lock Token` matches the provided token.
2. If token does not match → return `LOST_LOCK`.
3. Update properties:
   - `Status` → `Canceled`
   - `Blocker Reason` → provided reason
   - Clear lock fields (set to null/empty):
     - `Agent Run` → `""` (empty string)
     - `Lock Token` → `""` (empty string)
     - `Lock Expires` → null (clear the Date)
4. Return success.

## Error Codes

| Code           | Exit | Meaning                                           |
|----------------|------|---------------------------------------------------|
| SUCCESS        | 0    | Operation completed successfully                  |
| CONFLICT       | 2    | Another agent claimed the task; re-run `next`     |
| MISCONFIGURED  | 3    | Missing env vars, bad database schema, or missing/misnamed properties |
| CLI_MISSING    | 3    | `notion` binary not found in PATH                 |
| LOST_LOCK      | 4    | Lock token mismatch; lock was stolen or expired   |
| API_ERROR      | 5    | Notion API call failed (network, rate limit, etc) |

## Invariants

- A task MUST NOT be worked on without a valid, verified lock.
- Lock verification MUST re-read the page — never trust cached state.
- On CONFLICT: the agent must run `next` again to find a different task.
- On LOST_LOCK: the agent must either run `next` for a new task or surface
  the issue to the user.
- Lease duration defaults to 20 minutes. Agents should heartbeat well before
  expiry (e.g., every 10 minutes).
