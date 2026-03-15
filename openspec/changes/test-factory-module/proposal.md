## Why

Every test file duplicates the same `defp create_player`, `defp create_team_type`, `defp create_team` helpers with nearly identical defaults. As the data model grows, these diverge and become a maintenance burden.

## What Changes

- Add `test/support/factory.ex` — a single factory module with per-resource builder functions that go through Ash domain functions, use unique defaults, and support a trait system for common configurations.
- Remove duplicated `defp create_*` helpers from test files as they are replaced by the factory.
- Import `TennisTracker.Factory` in `DataCase` and `ConnCase` so all tests have access without extra boilerplate.

## Capabilities

### New Capabilities

- `test-factory`: Per-resource factory functions (`Factory.player/1`, `Factory.team_type/1`, `Factory.team/1`, `Factory.team_membership/1`, `Factory.season_rules/1`) with unique defaults, trait support, and automatic dependency creation.

### Modified Capabilities

## Impact

- `test/support/factory.ex` — new file
- `test/support/data_case.ex` — import `TennisTracker.Factory`
- `test/support/conn_case.ex` — import `TennisTracker.Factory`
- All existing test files that define local `create_*` helpers — refactored to use the factory
- No production code changes; no new dependencies
