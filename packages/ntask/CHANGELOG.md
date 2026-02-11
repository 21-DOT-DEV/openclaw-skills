# Changelog

## [0.3.0] - 2026-02-11

### Breaking Changes
- **Removed DB properties**: `Agent` (select) and `Claimed By` (select) no longer read or written
- **Removed JSON output fields**: `agent` and `claimed_by` removed from task summaries
- **Removed CLI flag**: `--agent-name` removed from `claim` command
- **PullPolicy**: Eligibility now uses lock-only checks (`Lock Token` + `Lock Expires`);
  human/agent distinction via `Claimed By` is removed

### Added
- **Assignee** people property: Written on `claim` using `NOTION_AGENT_USER_ID` env var
  (Notion user ID). Persists after release as audit trail.
- `NOTION_AGENT_USER_ID` env var: Required for `claim`; validated by `ntask doctor`
- `env_NOTION_AGENT_USER_ID` check in `ntask doctor` output

### Changed
- `updateForClaim` signature: removed `agentName` parameter
- `claimProperties`: replaced `Agent`/`Claimed By` with `Assignee` people property
- Release blocks (complete/block/review/cancel): no longer clear `Agent` or `Claimed By`

## [0.2.1] - 2026-02-10

### Breaking Changes
- **Status property type**: `select` → native `status` (Notion's built-in status type)
- **Status values**: UPPER_CASE → Title Case (e.g., `READY` → `Ready`, `IN_PROGRESS` → `In Progress`)
- **Class of Service values**: UPPER_CASE → Title Case (e.g., `EXPEDITE` → `Expedite`, `FIXED_DATE` → `Fixed Date`)
- **Claimed By values**: UPPER_CASE → Title Case (`AGENT` → `Agent`, `HUMAN` → `Human`)
- **Priority scale**: 1–10 → 1–3 (default: 2)
- **Removed CLI flags**: `--artifacts` removed from `complete` and `review` commands
- **Removed DB property**: `Artifacts` removed
- **Property renames**: `BlockerReason` → `Blocker Reason`, `UnblockAction` → `Unblock Action`,
  `StartedAt` → `Started At`, `DoneAt` → `Done At`, `NextCheckAt` → `Next Check At`

### Added
- `TaskStatus` enum with `ExpressibleByArgument` — case-insensitive status input
  (accepts `ready`, `READY`, or `Ready`)
- `ClassOfService` enum with `ExpressibleByArgument` — case-insensitive class input
- New output fields: `started_at`, `completed_subtasks` in task summaries
- `Completed Sub-tasks` rollup accessor for two-rollup completion guard
- Completion guard now compares `completedSubtasks` vs `dependencies` (total vs completed)

### Changed
- `updateForComplete` signature: removed `artifacts` parameter
- `updateForReview` signature: removed `artifacts` parameter
- All status filters use native `status` type instead of `select`

## [0.2.0] - 2026-02-08

### Breaking Changes
- **Schema refactor**: All DB property names updated to match new Notion schema
  - `TaskID` → `ID` (type: `unique_id`, value format: `TASK-42`)
  - `ClassOfService` → `Class`
  - `AgentName` → `Agent` (type: `select`, was `rich_text`)
  - `AgentRunID` → `Agent Run`
  - `ClaimedBy` → `Claimed By`
  - `LockToken` → `Lock Token`
  - `LockedUntil` → `Lock Expires`
  - `DependenciesOpenCount` → `Dependencies`
- **JSON output key renames**: `class_of_service` → `class`, `agent_name` → `agent`,
  `agent_run_id` → `agent_run`, `locked_until` → `lock_expires`
- **Removed fields**: `acceptance_criteria` removed from JSON output
- **Removed CLI flags**: `--task-id` and `--acceptance-criteria` removed from `create`;
  `--acceptance-criteria` removed from `update`
- `ntask doctor` output: `env_NOTION_TOKEN` (boolean) replaced with
  `notion_token` (object: `{available, source}`)
- `task_id` value now uses `TASK-42` prefix format (from Notion `unique_id`)

### Added
- **Codable types**: `NotionPage` is now `Decodable` with typed `NotionPropertyValue`
  enum (replaces `[String: Any]` + manual casting). Uses `JSONDecoder` throughout.
- Completion guard: `ntask complete` blocks if sub-tasks are still open
  (uses Dependencies rollup — zero extra API calls)
- Task ID resolution: accepts both `TASK-42` and `42` formats
- Keychain auth support: `ntask doctor` now detects `notion auth login`
  credentials via `notion auth status -o json`
- `NotionCLI.checkAuthStatus()` for probing keychain auth
- `NotionTokenCheck` struct for richer auth status reporting

### Removed
- `AcceptanceCriteria` property (replaced by sub-tasks)
- `DependenciesOpenCount` eligibility check from `ntask next`
- Manual `DependenciesOpenCount` increment from `ntask create`
- Dead `NotionCLI.token` computed property (was never called)

## [0.1.0] - 2025-02-07

Initial release. CLI skeleton with 14 commands, locking protocol,
JSON output contract, and Swift Testing suite.
