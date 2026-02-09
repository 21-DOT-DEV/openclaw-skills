# Task Triage — Decision-Making Framework

This document defines the agent's decision-making process before entering the
work loop. The flow is: **triage (think) → workflow (execute)**.

Read this before claiming any task. For the mechanical lifecycle (claim, work,
complete), see [workflow.md](workflow.md).

## Pre-Work Decision Tree

Run through these checks for each task **before claiming**:

| Decision | Rule |
|----------|------|
| **Should I work this?** | Check sub-items define clear done criteria. If no sub-items or vague → comment asking for clarification, move to REVIEW |
| **Can I do this?** | Assess if task requires tools/access the agent has. If not → block with specific unblock action |
| **Is this too big?** | If sub-items contain multiple independent deliverables → decompose into subtasks before starting |
| **Priority override?** | EXPEDITE class → drop current work (complete or block it first), claim EXPEDITE |
| **Stale check** | Task in READY for >N days with no comments → flag to user before claiming |
| **Dependency scan** | Before starting, check if task mentions other task IDs → verify those are DONE |
| **Time-box** | Estimate scope vs lease time. If work likely exceeds 2 lease renewals → decompose first |
| **Done criteria** | Before completing, verify each sub-item criterion is met. If partial → block or comment |

## PARA Alignment

Map task states to PARA categories for a consistent mental model:

| PARA Category | Task State | Meaning |
|---|---|---|
| **Inbox** (capture) | BACKLOG | Captured but not yet triaged |
| **Projects** (active) | READY, IN_PROGRESS, REVIEW | Actionable work tied to Project relations |
| **Areas** (ongoing) | IN_PROGRESS, BLOCKED | Recurring responsibilities |
| **Resources** (reference) | DONE (with artifacts) | Completed work linked via Resources relation |
| **Archive** | CANCELED / old DONE | No longer active |

## Periodic Sweeps

| Sweep | Trigger | Action |
|-------|---------|--------|
| Stale BLOCKED | >3 days in BLOCKED | Re-notify user with blocker reason |
| Orphaned leases | Expired `Lock Expires`, no active agent | Flag as orphaned, reset to READY |
| Unreviewed REVIEW | >2 days in REVIEW, no human response | Bump notification to user |
| Recurring patterns | Same task blocked 3+ times | Suggest task redesign or cancellation |

## Integration with Workflow

After triage passes, enter the work loop defined in [workflow.md](workflow.md):

1. **Triage** — this document (think)
2. **Workflow** — claim → work → complete (execute)

If triage reveals a problem (vague criteria, missing tools, too large), resolve
it **before** claiming. Never claim a task you cannot complete within the lease
window.
