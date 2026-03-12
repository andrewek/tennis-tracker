## Why

The initial team-roster-planning spike established the core data model and LiveView, but several rough edges remain: PubSub is wired manually rather than through Ash, schema constraints are too strict or duplicated, the team modal UX is inline and hard to manage, and the board loads all players into memory rather than filtering at the DB level. These refinements harden the foundation before broader use.

## What Changes

- **PubSub**: Replace manual `Phoenix.PubSub` calls on `Team` and `TeamMembership` with `Ash.Notifier.PubSub` using dynamic topics `roster:{team_type_id}:{season_year}`; update `RosterPlannerLive` to subscribe and handle `%Ash.Notifier.Notification{}` structs
- **SeasonRules**: Make `min_roster`, `max_roster`, and `on_level_min_pct` nullable; add conditional validations (positive integer for roster sizes, 0.0–100.0 for percentage) on create and update
- **Team**: Remove the unused `captain` attribute; add a resource-level default sort (year desc → age_group asc nils_last → ntrp_level desc nils_last → name asc) across the TeamType relationship
- **TeamType**: Make `ntrp_level` and `age_group` nullable; guard existing `attribute_in` validations with `where([present(...)])`
- **NTRP consolidation**: Extract NTRP level constants into a shared `TennisTracker.Tennis.NtrpLevels` module; update `Player` and `TeamType` to reference it
- **RosterPlannerLive — modal**: Replace scattered inline rename/delete assigns with a single `@team_modal` assign; one modal shared for create, edit, and delete; AshPhoenix.Form-driven with validation errors displayed
- **RosterPlannerLive — load_board**: Push unassigned player eligibility filtering to the DB via Ash.Query (age group, NTRP levels, `not exists` membership check); remove in-memory filtering helpers

## Capabilities

### New Capabilities

- `ntrp-levels`: Shared NTRP level constants module used by Player and TeamType validation
- `team-modal`: Modal-based team create/edit/delete UX on the roster planner board

### Modified Capabilities

- `roster-planner`: Board loading now DB-filtered; PubSub mechanism changed to Ash.Notifier; team action UI replaced by modal
- `team-management`: SeasonRules fields are now nullable with conditional validations; Team loses `captain`; TeamType fields are nullable; default sort added to Team

## Impact

- **Schema migrations**: Three new Ash migrations (SeasonRules nullability, Team captain removal, TeamType nullability)
- **Resources modified**: `Team`, `TeamMembership`, `TeamType`, `SeasonRules`, `Player`
- **New module**: `TennisTracker.Tennis.NtrpLevels`
- **LiveView**: `RosterPlannerLive` — assigns, events, and board loading significantly refactored
- **Seeds**: May need updating if captain or non-nullable fields are referenced
- **Tests**: Existing roster planner and team roster tests will need updates for removed captain, new modal events, and changed PubSub patterns
