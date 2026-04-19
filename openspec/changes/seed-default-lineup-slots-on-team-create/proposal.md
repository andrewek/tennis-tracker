## Why

When a new team is created, captains must manually set up lineup columns and slots before they can use the lineup features. Providing sensible defaults accelerates time-to-first-lineup and establishes a consistent starting structure that matches the most common USTA team lineup format.

## What Changes

- When a non-pseudo team is created, automatically provision an "Assigned" column with six default slots: "#1 Singles", "#2 Singles", "#1 Doubles", "#2 Doubles", "#3 Doubles", and "Sub"
- The existing auto-provisioned "Reserve" column with its "Out" exclusion slot is unchanged
- The `lineup_assignment_mode` default changes from `:one_per_match` to `:one_per_column`

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `team-lineup-slots`: Team creation now provisions six default playing slots in an "Assigned" column in addition to the existing "Out" exclusion slot in "Reserve"
- `match-lineup`: Default `lineup_assignment_mode` changes from `:one_per_match` to `:one_per_column`

## Impact

- `lib/tennis_tracker/tennis/team.ex` — the `create` action's after_action callback gains logic to provision the "Assigned" column and its six default slots; the `lineup_assignment_mode` attribute default changes from `:one_per_match` to `:one_per_column`
- Existing teams are unaffected — this only applies to newly created teams
- Tests that create non-pseudo teams will now have additional lineup columns/slots available; tests creating pseudo teams are unaffected (the existing `if !team.is_pseudo` guard remains)
