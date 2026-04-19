## Context

Team creation currently auto-provisions a "Reserve" column and an "Out" exclusion slot via an `after_action` callback in `TennisTracker.Tennis.Team`'s `:create` action. Captains must then manually create an "Assigned" column and their playing slots before using lineup features.

The `lineup_assignment_mode` attribute currently defaults to `:one_per_match`, which only allows one slot assignment per player per match. `:one_per_column` is a better default for teams with separate Singles/Doubles columns, as it allows one assignment per column rather than one globally.

## Goals / Non-Goals

**Goals:**
- Auto-provision an "Assigned" column with six standard playing slots on team creation
- Change the default `lineup_assignment_mode` from `:one_per_match` to `:one_per_column`

**Non-Goals:**
- Backfilling existing teams (no migration for existing data)
- Making the default slot set configurable (hardcoded to USTA-standard names)
- Changing pseudo-team behavior (the `if !team.is_pseudo` guard remains)

## Decisions

### Extend the existing after_action callback
The current `after_action` in `Team.create` already provisions the Reserve column and Out slot. We extend the same callback to also create the "Assigned" column and its six slots. This keeps all provisioning logic co-located.

**Alternative considered:** A separate change or a dedicated Ash notifier. Rejected because the scope is small and the existing pattern is already established.

### Slot names and participation_type
The six slots use participation_type `:playing` (the enum default). "Sub" is still a playing-type slot — it represents a player who may sub in, not one who is excluded. `is_exclusion_slot` defaults to `false` for all six. `include_in_clipboard` defaults to `true`.

### Default mode change
Change `lineup_assignment_mode` attribute default from `:one_per_match` to `:one_per_column`. This is an attribute-level default, not a migration — existing teams keep their current mode. The validation logic that prevents invalid mode transitions is unaffected.

**Alternative considered:** Leaving the default and setting it explicitly in the `create` action. Rejected because the attribute default is the right place for this.

## Risks / Trade-offs

- **Tests creating non-pseudo teams** will now get an "Assigned" column and six slots. Tests that assert exact slot/column counts may need updating. → Tests should not be asserting absence of default slots; if they do, they'll need a targeted fix.
- **Default mode change** could affect existing tests that rely on `:one_per_match` being the default for new teams created in test setup. → Review test factories and lineup-related tests for implicit mode assumptions.
