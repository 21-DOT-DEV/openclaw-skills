# Notion Task Database Schema

This document defines the Notion database properties used by the
notion-task-skill. The schema adds agent-specific properties to an existing
PARA-aligned Notion task database while converting two native property types
to formats ntask can work with.

## Design Decisions

- **Single status property**: One `select` Status (no dual-status pattern —
  community consensus says dual-status causes drift)
- **PARA via relations**: Project, Resources, and Sub-tasks relations preserve
  PARA alignment without encoding it into status values
- **Sub-items for acceptance criteria**: Each criterion is a sub-task with a
  checkbox, using existing Sub-tasks/Parent-task relations. Machine-readable,
  visual, and native to Notion.

Sources: Forte, Poulin, Frank, Bradley on PARA best practices; Notion API
property type documentation; `unique_id` and sub-items feature docs.

## Existing Properties (Preserved)

These properties remain unchanged from the existing Notion database:

| Property | Type | PARA Role |
|---|---|---|
| Task name | Title | — |
| Assignee | People | — |
| Due | Date | — |
| Sub-tasks | Relation (self) | Task hierarchy |
| Parent-task | Relation (self) | Task hierarchy |
| Project | Relation → Projects DB | **P** — Projects |
| Resources | Relation → Resources DB | **R** — Resources |
| Summary | Rich Text | — |
| URL | URL | — |

## Converted Properties

These existing properties must change type. Notion API has no in-place type
conversion — create the new property, migrate data, rename old to
`_property_old` as rollback safety.

### Status: native `status` → `select`

| Current (native status) | → New (select) | Rationale |
|---|---|---|
| Inbox | BACKLOG | Not yet triaged/ready |
| Planning | BACKLOG | Still being scoped |
| In Progress | IN_PROGRESS | Direct mapping |
| Paused | BLOCKED | Stalled work |
| Done | DONE | Direct mapping |
| Canceled | CANCELED | Direct mapping |
| *(new)* | READY | Triaged and actionable, not yet claimed |
| *(new)* | REVIEW | Work done, awaiting review |

### Priority: `select` → `number`

| Current (select) | → New (number) |
|---|---|
| Low | 1 |
| Medium | 5 |
| High | 9 |

Higher number = more urgent. Scale 1–10 allows fine-grained ordering.

## Added Properties (7 new)

These properties are added for agent lifecycle management:

| Property | Type | Description |
|---|---|---|
| ID | `unique_id` | Auto-increment, customizable prefix, URL-accessible. Read-only via API (Notion generates). |
| Class | Select | Kanban class-of-service: EXPEDITE, FIXED_DATE, STANDARD, INTANGIBLE |
| Claimed By | Select | Who holds the lock: `AGENT` or `HUMAN` |
| Agent | Select | Name/identifier of the agent holding the lock |
| Agent Run | Rich Text | UUID for the agent's current run (no better Notion type for UUIDs) |
| Lock Token | Rich Text | UUID for lock verification (no better Notion type for UUIDs) |
| Lock Expires | Date | ISO 8601 timestamp when the lock expires |

### Dependencies (Rollup)

Add a Rollup property on the Sub-tasks relation that counts sub-tasks whose
Status is not DONE or CANCELED. Completion is blocked when this value is > 0.

### Class — Allowed Select Options

| Value | Rank | Meaning |
|---|---|---|
| EXPEDITE | 1 | Drop everything; highest urgency |
| FIXED_DATE | 2 | Has a hard deadline |
| STANDARD | 3 | Normal priority work |
| INTANGIBLE | 4 | Technical debt, improvements, nice-to-have |

### Claimed By — Allowed Select Options

| Value | Meaning |
|---|---|
| AGENT | Claimed by an automated agent |
| HUMAN | Claimed by a human operator |

## Optional Properties

These improve observability and auditability but are not required:

| Property | Type | Description |
|---|---|---|
| Artifacts | Rich Text | Links/references to work products |
| BlockerReason | Text | Why the task is blocked |
| UnblockAction | Text | What needs to happen to unblock |
| NextCheckAt | Date | When to re-check a blocked task |
| StartedAt | Date | When work began (set on claim) |
| DoneAt | Date | When work completed (set on complete) |
| ClassRank | Number | Explicit sort rank (1–4). If present, used instead of deriving from Class select. |

## Property Refinements (from Research)

These changes improve the original schema design:

| Property | Original Plan | → Revised | Rationale |
|---|---|---|---|
| TaskID | rich_text | `unique_id` | Auto-increment, customizable prefix, guaranteed unique |
| AcceptanceCriteria | rich_text | Removed — use sub-items | Each criterion = sub-task with checkbox. Native Notion pattern. |
| AgentName | rich_text | `select` (renamed `Agent`) | Finite set of agents. Better for formulas/filters. |
| ClassOfService | select | select (renamed `Class`) | Cleaner column header |
| ClaimedBy | select | select (renamed `Claimed By`) | Spaced for readability |
| AgentRunID | rich_text | rich_text (renamed `Agent Run`) | UUID — no better type exists |
| LockToken | rich_text | rich_text (renamed `Lock Token`) | UUID — no better type exists |
| LockedUntil | date | date (renamed `Lock Expires`) | More descriptive |

Net result: 7 new properties (down from 8). Only 2 rich_text fields remain
(both UUIDs where no alternative exists).

## Migration Plan

Migration plan is tracked separately outside this repository.

| Phase | Description | Status |
|---|---|---|
| 0 | Duplicate DB for testing | ✅ Done |
| 1 | Add 7 new properties to test DB | Being refined |
| 2 | Convert Status: native `status` → `select` | Pending |
| 3 | Convert Priority: `select` → `number` | Pending |
| 4 | Add Dependencies rollup | Pending |
| 5 | Backfill IDs (prefix TBD) | Pending |

**Migration notes:**
- Notion API has no in-place type conversion — must create new property,
  migrate data, archive old with `_property_old` suffix
- DB duplication is UI-only; relations survive, two-way downgrades to one-way
- No rollback mechanism — `_property_old` rename is industry standard

## PARA Alignment

| PARA Category | How It Maps |
|---|---|
| **Projects** | `Project` relation → Projects DB |
| **Areas** | Ongoing tasks in IN_PROGRESS / BLOCKED |
| **Resources** | `Resources` relation → Resources DB; DONE tasks with artifacts |
| **Archive** | DONE / CANCELED status values |

## Open Questions

- **`unique_id` prefix**: What prefix for auto-generated IDs? (e.g., `TASK-`, project-specific)
- **Priority scale**: Confirm 1–10 with Low=1, Medium=5, High=9
- **Optional properties**: Which optional properties (BlockerReason, StartedAt, DoneAt, etc.) to add in Phase 1 vs defer
