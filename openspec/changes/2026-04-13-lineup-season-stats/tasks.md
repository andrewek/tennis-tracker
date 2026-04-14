## Phase 1: participation_type data model

- [ ] 1.1 Add `lib/tennis_tracker/tennis/participation_type.ex` — `use Ash.Type.Enum, values: [:playing, :out, :neutral]`

- [ ] 1.2 Update `TeamLineupSlot`:
  - Remove `is_exclusion_slot` attribute
  - Add `participation_type` attribute using the new enum type, `allow_nil?: false`, `default: :playing`, `public?: true`
  - Update the "only one exclusion slot per team" constraint to check `participation_type == :out` instead of `is_exclusion_slot == true`

- [ ] 1.3 Generate migration: `mix ash_postgres.generate_migrations --name replace_exclusion_slot_with_participation_type`
  - In the generated migration's `up`, add data migration SQL before dropping the old column:
    `UPDATE team_lineup_slots SET participation_type = 'out' WHERE is_exclusion_slot = true`
    `UPDATE team_lineup_slots SET participation_type = 'playing' WHERE is_exclusion_slot = false OR is_exclusion_slot IS NULL`
  - Then drop `is_exclusion_slot`
  - Write the corresponding `down` to reverse

- [ ] 1.4 Update `MatchLineupAssignment` — replace all `is_exclusion_slot` checks with `participation_type == :out`:
  - In the `before_action` change on `:create`: `slot.is_exclusion_slot` check (line ~116)
  - The `Enum.filter/reject` that separates exclusion from non-exclusion assignments
  - The `Enum.find` that looks for an existing exclusion assignment

- [ ] 1.5 Update `Team` default slot creation — `is_exclusion_slot: true` → `participation_type: :out` (the "Out" slot created automatically on team create, line ~156)

- [ ] 1.6 Update `LineupEditLive` — replace `is_exclusion_slot` references in `load_board`:
  - `excl_player_ids` filter: `& &1.team_lineup_slot.is_exclusion_slot` → `& &1.team_lineup_slot.participation_type == :out`
  - `playing_assignments` filter: `Enum.reject(& &1.team_lineup_slot.is_exclusion_slot)` → reject where `participation_type == :out`
  - `do_slot_assignment`: the `Enum.filter(&(&1.player_id == player_id && &1.team_lineup_slot.is_exclusion_slot))` check

- [ ] 1.7 Update `ShowLive` — `Enum.reject(& &1.is_exclusion_slot)` on line 37 → reject where `participation_type == :out`

- [ ] 1.8 Update `EditLive` (teams) — slot delete guard on line 682: `slot.is_exclusion_slot` → `slot.participation_type == :out`

- [ ] 1.9 Update the slot creation UI in `EditLive` (teams):
  - Replace the `is_exclusion_slot` checkbox/input with a `participation_type` select (`:playing`, `:out`, `:neutral`)
  - The `:out` option should be disabled if the team already has an `:out` slot (matching the existing single-exclusion-slot constraint)
  - The slot edit form (rename, reorder) SHALL NOT include a `participation_type` field — type is immutable after creation

- [ ] 1.10 Write tests for slot management changes:
  - Default "Out" slot created on team create has `participation_type: :out`
  - Creating a `:playing` slot succeeds
  - Creating a `:neutral` slot succeeds
  - Creating an `:out` slot succeeds when the team has none
  - Creating a second `:out` slot is rejected with a validation error
  - Delete is rejected for a slot with `participation_type: :out`
  - Delete succeeds for `:playing` and `:neutral` slots
  - UI: `participation_type` select shown on slot creation form with Playing / Out / Neutral options
  - UI: `:out` option disabled in the select when the team already has an `:out` slot
  - UI: no `participation_type` field shown in the slot edit form

- [ ] 1.11 Run `mix precommit` — confirm no compile warnings, tests pass

---

## Phase 2: Season stats domain function

- [ ] 2.1 Add `season_stats_for_team!/3` to `TennisTracker.Tennis` domain:
  - Accepts `team_id`, a pre-loaded `all_matches` list, and `opts` (tenant/actor)
  - Load all `MatchLineupAssignment` records where `match.team_id == ^team_id`, loading only `:team_lineup_slot` (not `:match` — match data comes from the passed-in list)
  - Build `matches_by_id` map from the pre-loaded list; use it to look up `match_start_datetime` per assignment
  - `total_matches` is `length(all_matches)`
  - Aggregate in Elixir by player: `played_past`, `played_future`, `out`, `neutral` (map of slot_name → count)
  - Past vs future determined by comparing `match.match_start_datetime` against `DateTime.utc_now()`
  - Return `%{total_matches: integer, by_player: %{player_id => stats_map}}`

- [ ] 2.2 Write tests for `season_stats_for_team!`:
  - Player with only past playing assignments → correct `played_past`, zero others
  - Player with only future playing assignments → correct `played_future`, zero others
  - Player with out assignments → correct `out` count, not reflected in played counts
  - Player with neutral slot assignments → appears in `neutral` map under slot name, not in played counts
  - Player with a mix of past playing + future out + neutral → all counts correct
  - Player with sub assignments at multiple neutral slots → both slots tracked in `neutral` map
  - Player with no assignments at all → absent from `by_player` (zero-filling is the drawer's responsibility)
  - `total_matches` equals count of all matches for team regardless of assignments

---

## Phase 3: Lineup editor enhancements

- [ ] 3.1 Add new assigns to `LineupEditLive.mount/3`:
  - `:stats_open` → `false`
  - `:stats_sort` → `:name`
  - `:season_stats` → `nil`
  - `:prev_match` → `nil`
  - `:next_match` → `nil`

- [ ] 3.2 Extend `load_board/2` to also:
  - Load all matches for the team (for prev/next and total_matches) using `list_all_matches_for_team!`
  - Compute `prev_match` and `next_match` by finding the current match's index in the sorted list
  - Pass the loaded matches list into `season_stats_for_team!(team_id, all_matches, ...)` and assign the result
  - Assign the list of neutral slot names from the team's slot definitions (all slots where `participation_type == :neutral`), for drawer column headers — shown even if all counts are zero

- [ ] 3.3 Add `handle_event("toggle_stats", ...)` — flips `:stats_open`

- [ ] 3.4 Add `handle_event("set_stats_sort", %{"sort" => sort}, ...)` — updates `:stats_sort`

- [ ] 3.5 Add toggle button to the header bar in `render/1`:
  - Positioned in the right side of the header, alongside the "Back" link and match title
  - Shows an icon (e.g. `hero-table-cells`) or a small label ("Stats")
  - Active/inactive styling based on `@stats_open`

- [ ] 3.6 Add prev/next navigation to the header bar in `render/1`:
  - `← Prev` link (disabled/hidden if `@prev_match` is nil) navigating to `~p".../matches/#{@prev_match.id}/lineup-edit"`
  - `→ Next` link (disabled/hidden if `@next_match` is nil) navigating to `~p".../matches/#{@next_match.id}/lineup-edit"`
  - Show abbreviated match context on the button (e.g. date or opponent) as a tooltip or subtitle

- [ ] 3.7 Implement the `stats_drawer/1` private component:
  - Rendered only when `@stats_open`
  - Fixed width (`w-80` or similar), sits alongside the board in the flex row
  - Header row: "Season Stats" title + sort control (Name / Fewest played / Most played / Most out)
  - Table rows: one per roster player (iterate over the roster already in assigns, not over `by_player` keys)
  - For each roster player, look up their entry in `by_player`; if absent, default all counts to zero
  - Columns: Name · Played (past, muted) · Planned (future) · Total (N / M) · Out · [neutral columns]
  - Sort applied in the component based on `@stats_sort`

- [ ] 3.8 Write LiveView tests:
  - Stats drawer opens and closes via toggle
  - Stats drawer shows correct played/planned/out counts after making assignments on a future match
  - Stats drawer shows correct played count after assigning to a `:playing` slot on a past match
  - Sorting by each sort option produces correct order
  - Prev/next links navigate to correct adjacent matches
  - Prev link absent when on first match; next link absent when on last match
  - Neither Prev nor Next shown when the team has exactly one match
  - Stats drawer is closed after navigating to an adjacent match
  - Drawer shows a column for every neutral slot on the team, including one with all-zero counts
