## 1. Dependencies and Configuration

- [ ] 1.1 Add `{:tzdata, "~> 1.1"}` to `mix.exs` deps and run `mix deps.get`
- [ ] 1.2 Add `config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase` to `config/config.exs`
- [ ] 1.3 Add `config :tzdata, :autoupdate, :disabled` to `config/runtime.exs` (production safety)

## 2. Data Model: Team default_timezone

- [ ] 2.1 Add `default_timezone` (`:string`, nullable, `public?(true)`, `default("America/Chicago")`) attribute to `TennisTracker.Tennis.Team`
- [ ] 2.2 Add `default_timezone` to the `accept` list of `Team`'s `:update` action
- [ ] 2.3 Run `mix ash_postgres.generate_migrations --name add_team_default_timezone` and verify the generated migration

## 3. Data Model: Match match_start_datetime (additive step)

- [ ] 3.1 Add `match_start_datetime` (`:utc_datetime`, `allow_nil?(true)` initially, `public?(true)`) attribute to `TennisTracker.Tennis.Match`
- [ ] 3.2 Run `mix ash_postgres.generate_migrations --name add_match_start_datetime` and verify the generated migration
- [ ] 3.3 Run `mix ecto.migrate` to apply the additive migration

## 4. Data Migration: Backfill match_start_datetime

- [ ] 4.1 Write a raw Ecto SQL migration that sets `match_start_datetime` from `(match_date::text || ' ' || match_time::text)::timestamp AT TIME ZONE timezone` for all existing rows
- [ ] 4.2 Run the backfill migration and verify row counts before/after

## 5. Data Model: Make match_start_datetime non-nullable, drop old fields

- [ ] 5.1 Change `match_start_datetime` attribute to `allow_nil?(false)` in `Match`
- [ ] 5.2 Remove `match_date` and `match_time` attributes from `Match`
- [ ] 5.3 Update the `:create` action `accept` list: remove `match_date`/`match_time`, add `match_start_datetime`
- [ ] 5.4 Run `mix ash_postgres.generate_migrations --name finalize_match_start_datetime` and verify the migration sets NOT NULL and drops both old columns
- [ ] 5.5 Run `mix ecto.migrate`

## 6. Match Read Actions

- [ ] 6.1 Update `list_upcoming_matches_for_team` filter to `match_start_datetime >= fragment("NOW()")` and sort by `match_start_datetime` ascending
- [ ] 6.2 Update `next_upcoming_match_for_team` filter and sort identically
- [ ] 6.3 Update `list_past_matches_for_team` filter to `match_start_datetime < fragment("NOW()")` and sort by `match_start_datetime` descending
- [ ] 6.4 Remove the custom `match_date` index from the `postgres` block and add an index on `[:team_id, :match_start_datetime]`

## 7. Team Aggregates

- [ ] 7.1 Remove `next_match_date` and `next_match_time` aggregates from `Team`
- [ ] 7.2 Add `next_match_start_datetime` aggregate (`:first`, field `:match_start_datetime`, filter `match_start_datetime >= fragment("NOW()")`, sort `[match_start_datetime: :asc]`)
- [ ] 7.3 Verify `Tennis.list_real_teams!` domain function passes through `load:` options (it does — load list update is in task 8.2)

## 8. LiveView: Teams IndexLive

- [ ] 8.1 Update `format_next_match/2` to accept a UTC `DateTime` and a timezone string; shift zone and format as a single string (e.g. "Mon, Apr 6 · 9:00 AM")
- [ ] 8.2 Update `Tennis.list_real_teams!` load to `[:team_type_name, :next_match_start_datetime, :default_timezone]` (default_timezone is needed for display conversion)
- [ ] 8.3 Update the template to call `format_next_match(team.next_match_start_datetime, team.default_timezone)`

## 9. LiveView: Teams ShowLive — display

- [ ] 9.1 Replace `format_match_date/1` and `format_match_time/1` helpers with a single `format_match_datetime/2` that accepts a UTC `DateTime` and a timezone string, shifts zone, and returns `{date_str, time_str}`
- [ ] 9.2 Update the upcoming matches stream template to call the new formatter with `match.match_start_datetime` and `match.timezone`
- [ ] 9.3 Update the past matches stream template similarly

## 10. LiveView: Teams ShowLive — match creation form

- [ ] 10.1 Load `team.default_timezone` alongside the form in `handle_event "open_match_form"`; assign it as `@team_timezone` (falling back to `"America/Chicago"` if nil)
- [ ] 10.2 Keep separate `<.input field={@form[:match_date]} type="date">` and `<.input field={@form[:match_time]} type="time">` inputs; remove any timezone selector (no per-match timezone UX)
- [ ] 10.3 Extract a private `build_match_datetime_params/3` function that takes date string, time string, and timezone; parses them into a `NaiveDateTime`; calls `DateTime.from_naive/2` handling `:ambiguous` (use `:after` interpretation) and `:gap` (shift forward); returns `{:ok, utc_datetime}` or `{:error, reason}`
- [ ] 10.4 Update `handle_event "validate_match"` to call `build_match_datetime_params/3` with `@team_timezone`; on success inject `match_start_datetime` and `timezone` into params before `AshPhoenix.Form.validate/2`; on error assign a `@datetime_error` flash-style message
- [ ] 10.5 Update `handle_event "save_match"` to call `build_match_datetime_params/3`; on error put a human-readable flash ("Date or time is invalid — please check the values you entered") and return without submitting; on success inject `match_start_datetime` and `timezone` into params before `AshPhoenix.Form.submit/2`
- [ ] 10.6 Remove `match_date` and `match_time` from the Ash create action's `accept` list (done in task 5.3); ensure `match_start_datetime` and `timezone` are accepted

## 11. LiveView: Matches ShowLive

- [ ] 11.1 Replace `format_match_date/1` and `format_match_time/1` with a single helper that shifts `match.match_start_datetime` to `match.timezone` and formats date + time separately
- [ ] 11.2 Update the template's "Date & Time" section to use the new formatter

## 12. Factory and Tests

- [ ] 12.1 Update `Factory.match/1`: replace `match_date`/`match_time` defaults with `match_start_datetime: DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.truncate(:second)`
- [ ] 12.2 Update `MatchTest` create tests: replace `match_date`/`match_time` params with `match_start_datetime`
- [ ] 12.3 Update `MatchTest` `list_upcoming_matches_for_team` test: express past/future matches via `match_start_datetime` offsets from `DateTime.utc_now()`
- [ ] 12.4 Update `MatchTest` `list_past_matches_for_team` test similarly
- [ ] 12.5 Update `ShowLiveTest` (teams) to use `match_start_datetime` in factory calls
- [ ] 12.6 Update `IndexLiveTest` (teams) to use `next_match_start_datetime` in assertions

## 13. Verification

- [ ] 13.1 Run `mix precommit` (compile warnings-as-errors, format, all tests pass)
- [ ] 13.2 Manually verify match creation form in dev: create a match, confirm UTC value stored, confirm display shows correct local time
- [ ] 13.3 Verify teams index page shows correct "next match" time in local timezone
