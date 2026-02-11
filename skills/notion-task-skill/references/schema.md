# Notion Task Database Schema

This document defines the Notion database properties used by the
notion-task-skill. The schema adds agent-specific properties to an existing
PARA-aligned Notion task database while converting two native property types
to formats ntask can work with.

## Design Decisions

- **Single status property**: One native `status` property (no dual-status pattern —
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

### Status: native `status` (preserved)

The Status property uses Notion's native `status` type with three groups:

| Status | Group | Description |
|---|---|---|
| Backlog | To-do | Not yet triaged/ready |
| Ready | To-do | Triaged and actionable, not yet claimed |
| In Progress | In Progress | Active work |
| Blocked | In Progress | Stalled work |
| Review | In Progress | Work done, awaiting review |
| Done | Complete | Direct mapping |
| Canceled | Complete | Direct mapping |

### Priority: `select` → `number`

| Current (select) | → New (number) |
|---|---|
| Low | 1 |
| Medium | 2 |
| High | 3 |

Higher number = more urgent. Scale 1–3.

## Added Properties (5 new)

These properties are added for agent lifecycle management:

| Property | Type | Description |
|---|---|---|
| ID | `unique_id` | Auto-increment, customizable prefix, URL-accessible. Read-only via API (Notion generates). |
| Class | Select | Kanban class-of-service: Expedite, Fixed Date, Standard, Intangible |
| Agent Run | Rich Text | UUID for the agent's current run (no better Notion type for UUIDs) |
| Lock Token | Rich Text | UUID for lock verification (no better Notion type for UUIDs) |
| Lock Expires | Date | ISO 8601 timestamp when the lock expires |

The existing **Assignee** (People) property is reused on claim — set to the
agent's Notion user via `NOTION_AGENT_USER_ID` env var. Persists after release
as audit trail.

### Dependencies (Rollup)

Rollup on the Sub-tasks relation that counts all sub-tasks (total count).

### Completed Sub-tasks (Rollup)

Rollup on the Sub-tasks relation using count_per_group for the Complete group
(Done + Canceled). Completion is blocked when `Completed Sub-tasks < Dependencies`.

### Class — Allowed Select Options

| Value | Rank | Meaning |
|---|---|---|
| Expedite | 1 | Drop everything; highest urgency |
| Fixed Date | 2 | Has a hard deadline |
| Standard | 3 | Normal priority work |
| Intangible | 4 | Technical debt, improvements, nice-to-have |

## Optional Properties

These improve observability and auditability but are not required:

| Property | Type | Description |
|---|---|---|
| Blocker Reason | Text | Why the task is blocked |
| Unblock Action | Text | What needs to happen to unblock |
| Next Check At | Date | When to re-check a blocked task |
| Started At | Date | When work began (set on claim) |
| Done At | Date | When work completed (set on complete) |
| ClassRank | Number | Explicit sort rank (1–4). If present, used instead of deriving from Class select. |

## Property Refinements (from Research)

These changes improve the original schema design:

| Property | Original Plan | → Revised | Rationale |
|---|---|---|---|
| TaskID | rich_text | `unique_id` | Auto-increment, customizable prefix, guaranteed unique |
| AcceptanceCriteria | rich_text | Removed — use sub-items | Each criterion = sub-task with checkbox. Native Notion pattern. |
| ClassOfService | select | select (renamed `Class`) | Cleaner column header |
| AgentRunID | rich_text | rich_text (renamed `Agent Run`) | UUID — no better type exists |
| LockToken | rich_text | rich_text (renamed `Lock Token`) | UUID — no better type exists |
| LockedUntil | date | date (renamed `Lock Expires`) | More descriptive |

Net result: 5 new properties. Only 2 rich_text fields remain
(both UUIDs where no alternative exists). Existing Assignee (People) property
is reused for agent attribution.

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
| **Areas** | Ongoing tasks in In Progress / Blocked |
| **Resources** | `Resources` relation → Resources DB; Done tasks with work products |
| **Archive** | Done / Canceled status values |

## Open Questions

- **`unique_id` prefix**: What prefix for auto-generated IDs? (e.g., `TASK-`, project-specific)
- **Priority scale**: Confirmed 1–3 with Low=1, Medium=2, High=3
- **Optional properties**: Blocker Reason, Started At, Done At added; Artifacts removed
