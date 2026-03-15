## 1. Create the factory module

- [x] 1.1 Create `test/support/factory.ex` with the `TennisTracker.Factory` module skeleton
- [x] 1.2 Implement `team_type/1` with unique name default and trait support (`:_35`, `:_40`, `:_40_plus_35`, `:_40_plus_40`)
- [x] 1.3 Implement `player/1` with unique name default and trait support (`:unrated`, `:eligible_40_plus`, `:eligible_55_plus`, `:ineligible`)
- [x] 1.4 Implement `team/1` with `team_type:` special key, auto-create fallback, `season_year` default, and `:pseudo` trait
- [x] 1.5 Implement `season_rules/1` with `team_type:` special key, auto-create fallback, and `season_year` default
- [x] 1.6 Implement `team_membership/1` with `player:` and `team:` special keys, auto-create fallbacks, and derivation of `team_type_id` and `season_year` from the team

## 2. Remove ExMachina

- [x] 2.1 Remove the `{:ex_machina, ...}` dependency from `mix.exs`
- [x] 2.2 Remove `{:ok, _} = Application.ensure_all_started(:ex_machina)` from `test/test_helper.exs`
- [x] 2.3 Run `mix deps.unlock ex_machina` and `mix deps.get` to clean up the lockfile

## 3. Wire factory into test support cases

- [x] 3.1 Add `alias TennisTracker.Factory` to the `using` block in `test/support/data_case.ex`
- [x] 3.2 Add `alias TennisTracker.Factory` to the `using` block in `test/support/conn_case.ex`

## 4. Refactor existing tests to use the factory

- [x] 4.1 Refactor `test/tennis_tracker/tennis/team_roster_test.exs` — remove local `create_*` helpers; replace inline `Tennis.create_team_membership!/1` calls with `Tennis.assign_player/4`
- [x] 4.2 Refactor `test/tennis_tracker_web/live/roster_planner_live_test.exs` — remove local `create_*` helpers; replace inline `Tennis.create_team!/1` calls with `Factory.team/1`
- [x] 4.3 Refactor `test/tennis_tracker_web/live/teams/show_live_test.exs` — remove local `create_*` helpers
- [x] 4.4 Refactor `test/tennis_tracker_web/live/players/index_live_test.exs` — remove local `create_player/1` helper
- [x] 4.5 Refactor `test/tennis_tracker/tennis/player_filters_test.exs` — remove local `create_player/1` helper
- [x] 4.6 Refactor `test/tennis_tracker/tennis/list_real_teams_test.exs` — remove local `create_team_type/1` and `create_team/2` helpers
- [x] 4.7 Refactor `test/tennis_tracker_web/controllers/player_csv_controller_test.exs` — remove local `create_player/1` helper; keep `parse_csv/1`

## 5. Verify

- [x] 5.1 Run `mix test` and confirm all tests pass
