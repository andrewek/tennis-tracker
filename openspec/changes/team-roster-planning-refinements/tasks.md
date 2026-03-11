## 1. Shared NTRP Constants Module

- [x] 1.1 Create `TennisTracker.Tennis.NtrpLevels` module with `team_levels/0` (3.0–4.5) and `player_levels/0` (2.5–5.0, superset of team levels)
- [x] 1.2 Update `TennisTracker.Tennis.Player` NTRP validation to reference `NtrpLevels.player_levels/0` instead of an inline list
- [x] 1.3 Update `TennisTracker.Tennis.TeamType` NTRP validation to reference `NtrpLevels.team_levels/0` instead of an inline list
- [x] 1.4 Verify compile passes and existing player/team type tests still pass

## 2. SeasonRules — Nullable Fields and Validations

- [x] 2.1 Change `min_roster`, `max_roster`, and `on_level_min_pct` to `allow_nil?(true)` on the `SeasonRules` resource
- [x] 2.2 Add conditional validation: `min_roster` must be a positive integer when present (apply to `:create` and `:update` actions)
- [x] 2.3 Add conditional validation: `max_roster` must be a positive integer when present (apply to `:create` and `:update` actions)
- [x] 2.4 Add conditional validation: `on_level_min_pct` must be between 0.0 and 100.0 inclusive when present (apply to `:create` and `:update` actions)
- [x] 2.5 Generate Ash migration: `mix ash_postgres.generate_migrations --name nullable_season_rules_fields`
- [x] 2.6 Run `mix ecto.migrate` and verify the migration applies cleanly
- [x] 2.7 Update seeds if any SeasonRules records rely on non-nullable behavior; verify seeds run cleanly

## 3. Team — Remove Captain, Add Default Sort

- [x] 3.1 Remove the `captain` attribute from `TennisTracker.Tennis.Team`
- [x] 3.2 Remove `captain` from all `accept` lists in Team actions (`:create`, `:update`)
- [x] 3.3 Remove any `captain` references from seeds, test fixtures, and the LiveView
- [x] 3.4 Add resource-level default sort to the Team primary `:read` action via a `prepare` block: `season_year: :desc`, then `team_type.age_group: :asc_nils_last`, then `team_type.ntrp_level: :desc_nils_last`, then `name: :asc`
- [x] 3.5 Verify relationship-path sort compiles and works in AshPostgres; if nil handling across the join is unsupported, introduce `calculate :team_type_age_group` and `calculate :team_type_ntrp_level` using `expr(team_type.age_group)` / `expr(team_type.ntrp_level)` and sort on those instead
- [x] 3.6 Generate Ash migration: `mix ash_postgres.generate_migrations --name remove_team_captain`
- [x] 3.7 Run `mix ecto.migrate` and verify

## 4. TeamType — Nullable Fields

- [x] 4.1 Change `ntrp_level` and `age_group` to `allow_nil?(true)` on the `TeamType` resource
- [x] 4.2 Add `where([present(:ntrp_level)])` guard to the existing `attribute_in(:ntrp_level, ...)` validation
- [x] 4.3 Add `where([present(:age_group)])` guard to the existing `attribute_in(:age_group, ...)` validation
- [x] 4.4 Generate Ash migration: `mix ash_postgres.generate_migrations --name nullable_team_type_fields`
- [x] 4.5 Run `mix ecto.migrate` and verify

## 5. Ash.Notifier.PubSub on Team and TeamMembership

- [x] 5.1 Add `Ash.Notifier.PubSub` configuration to `TennisTracker.Tennis.Team` with a dynamic topic function producing `roster:{team_type_id}:{season_year}` for create, update, and destroy actions
- [x] 5.2 Add `Ash.Notifier.PubSub` configuration to `TennisTracker.Tennis.TeamMembership` with a dynamic topic function producing `roster:{team_type_id}:{season_year}` for create, update, and destroy actions
- [x] 5.3 Update `RosterPlannerLive` to subscribe with `Ash.Notifier.PubSub.subscribe/1` (or the appropriate Ash subscribe mechanism) instead of `Phoenix.PubSub.subscribe`
- [x] 5.4 Update `handle_info` in `RosterPlannerLive` to pattern-match on `%Ash.Notifier.Notification{}` instead of `{:roster_updated, _}`
- [x] 5.5 Remove the `broadcast_update/1` helper and all manual `Phoenix.PubSub.broadcast` calls from `RosterPlannerLive`
- [x] 5.6 Verify real-time sync works end-to-end: move a player in one session, confirm the second session updates

## 6. RosterPlannerLive — load_board DB Filtering

- [x] 6.1 Add `Tennis.list_eligible_unassigned_players/3` domain function (takes `team_type`, `team_type_id`, `season_year`) that queries `Player` with age-group eligibility, NTRP level filter (nil-rated players included), and `not exists(team_memberships, ...)` for the given context
- [x] 6.2 Sort results by `ntrp_rating: :desc_nils_last, name: :asc` within the query
- [x] 6.3 Update `load_board` in `RosterPlannerLive` to call `Tennis.list_eligible_unassigned_players/3` instead of `Tennis.list_players!/0` + in-memory filtering
- [x] 6.4 Remove the `eligible_for_team_type?/2` private helper from `RosterPlannerLive`
- [x] 6.5 Remove the in-memory `assigned_player_ids` MapSet and `Enum.reject` call from `load_board`
- [x] 6.6 Run existing eligibility unit tests and update as needed

## 7. RosterPlannerLive — Team Modal

- [x] 7.1 Add `@team_modal` assign (default `nil`) to `mount/3`; remove `:renaming_team_id`, `:rename_value`, `:deleting_team_id`, `:show_new_team_form`, `:new_team_name` assigns
- [x] 7.2 Add event handlers: `open_team_modal` (with `mode` + optional `team_id` params), `close_team_modal`, `validate_team_form`, `submit_team_form`, `confirm_delete_team`
- [x] 7.3 Implement `open_team_modal` for `:create` mode: set `@team_modal` to `%{mode: :create, form: AshPhoenix.Form.for_create(Team, :create, ...), team: nil}`
- [x] 7.4 Implement `open_team_modal` for `:edit` mode: look up team from board, set `@team_modal` to `%{mode: :edit, form: AshPhoenix.Form.for_update(team, :update, ...), team: team}`
- [x] 7.5 Implement `open_team_modal` for `:delete` mode: set `@team_modal` to `%{mode: :delete, form: nil, team: team}`
- [x] 7.6 Implement `validate_team_form`: call `AshPhoenix.Form.validate/2` and update `@team_modal.form`
- [x] 7.7 Implement `submit_team_form`: call `AshPhoenix.Form.submit/2`; on success close modal and reload board; on error update form with errors
- [x] 7.8 Implement `confirm_delete_team`: call `Tennis.delete_team/1`, close modal, reload board
- [x] 7.9 Render modal overlay in `render/1` when `@team_modal` is not nil; show create/edit form (with `<.form>` and field errors) or delete confirmation UI based on `mode`
- [x] 7.10 Update `board_column` component: replace inline rename/delete UI with buttons that emit `open_team_modal` events; remove `renaming`, `rename_value`, `deleting` attrs
- [x] 7.11 Update all LiveView tests for team create, rename, and delete to use new modal event names and patterns
- [x] 7.12 Run `mix precommit` and fix any warnings or failures
