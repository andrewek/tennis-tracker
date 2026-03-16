## Context

`Match` currently stores `match_date` (:date) + `match_time` (:time) + `timezone` (:string). All "upcoming vs. past" filtering uses a PostgreSQL fragment to cast `NOW()` into the match's stored timezone before comparing to the date. The team aggregates (`next_match_date`, `next_match_time`) expose two fields to callers instead of one. Display code in three LiveViews manually combines them.

Elixir's `Calendar` module ships with UTC only; supporting timezone conversion (e.g. "America/Chicago" → UTC) requires the `tzdata` library, which is **not currently in the project**.

## Goals / Non-Goals

**Goals:**
- Replace `match_date` + `match_time` with a single `match_start_datetime` (:utc_datetime / `timestamptz`) on `Match`
- Keep `timezone` on `Match` as the display/entry timezone; it is NOT removed
- Add `default_timezone` to `Team` to seed the match creation form
- Add `tzdata` and configure `Tzdata.TimeZoneDatabase` globally
- Update all filtering, sorting, aggregates, LiveViews, factory, and tests to use the new field
- Write a data migration that back-fills `match_start_datetime` from existing rows

**Non-Goals:**
- Multi-timezone user preferences or per-user timezone detection
- Supporting non-US timezones in the UI (can be added later)
- Removing the `timezone` field from `Match` (it is still needed for display)

## Decisions

### 1. Ash type: `:utc_datetime`

Use `:utc_datetime` (not `:datetime`). AshPostgres maps `:utc_datetime` to `timestamptz`, which PostgreSQL stores in UTC and returns in UTC. This eliminates any ambiguity at the DB layer.

*Alternative considered:* `:naive_datetime` — ruled out because it loses timezone information entirely at the persistence layer.

### 2. Add `tzdata ~> 1.1` dependency

`DateTime.shift_zone/2` requires a configured time zone database. Add `{:tzdata, "~> 1.1"}` to `mix.exs` and set `config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase` in `config/config.exs`. This is the standard Elixir approach and the only real option.

*Alternative considered:* `:tz` library — functionally equivalent; `tzdata` is more widely used in the Ash/Phoenix ecosystem.

### 3. Form UX: separate date + time inputs, team timezone used for conversion

The match creation form keeps separate `<input type="date">` and `<input type="time">` inputs. No per-match timezone selector. The LiveView `save_match` handler:

1. Reads `team.default_timezone` (already loaded when the form is opened), falling back to `"America/Chicago"` if nil
2. Combines the date and time strings into a `NaiveDateTime`
3. Calls `DateTime.from_naive(naive, timezone)` to get a local `DateTime`, handling `:ambiguous`/`:gap` DST edge cases
4. Shifts to UTC and passes `match_start_datetime` (UTC) + `timezone` (team's default) into the Ash create params

The `validate_match` handler applies the same date+time combination and UTC conversion before calling `AshPhoenix.Form.validate/2`, so validation errors appear correctly as the user types. If the date or time string is unparseable, a flash error is shown with a human-readable message ("Date or time is invalid — please check the values you entered") rather than surfacing the raw Ash field name.

The per-match `timezone` field is set to `team.default_timezone` at creation and is used as the display timezone. Since all matches for a team are in the same timezone, this is self-contained and no team relationship load is needed at display time.

*Alternative considered:* `<input type="datetime-local">` — ruled out due to inconsistent browser UX (especially iOS Safari) and the added complexity of parsing a naive datetime string in both save and validate handlers.

*Alternative considered:* Per-match timezone selector — ruled out for this iteration. All teams are in US/Central; cross-timezone matches (e.g. Nationals travel) are out of scope.

### 4. Display: convert UTC back to team's timezone on render

In all LiveViews, format `match_start_datetime` by:
1. `DateTime.shift_zone!(match.match_start_datetime, match.timezone)` to get a local `DateTime`
2. Format date and time from the shifted value

`match.timezone` is always set to `team.default_timezone` at creation (falling back to `"America/Chicago"`), so the match is self-contained for display — no extra team relationship load is needed at render time.

For the Teams IndexLive `next_match_start_datetime` aggregate: use `team.default_timezone` directly (it is already loaded alongside the aggregate). Since `match.timezone == team.default_timezone` for all matches, this is equivalent.

### 5. Migration strategy: backfill then drop

The Ash migration (generated via `mix ash_postgres.generate_migrations`) adds `match_start_datetime` as nullable first. A separate raw SQL migration back-fills:

```sql
UPDATE matches
SET match_start_datetime = (
  (match_date::text || ' ' || match_time::text)::timestamp AT TIME ZONE timezone
);
```

Then a third migration sets `match_start_datetime NOT NULL` and drops `match_date`/`match_time`.

This three-step approach keeps the migration reversible and avoids a single destructive step.

*Alternative:* Do it in one migration — riskier; harder to validate the backfill before removing the source columns.

### 6. Team aggregates

Replace `next_match_date` (`:date`) and `next_match_time` (`:time`) aggregates on `Team` with a single `next_match_start_datetime` (`:utc_datetime`). All callers (IndexLive) display via the same UTC-to-local conversion path.

### 7. DST ambiguity

`DateTime.from_naive/2` will return `{:ambiguous, ...}` or `{:gap, ...}` for ambiguous/non-existent wall times (e.g. spring-forward gaps). The LiveView form `save_match` handler will handle this by taking the `:after` (post-DST) interpretation on ambiguous times, which is the least surprising default for a sports scheduling context. A flash warning can be shown.

## Risks / Trade-offs

- **Existing data**: The SQL backfill depends on `timezone` being accurate for every existing row. Rows with an incorrect timezone will silently store the wrong UTC time. → Mitigation: The default is already "America/Chicago" and all current users are in US/Central; risk is low.

- **DST boundary matches**: Matches scheduled during the spring-forward hour (e.g. 2:30 AM CT on the transition day) will be silently shifted. → Mitigation: Tennis matches are never at 2 AM; irrelevant in practice.

- **`tzdata` download at compile/startup**: `tzdata` downloads timezone data on first run if not bundled. In production, ensure `config :tzdata, :autoupdate, :disabled` and bundle the data or pin a version. → Add this config note to `config/runtime.exs`.

- **Test isolation**: Tests that create matches with relative dates (e.g. `Date.utc_today() |> Date.add(7)`) will need to be expressed as UTC datetimes. The factory `match/1` will accept `match_start_datetime` and default to `DateTime.utc_now() |> DateTime.add(7, :day)`. → Update factory accordingly.

## Migration Plan

1. Add `tzdata` to `mix.exs`; configure `Tzdata.TimeZoneDatabase` in `config/config.exs`
2. Add `default_timezone` to `Team` → `mix ash_postgres.generate_migrations --name add_team_default_timezone`
3. Add `match_start_datetime` (nullable) to `Match` → `mix ash_postgres.generate_migrations --name add_match_start_datetime`
4. Write a manual SQL migration to backfill `match_start_datetime` from `match_date + match_time + timezone`
5. Generate migration to set `match_start_datetime NOT NULL` and drop `match_date`/`match_time`
6. Update Ash resource, read actions, aggregates, domain functions, LiveViews, factory, and tests
7. Run `mix precommit` to verify

**Rollback:** Re-add `match_date`/`match_time` columns and reverse the backfill SQL (UTC → local date + time using stored `timezone`). No data loss if done before column drop.

## Resolved Decisions

1. **`default_timezone` on Team:** Nullable, with a column default of `"America/Chicago"` (set at the DB level via the migration). The match form falls back to `"America/Chicago"` when the value is nil.

2. **No per-match timezone selector:** The form does not expose a timezone picker. The team's `default_timezone` is used for both UTC conversion at creation and display thereafter. Cross-timezone matches (away travel) are explicitly out of scope.

3. **`next_match_start_datetime` display in IndexLive:** Single formatted string (e.g. "Mon, Apr 6 · 9:00 AM") converted using `team.default_timezone`. Split to two lines only if it doesn't fit at narrow breakpoints (CSS concern, not logic concern).

4. **`tzdata` autoupdate:** Disabled in production via `config :tzdata, :autoupdate, :disabled` in `config/runtime.exs`.
