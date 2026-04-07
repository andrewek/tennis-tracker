## Why

The original match-lineups feature established individual named slots and a flat drag-and-drop board, but had no concept of slot grouping, no way to configure whether a player can appear in multiple slots (a requirement for high school and informal league formats), and no semantic distinction between playing slots and exclusion slots like "Out". This change adds the structural foundation that makes the lineup feature usable across different league formats.

## What Changes

- **New resource `TeamLineupColumn`**: Groups slots into named visual columns with their own sort order, independent of slot sort order. A standard 18+ USTA board becomes Available | Singles (#1S, #2S) | Doubles (#1D–#3D) | Reserve (Sub, Out) — four columns instead of seven.
- **`lineup_assignment_mode` on Team**: Configures the player-per-match assignment constraint for the team — `:one_per_match` (default, current behavior), `:one_per_column` (one slot per column group, supports dual-format leagues), or `:many_per_match` (any number of slots, informal formats).
- **`is_exclusion_slot` on `TeamLineupSlot`**: Marks a slot (e.g. "Out", "Unavailable") as mutually exclusive with playing slots. Assigning a player to an exclusion slot removes their playing assignments; assigning an excluded player to a playing slot is blocked. Each team has exactly one exclusion slot, auto-provisioned as "Out" in a default "Reserve" column when the team is created.
- **Revised board layout**: The lineup board groups slots vertically within column headers rather than one column per slot. Available is always leftmost. Columns are ordered by `TeamLineupColumn.sort_order`, slots within each column by `TeamLineupSlot.sort_order`.
- **Tap-to-assign on mobile**: In addition to existing drag-and-drop (desktop), a tap-to-assign interaction is added — tap a player to select, tap a destination slot to assign.
- **Available column behavior changes per mode**: `:one_per_match` keeps current behavior (assigned players leave the Available column); `:one_per_column` shows all non-excluded players always, with column assignment badges on cards; `:many_per_match` always shows the full roster.
- **`player_per_match` DB identity replaced**: The current unconditional DB-level unique constraint on `(match_id, player_id)` is dropped in favor of application-layer validation keyed off `lineup_assignment_mode`, enabling multi-slot assignment for `:one_per_column` and `:many_per_match` teams.

## Capabilities

### New Capabilities

- `team-lineup-columns`: Define and manage named column groups for lineup slots. Each column belongs to a team, has a name (unique within team), and a sort_order. Slots are assigned to columns. Captains can create, rename, reorder, and delete columns.

### Modified Capabilities

- `team-lineup-slots`: Slots gain `is_exclusion_slot` flag (mutual exclusion with playing slots, enforced on assignment) and `team_lineup_column_id` (optional column association).
- `match-lineup`: Board layout changes to grouped columns. Available column semantics change per `lineup_assignment_mode`. Tap-to-assign added for mobile. `player_per_match` identity replaced with mode-aware application-layer constraint.
- `team-edit-page`: Column management section added alongside slot management. `lineup_assignment_mode` setting added.

## Impact

- New Ash resource: `TeamLineupColumn` (already migrated, domain-registered)
- Modified Ash resources: `TeamLineupSlot` (already migrated: `is_exclusion_slot`, `team_lineup_column_id`), `Team` (already migrated: `lineup_assignment_mode`), `MatchLineupAssignment` (`player_per_match` identity to be dropped)
- Modified LiveView: `LineupEditLive` updated with grouped board layout, mode-aware assignment, and tap-to-assign; column management added to team edit page
- New JS interaction: tap-to-assign (implemented via `phx-click` handlers, no separate hook required)
- `BoardComponents`: new `lineup_board` component (grouped vertical slots within a horizontal column header)
