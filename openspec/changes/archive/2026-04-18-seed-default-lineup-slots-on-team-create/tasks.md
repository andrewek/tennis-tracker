## 1. Change default lineup_assignment_mode

- [x] 1.1 In `TennisTracker.Tennis.Team`, change the `lineup_assignment_mode` attribute default from `:one_per_match` to `:one_per_column`

## 2. Provision default Assigned column and slots on team creation

- [x] 2.1 In the `create` action's `after_action` callback in `team.ex`, create an "Assigned" `TeamLineupColumn` with sort_order 1 for the team (using `authorize?: false`, same pattern as Reserve); also update the Reserve column provisioning to use sort_order 2
- [x] 2.2 Create the six default playing slots in the Assigned column: "#1 Singles", "#2 Singles", "#1 Doubles", "#2 Doubles", "#3 Doubles", "Sub" — each with `participation_type: :playing`, `is_exclusion_slot: false`, `include_in_clipboard: true`

## 3. Tests

- [x] 3.1 Update or add a test asserting that a newly created non-pseudo team has an "Assigned" column with the six default slots
- [x] 3.2 Verify that the existing "Out" exclusion slot provisioning test still passes
- [x] 3.3 Check for any tests that assert `lineup_assignment_mode` defaults to `:one_per_match` and update them to expect `:one_per_column`
- [x] 3.4 Run `mix test` and fix any test failures caused by the new default slots or mode change
