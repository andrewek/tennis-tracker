## 0. Data Layer: Auto-Provisioning at Team Creation

- [ ] 0.1 Add an after-action hook (or `change`) to the `Team` create action that creates a default "Reserve" `TeamLineupColumn` (sort_order: 1) for the new team
- [ ] 0.2 In the same hook, create a default "Out" `TeamLineupSlot` with `is_exclusion_slot: true` assigned to the "Reserve" column
- [ ] 0.3 Write tests: creating a team produces exactly one column ("Reserve") and one exclusion slot ("Out") in that column
- [ ] 0.4 Remove the explicit "Out" slot creation from `seed_18_lineup` in `priv/repo/seeds.exs` (line 386 — `upsert_lineup_slot` for `name: "Out"`); the auto-provisioned slot covers it. The "Reserve" column upsert in both seed functions will find the auto-provisioned column and continue normally.

## 1. Data Layer: Exclusion Slot Enforcement

- [ ] 1.1 Add validation to `MatchLineupAssignment` create action: block assignment to a playing slot when the player already has an exclusion slot assignment for the same match
- [ ] 1.2 Add logic to `assign_to_slot` (or `MatchLineupAssignment` create): when assigning to an exclusion slot, auto-destroy any existing playing slot assignments for that player+match before creating the exclusion assignment
- [ ] 1.3 Write tests for: blocked playing-slot assignment when excluded, auto-removal of playing assignments on exclusion assign, unaffected assignment when no exclusion exists
- [ ] 1.4 Add validation to `TeamLineupSlot` create/update: reject `is_exclusion_slot = true` when the team already has an exclusion slot
- [ ] 1.5 Add validation to `TeamLineupSlot` create/update: reject `team_lineup_column_id` nil (all slots require a column)
- [ ] 1.6 Add policy/validation to `TeamLineupSlot` destroy action: reject deletion of the team's exclusion slot
- [ ] 1.7 Add cascade destroy of `MatchLineupAssignment` records when a slot is deleted (via Ash destroy action or relationship destroy)
- [ ] 1.8 Write tests for: second exclusion slot blocked, exclusion slot without column blocked, exclusion slot deletion blocked, slot deletion cascades assignments

## 2. Data Layer: Assignment Mode Enforcement

- [ ] 2.1 Generate migration to drop `player_per_match` identity and add `player_per_slot_per_match` identity `(match_id, player_id, team_lineup_slot_id)`
- [ ] 2.2 Add custom Ash validation to `MatchLineupAssignment` create action implementing mode-aware constraint: load match → team → `lineup_assignment_mode`, apply correct check
- [ ] 2.3 Update `assign_to_slot` domain function: for `:one_per_match`, load existing assignment and update slot in place if found (replaces reliance on dropped identity for upsert)
- [ ] 2.4 Write tests for `:one_per_match` — reassignment updates slot, only one assignment exists
- [ ] 2.5 Write tests for `:one_per_column` — second slot in same column is blocked, slots in different columns both succeed
- [ ] 2.6 Write tests for `:many_per_match` — multiple slots succeed, same slot twice is blocked

## 3. Team Edit Page: Column Management UI

- [ ] 3.1 Add lineup columns section to the team edit LiveView above the slots section (captain/owner only)
- [ ] 3.2 Implement create column inline form (name input, submit creates column at end of list)
- [ ] 3.3 Implement rename column: inline edit on column name, validated for uniqueness within team
- [ ] 3.4 Implement reorder column via move-up / move-down buttons (swap sort_order values)
- [ ] 3.5 Implement delete column: show error if column has assigned slots; allow deletion and destroy the record only when the column is empty
- [ ] 3.5a Implement delete slot with confirmation dialog warning about cascade-deleted match assignments; call slot destroy action which cascades assignments
- [ ] 3.6 Add required column assignment dropdown to each slot row in the slot management section (column is required; no "uncolumned" option)
- [ ] 3.7 Add `lineup_assignment_mode` select input to team edit page (captain/owner only); persist on save
- [ ] 3.8 Add custom validation to the `Team` update action: when `lineup_assignment_mode` changes to `:one_per_match`, reject if any match has a player with more than one assignment; when changing to `:one_per_column`, reject if any match has a player with more than one assignment in the same column; no check needed for `:many_per_match`
- [ ] 3.9 Write tests: mode change to `:one_per_match` blocked when multi-slot assignments exist; mode change to `:one_per_column` blocked when same-column conflicts exist; mode change to `:many_per_match` always succeeds

## 4. Board Layout: Grouped Column Component

- [ ] 4.1 Add a `lineup_board` component that renders the board as a set of named columns (one per `TeamLineupColumn` that has slots); each column shows a header with its slots stacked vertically as individual drop zones. Columns with no slots are not rendered. The Available column appears as the leftmost virtual column.
- [ ] 4.2 Update the lineup board render to group slots by `team_lineup_column_id` and order groups by `TeamLineupColumn.sort_order`
- [ ] 4.3 Update Available column computation in `LineupEditLive`: use current behavior for `:one_per_match`; annotated roster (all non-excluded players with column badges) for `:one_per_column`; full roster for `:many_per_match`
- [ ] 4.4 Update `move_lineup_player` drag handler in `LineupEditLive` for mode-aware semantics: `:one_per_match` — update existing assignment to target slot (existing behavior); `:one_per_column` same-column drag — destroy existing column assignment and create new one for target slot (reposition); `:one_per_column` cross-column drag — create new assignment without removing the existing assignment in the source column; `:many_per_match` — always create a new assignment. Handler must detect same-column vs. cross-column by comparing the source slot's `team_lineup_column_id` against the target slot's `team_lineup_column_id`.

## 5. Mobile: Tap-to-Assign

- [ ] 5.1 Add `selected_player_id` assign (default nil) to `LineupEditLive`
- [ ] 5.2 Add `phx-click="select_player"` handler to player cards: sets/clears `selected_player_id`
- [ ] 5.3 Add `phx-click="assign_selected_player"` handler to slot drop zones: when `selected_player_id` is set, apply mode-aware logic and clear selection — `:one_per_match`: update existing assignment in place; `:one_per_column` same-column: destroy existing column assignment and create new one (reposition); `:one_per_column` cross-column: create new assignment; `:many_per_match`: create new assignment
- [ ] 5.4 Pass `selected` boolean to `player_card` component so the ring highlight renders for the selected player
