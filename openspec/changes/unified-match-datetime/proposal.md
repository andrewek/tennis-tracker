## Why

`match_date` and `match_time` are stored as separate fields, requiring manual recombination and timezone-aware SQL fragments (`CAST(NOW() AT TIME ZONE ...)`) everywhere they are compared. Consolidating to a single UTC `match_start_datetime` simplifies filtering, sorting, and display logic, while making timezone intent explicit in the data model rather than buried in query fragments.

## What Changes

- **BREAKING** Remove `match_date` (:date) and `match_time` (:time) attributes from `Match`
- Add `match_start_datetime` (:utc_datetime) to `Match` — stores the moment a match starts as UTC
- Keep `timezone` on `Match` (already exists, default "America/Chicago") — used for display conversion and as the interpretation context when the user enters a local date+time on the form
- Add `default_timezone` (:string) to `Team` — seeds the match creation form's timezone picker; defaults to "America/Chicago"
- Replace Team aggregates `next_match_date` / `next_match_time` with a single `next_match_start_datetime`
- Update all read actions on `Match` that filter/sort on `match_date`/`match_time` to use `match_start_datetime`
- Update the match creation form: replace separate date + time inputs with a local datetime input + a timezone selector (pre-filled from team's `default_timezone`); convert to UTC before saving
- Update all display sites that format `match_date` / `match_time` to format the UTC datetime in the match's stored `timezone`
- Add `tzdata` dependency and configure Elixir's time zone database (currently absent — timezone conversion in Elixir requires it)
- Write a data migration to convert existing rows (combining `match_date` + `match_time` + `timezone` into a UTC `timestamptz`)

## Capabilities

### New Capabilities

- `match-datetime-unification`: Replace the split date/time fields on Match with a single UTC datetime, including form UX for local-time entry with timezone selection and display conversion back to local time

### Modified Capabilities

- `team-management`: Add `default_timezone` field to Team (used to pre-populate the timezone picker on match creation)

## Impact

**Ash resources:** `Match` (attributes, read actions, create action), `Team` (new attribute, aggregates)

**LiveViews:**
- `TennisTrackerWeb.Teams.ShowLive` — match creation form, match list display (date/time formatting)
- `TennisTrackerWeb.Teams.IndexLive` — `next_match_date`/`next_match_time` aggregate replaced
- `TennisTrackerWeb.Matches.ShowLive` — date/time display

**Tests:** `MatchTest`, `ShowLive` test (teams), `IndexLive` test (teams), `Factory` (match/0)

**Dependencies:** `tzdata ~> 1.1` must be added to `mix.exs`; `config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase` must be set in `config/config.exs`

**Migrations:** One migration to add `match_start_datetime`, back-fill from existing columns, then drop `match_date`/`match_time`; one migration to add `default_timezone` to teams
