# Changelog

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
