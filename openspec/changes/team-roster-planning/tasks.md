## 1. Data Model — Ash Resources

- [ ] 1.1 Create `TennisTracker.Tennis.TeamType` Ash resource with attributes: `id`, `name`, `age_group` (enum: 18_plus, 40_plus), `ntrp_level` (decimal), `allowed_ntrp_levels` ({:array, :decimal}), timestamps
- [ ] 1.2 Create `TennisTracker.Tennis.SeasonRules` Ash resource with attributes: `id`, `team_type_id`, `season_year` (integer), `min_roster` (integer), `max_roster` (integer), `on_level_min_pct` (decimal), timestamps; unique constraint on (team_type_id, season_year)
- [ ] 1.3 Create `TennisTracker.Tennis.Team` Ash resource with attributes: `id`, `team_type_id`, `season_year` (integer, indexed), `name` (string), `captain` (string, nullable), `is_pseudo` (boolean, default false), timestamps
- [ ] 1.4 Create `TennisTracker.Tennis.TeamMembership` Ash resource with attributes: `id`, `player_id`, `team_id`, `team_type_id` (denormalized), `season_year` (integer, denormalized); unique constraint on (player_id, team_type_id, season_year)
- [ ] 1.5 Add Ash relationships: `TeamType has_many :teams`, `TeamType has_many :season_rules`; `Team belongs_to :team_type`, `Team has_many :memberships`; `TeamMembership belongs_to :player`, `TeamMembership belongs_to :team`; `Player has_many :team_memberships`
- [ ] 1.6 Generate Ash migration: `mix ash_postgres.generate_migrations --name add_team_roster_tables`
- [ ] 1.7 Run `mix ecto.migrate` and verify tables are created correctly

## 2. Domain Actions

- [ ] 2.1 Add `TeamType` read actions: `list_team_types` (all), `get_team_type` (by id)
- [ ] 2.2 Add `SeasonRules` read action: `get_season_rules` (by team_type_id + season_year), returns nil if not found
- [ ] 2.3 Add `Team` actions: `create_team` (requires name, team_type_id, season_year), `update_team` (name, captain), `list_teams_for_context` (by team_type_id + season_year, includes pseudo-teams)
- [ ] 2.4 Add `Team` action: `ensure_pseudo_team` — find-or-create the Not Participating pseudo-team for a given (team_type_id, season_year)
- [ ] 2.5 Add `TeamMembership` actions: `assign_player` (create or update membership for a player in a context), `unassign_player` (delete membership), `list_memberships_for_context` (all memberships for a team_type_id + season_year)
- [ ] 2.6 Expose new actions on the `TennisTracker.Tennis` domain module

## 3. Seed Data

- [ ] 3.1 Create seed script (or update `priv/repo/seeds.exs`) to insert 8 TeamType records: age groups 18+ and 40+, NTRP levels 3.0/3.5/4.0/4.5, with correct allowed_ntrp_levels for each (3.0→[3.0], 3.5→[3.0,3.5], 4.0→[3.5,4.0], 4.5→[4.0,4.5])
- [ ] 3.2 Create seed entries for SeasonRules for season 2026 with reasonable defaults (e.g. 18+ 3.5: min 10, max 18, on_level 0.60)
- [ ] 3.3 Run seeds and verify records in the database

## 4. Roster Health Logic

- [ ] 4.1 Create `TennisTracker.Tennis.RosterHealth` module with a `check/3` function that takes a team, its members, and season_rules and returns a list of violation structs (type, message)
- [ ] 4.2 Implement below-minimum roster size check
- [ ] 4.3 Implement above-maximum roster size check
- [ ] 4.4 Implement on-level percentage check (nil-rated players count as unknown, not on-level)
- [ ] 4.5 Implement per-player NTRP allowed-levels check
- [ ] 4.6 Implement per-player nil-rating caution (warning, not error)
- [ ] 4.7 Return empty list (no violations) when season_rules is nil

## 5. Roster Planner LiveView

- [ ] 5.1 Add route `live "/roster-planner", RosterPlannerLive, :index` (and `live "/roster-planner/:team_type_id/:season_year", RosterPlannerLive, :board`) to `router.ex`
- [ ] 5.2 Create `TennisTrackerWeb.Live.RosterPlannerLive` with mount that loads context selector (list of team types and a season year input)
- [ ] 5.3 Implement context selection: on submit, navigate to `/roster-planner/:team_type_id/:season_year`
- [ ] 5.4 On board mount: load team type, season rules, teams for context, memberships for context, all players; call `ensure_pseudo_team`; subscribe to PubSub topic `roster_planner:{team_type_id}:{season_year}`
- [ ] 5.5 Build board template: columns for Unassigned, each real team (sorted by name), and Not Participating; player cards in each column
- [ ] 5.6 Compute and assign health indicators per team and per player card using `RosterHealth.check/3`
- [ ] 5.7 Implement "New Team" flow: button opens inline form, submit calls `create_team`, broadcasts update via PubSub
- [ ] 5.8 Implement team rename: inline edit on team column header, submit calls `update_team`, broadcasts update
- [ ] 5.9 Implement drag-and-drop on desktop: colocated JS hook (`.RosterDrag`) using HTML5 drag API; on drop, send LiveView event `move_player` with player_id and target_team_id
- [ ] 5.10 Implement `handle_event("move_player", ...)`: call `assign_player` or `unassign_player`, recompute health, broadcast PubSub event
- [ ] 5.11 Implement mobile tap-to-assign: tap on player card sends `select_player` event; LiveView assigns selected player and shows destination picker modal/bottom sheet; selecting a destination sends `move_player`
- [ ] 5.12 Implement `handle_info` for PubSub broadcast: re-fetch memberships, recompute health, update streams
- [ ] 5.13 Use LiveView streams for player lists in each column

## 6. UI Polish

- [ ] 6.1 Style player cards with health indicator badges (warning icon for NTRP violation, caution icon for unrated)
- [ ] 6.2 Style team column headers with health summary (e.g. roster count vs min/max, on-level %)
- [ ] 6.3 Ensure board is horizontally scrollable on mobile when multiple teams are present
- [ ] 6.4 Test and verify bottom sheet destination picker is usable on small screens

## 7. Tests

- [ ] 7.1 Unit tests for `RosterHealth.check/3` covering all violation types and nil season_rules case
- [ ] 7.2 Ash resource tests: TeamType, SeasonRules uniqueness constraint, TeamMembership uniqueness constraint
- [ ] 7.3 LiveView test: board loads for a valid context
- [ ] 7.4 LiveView test: moving a player updates the correct column
- [ ] 7.5 LiveView test: health indicators appear when rules are violated
- [ ] 7.6 LiveView test: PubSub broadcast reaches a second subscriber session
- [ ] 7.7 Run `mix precommit` and confirm all tests pass
