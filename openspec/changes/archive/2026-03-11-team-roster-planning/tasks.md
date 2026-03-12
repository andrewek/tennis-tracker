## 1. Data Model — Ash Resources

- [x] 1.1 Create `TennisTracker.Tennis.TeamType` Ash resource with attributes: `id`, `name`, `age_group` (enum: 18_plus, 40_plus), `ntrp_level` (decimal), `allowed_ntrp_levels` ({:array, :decimal}), timestamps
- [x] 1.2 Create `TennisTracker.Tennis.SeasonRules` Ash resource with attributes: `id`, `team_type_id`, `season_year` (integer), `min_roster` (integer), `max_roster` (integer), `on_level_min_pct` (decimal), timestamps; unique constraint on (team_type_id, season_year)
- [x] 1.3 Create `TennisTracker.Tennis.Team` Ash resource with attributes: `id`, `team_type_id`, `season_year` (integer, indexed), `name` (string), `captain` (string, nullable), `is_pseudo` (boolean, default false), timestamps
- [x] 1.4 Create `TennisTracker.Tennis.TeamMembership` Ash resource with attributes: `id`, `player_id`, `team_id`, `team_type_id` (denormalized), `season_year` (integer, denormalized); unique constraint on (player_id, team_type_id, season_year)
- [x] 1.5 Add Ash relationships: `TeamType has_many :teams`, `TeamType has_many :season_rules`; `Team belongs_to :team_type`, `Team has_many :memberships`; `TeamMembership belongs_to :player`, `TeamMembership belongs_to :team`; `Player has_many :team_memberships`
- [x] 1.6 Generate Ash migration: `mix ash_postgres.generate_migrations --name add_team_roster_tables`
- [x] 1.7 Run `mix ecto.migrate` and verify tables are created correctly

## 2. Domain Actions

- [x] 2.1 Add `TeamType` read actions: `list_team_types` (all), `get_team_type` (by id)
- [x] 2.2 Add `SeasonRules` read action: `get_season_rules` (by team_type_id + season_year), returns nil if not found
- [x] 2.3 Add `Team` actions: `create_team` (requires name, team_type_id, season_year), `update_team` (name, captain), `list_teams_for_context` (by team_type_id + season_year, includes pseudo-teams)
- [x] 2.4 Add `Team` action: `ensure_pseudo_team` — find-or-create the Not Participating pseudo-team for a given (team_type_id, season_year)
- [x] 2.5 Add `TeamMembership` actions: `assign_player` (create or update membership for a player in a context), `unassign_player` (delete membership), `list_memberships_for_context` (all memberships for a team_type_id + season_year)
- [x] 2.6 Expose new actions on the `TennisTracker.Tennis` domain module

## 3. Seed Data

- [x] 3.1 Create seed script (or update `priv/repo/seeds.exs`) to insert 8 TeamType records: age groups 18+ and 40+, NTRP levels 3.0/3.5/4.0/4.5, with correct allowed_ntrp_levels for each (3.0→[3.0], 3.5→[3.0,3.5], 4.0→[3.5,4.0], 4.5→[4.0,4.5])
- [x] 3.2 Create seed entries for SeasonRules for season 2026 with reasonable defaults (e.g. 18+ 3.5: min 10, max 18, on_level 0.60)
- [x] 3.3 Run seeds and verify records in the database

## 4. Roster Health Logic

- [x] 4.1 Create `TennisTracker.Tennis.RosterHealth` module with a `check/3` function that takes a team, its members, and season_rules and returns a list of violation structs (type, message)
- [x] 4.2 Implement below-minimum roster size check
- [x] 4.3 Implement above-maximum roster size check
- [x] 4.4 Implement on-level percentage check (nil-rated players count as unknown, not on-level)
- [x] 4.5 Implement per-player NTRP allowed-levels check
- [x] 4.6 Implement per-player nil-rating caution (warning, not error)
- [x] 4.7 Return empty list (no violations) when season_rules is nil

## 5. Roster Planner LiveView

- [x] 5.1 Add route `live "/roster-planner", RosterPlannerLive, :index` (and `live "/roster-planner/:team_type_id/:season_year", RosterPlannerLive, :board`) to `router.ex`
- [x] 5.2 Create `TennisTrackerWeb.Live.RosterPlannerLive` with mount that loads context selector (list of team types and a season year input)
- [x] 5.3 Implement context selection: on submit, navigate to `/roster-planner/:team_type_id/:season_year`
- [x] 5.4 On board mount: load team type, season rules, teams for context, memberships for context, all players; call `ensure_pseudo_team`; subscribe to PubSub topic `roster_planner:{team_type_id}:{season_year}`
- [x] 5.5 Build board template: columns for Unassigned, each real team (sorted by name), and Not Participating; player cards in each column
- [x] 5.6 Compute and assign health indicators per team and per player card using `RosterHealth.check/3`
- [x] 5.7 Implement "New Team" flow: button opens inline form, submit calls `create_team`, broadcasts update via PubSub
- [x] 5.8 Implement team rename: inline edit on team column header, submit calls `update_team`, broadcasts update
- [x] 5.9 Implement drag-and-drop on desktop: colocated JS hook (`.RosterDrag`) using HTML5 drag API; on drop, send LiveView event `move_player` with player_id and target_team_id
- [x] 5.10 Implement `handle_event("move_player", ...)`: call `assign_player` or `unassign_player`, recompute health, broadcast PubSub event
- [x] 5.11 Implement mobile tap-to-assign: tap on player card sends `select_player` event; LiveView assigns selected player and shows destination picker modal/bottom sheet; selecting a destination sends `move_player`
- [x] 5.12 Implement `handle_info` for PubSub broadcast: re-fetch memberships, recompute health, update board assign
- [x] 5.13 Board state held in `@board` assign (map of columns) — multiple dynamic columns make per-column streams architecturally complex; board is rebuilt on each change (small data set)

## 6. UI Polish

- [x] 6.1 Style player cards with health indicator badges (warning icon for NTRP violation, caution icon for unrated)
- [x] 6.2 Style team column headers with health summary (violation messages shown inline)
- [x] 6.3 Ensure board is horizontally scrollable on mobile when multiple teams are present (`overflow-x-auto`)
- [x] 6.4 Mobile bottom sheet destination picker implemented with fixed overlay

## 8. Eligibility Filtering for Unassigned Column

- [x] 8.1 Update `load_board/5` in `RosterPlannerLive` to filter `unassigned` players by age-group eligibility and allowed NTRP levels (including nil-rated players as eligible)
- [x] 8.2 Add unit test: eligible player with matching NTRP appears in Unassigned
- [x] 8.3 Add unit test: over-rated player is excluded from Unassigned
- [x] 8.4 Add unit test: under-rated player is excluded from Unassigned
- [x] 8.5 Add unit test: nil-rated age-eligible player appears in Unassigned
- [x] 8.6 Add unit test: ineligible player already assigned to a team still appears in their team column, not in Unassigned

## 9. Full-Width Planner Layout

- [x] 9.1 Add `fluid` boolean attribute (default `false`) to `Layouts.app` component; when `true`, remove `max-w-2xl` constraint while retaining horizontal padding
- [x] 9.2 Pass `fluid={true}` from `RosterPlannerLive` to `<Layouts.app>`

## 10. Delete Team

- [x] 10.1 Add `delete_team` action on `TennisTracker.Tennis.Team` Ash resource; action must also delete all associated `TeamMembership` records for that team
- [x] 10.2 Expose `delete_team/1` on the `TennisTracker.Tennis` domain module
- [x] 10.3 Add `deleting_team_id` assign to `RosterPlannerLive` (nil by default)
- [x] 10.4 Handle `"confirm_delete_team"` event: call `Tennis.delete_team/1`, broadcast PubSub update, reload board
- [x] 10.5 Handle `"start_delete_team"` event: set `deleting_team_id`; handle `"cancel_delete_team"` event: clear it
- [x] 10.6 Update `board_column` component: show delete button on real team columns (not pseudo-team); when `deleting_team_id == team.id`, render [Confirm Delete] + [Cancel] inline; hide rename controls while in confirm state
- [x] 10.7 Add LiveView test: deleting a team returns its players to Unassigned
- [x] 10.8 Add LiveView test: cancel during confirm state leaves team intact

## 7. Tests

- [x] 7.1 Unit tests for `RosterHealth.check/3` covering all violation types and nil season_rules case
- [x] 7.2 Ash resource tests: TeamType, SeasonRules uniqueness constraint, TeamMembership uniqueness constraint
- [x] 7.3 LiveView test: board loads for a valid context
- [x] 7.4 LiveView test: moving a player updates the correct column
- [x] 7.5 LiveView test: health indicators appear when rules are violated
- [x] 7.6 LiveView test: PubSub broadcast reaches a second subscriber session
- [x] 7.7 Run `mix precommit` and confirm all tests pass
