# Pull Policy — Deterministic Task Selection and Locking

This document defines exactly how ntask selects, claims, and manages tasks.
These rules are **deterministic** — given the same database state, every agent
must make the same selection.

## Task Selection (next)

### Filter Criteria

A task is eligible for selection when **all** of the following are true:

1. **Status** equals `READY`
2. **ClaimedBy** is NOT `HUMAN` (human-claimed tasks are never auto-pulled,
   regardless of `LockedUntil`)
3. **Lock is empty or expired:**
   - `ClaimedBy` is empty, **OR**
   - `LockedUntil` is empty or in the past (lock expired or inconsistent state)
4. **AcceptanceCriteria** is present and non-empty
5. **DependenciesOpenCount** equals `0`

**Edge case — inconsistent state:** If `ClaimedBy` is `AGENT` but `LockedUntil` is
empty, the task is treated as claimable (expired lock). This can happen if a
previous operation failed mid-update. The claiming agent should note this in the
task's comments for auditability.

### Sort Order (Deterministic)

Eligible tasks are sorted by the following keys, in order:

1. **ClassOfService rank** (ascending — lower rank = higher priority):
   - EXPEDITE (1) > FIXED_DATE (2) > STANDARD (3) > INTANGIBLE (4)
   - Tasks missing ClassOfService are treated as STANDARD (rank 3)
2. **Priority** (descending — higher number = more urgent)
3. **Last edited time** (ascending — oldest-edited first, to prevent starvation)

The **first** task after sorting is returned by `ntask next`.

## Claim Protocol

### Claiming a Task (claim)

1. Generate a UUID v4 `LockToken`.
2. Set the following properties atomically:
   - `Status` → `IN_PROGRESS`
   - `ClaimedBy` → `AGENT`
   - `AgentRunID` → provided run ID
   - `AgentName` → provided agent name
   - `LockToken` → generated token
   - `LockedUntil` → now + lease duration (default 20 minutes)
   - `StartedAt` → now (if property exists)
3. **Verify the claim** by re-reading the page immediately after update.
4. If the re-read shows a **different** `LockToken`, return `CONFLICT`.
   Another agent claimed the task first.

### Heartbeat (heartbeat)

1. Read the page and verify `LockToken` matches the provided token.
2. If token does not match → return `LOST_LOCK`.
3. If token matches, update:
   - `LockedUntil` → now + lease duration (default 20 minutes)
4. Return success with the new expiry time.

### Complete (complete)

1. Read the page and verify `LockToken` matches the provided token.
2. If token does not match → return `LOST_LOCK`.
3. Update properties:
   - `Status` → `DONE`
   - `Artifacts` → provided artifacts string
   - `DoneAt` → now (if property exists)
   - Clear lock fields (set to null/empty):
     - `ClaimedBy` → null (clear the Select)
     - `AgentRunID` → `""` (empty string)
     - `AgentName` → `""` (empty string)
     - `LockToken` → `""` (empty string)
     - `LockedUntil` → null (clear the Date)
4. Return success.

### Block (block)

1. Read the page and verify `LockToken` matches the provided token.
2. If token does not match → return `LOST_LOCK`.
3. Update properties:
   - `Status` → `BLOCKED`
   - `BlockerReason` → provided reason
   - `UnblockAction` → provided unblock action
   - `NextCheckAt` → provided ISO 8601 timestamp (optional)
   - Clear lock fields (set to null/empty):
     - `ClaimedBy` → null (clear the Select)
     - `AgentRunID` → `""` (empty string)
     - `AgentName` → `""` (empty string)
     - `LockToken` → `""` (empty string)
     - `LockedUntil` → null (clear the Date)
4. Return success.

### Review (review)

1. Read the page and verify `LockToken` matches the provided token.
2. If token does not match → return `LOST_LOCK`.
3. Update properties:
   - `Status` → `REVIEW`
   - `Artifacts` → provided artifacts string (optional)
   - Clear lock fields (set to null/empty):
     - `ClaimedBy` → null (clear the Select)
     - `AgentRunID` → `""` (empty string)
     - `AgentName` → `""` (empty string)
     - `LockToken` → `""` (empty string)
     - `LockedUntil` → null (clear the Date)
4. Return success.

### Cancel (cancel)

1. Read the page and verify `LockToken` matches the provided token.
2. If token does not match → return `LOST_LOCK`.
3. Update properties:
   - `Status` → `CANCELED`
   - `BlockerReason` → provided reason
   - Clear lock fields (set to null/empty):
     - `ClaimedBy` → null (clear the Select)
     - `AgentRunID` → `""` (empty string)
     - `AgentName` → `""` (empty string)
     - `LockToken` → `""` (empty string)
     - `LockedUntil` → null (clear the Date)
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
