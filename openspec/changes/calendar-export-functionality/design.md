## Context

The app has an existing file-export pattern in `PlayerCSVController` — a plain Phoenix controller that resolves a group, verifies group membership, fetches data, and streams a response with an appropriate content-type header. The calendar export follows this same pattern.

Match records store `match_start_datetime` in UTC and carry a `timezone` field (IANA timezone name, e.g. `"America/Chicago"`). Duration is stored as `duration_minutes` (default 90). Location is an optional `belongs_to` on Match.

The `Location` resource currently stores address data as a single opaque string. This makes it impossible to compose a machine-readable address for calendar clients. Structured fields are required.

The `Team` resource has expression calculations for `team_type_name`, `team_type_age_group`, and `team_type_ntrp_level`, but no composed display label. The `TeamMembership` resource has a `:display_label` fragment calc (`"2026 40+ 4.0 - Team Name"`) that is the right shape but lives in the wrong place.

## Goals / Non-Goals

**Goals:**
- One-click `.ics` download for a team's complete match schedule
- iCal events use local time (not UTC) for matches
- Location renders as a proper address in calendar clients, with optional map link
- Team identity is clear in event titles (division, year, team name)
- Location resource uses structured address fields composable into a formatted string

**Non-Goals:**
- Live calendar subscription URL (future work)
- Structured address validation or normalization (e.g. no zip format check, no geocoding); inputs are trimmed of whitespace only
- Country field on Location (US-only assumption is acceptable)
- Migrating existing production data (no production data exists)
- iCal line folding (RFC 5545 requires lines ≤ 75 octets; all major consumer calendar clients tolerate unfolded lines for download-only `.ics` files; folding is only necessary when serving via a CalDAV server, which is not in scope)

## Decisions

### Hand-roll iCal vs. library

No Elixir iCal library is in the deps. The iCal format required here is a fixed subset: one VCALENDAR, N VEVENTs, each with a small set of fields. Adding a library for ~40 lines of template logic introduces maintenance overhead with no meaningful benefit. **Decision: hand-roll.**

### DTSTART/DTEND with TZID vs. UTC

Calendar events for sports schedules should reflect local time — "10am Chicago time" is meaningful regardless of where a team member's device is set. Using `DTSTART;TZID=America/Chicago:20260401T100000` ensures the event anchors to the correct local wall-clock time and handles DST correctly. Using UTC (Z-suffix) would display incorrectly for members in non-local timezones. **Decision: use TZID with the match's `timezone` field.**

### Structured address fields vs. single string

A single `address` string cannot be reliably parsed into components, and calendar clients need a well-formed address string to render map links. Structured fields (`street_address`, `city`, `state`, `postal_code`) give deterministic composition via a `formatted_address` expression calculation. The location management forms become more guided as a side effect. All four fields are nullable — a location can be created with a name only and address fields filled in later. The `formatted_address` calc returns nil when all fields are nil; display contexts must handle nil gracefully. **Decision: structured fields, nullable, hard cutover, rework seeds.**

### display_label belongs on Team, not TeamMembership

The display label describes a team's identity. `TeamMembership.display_label` happens to have the right shape but is computed from `TeamMembership.season_year` (a denormalized field on the membership record) plus path traversals to `team.team_type.name` and `team.name`. `Team` also has its own `season_year` field. Adding `:display_label` and `:short_display_label` directly to `Team` (using `Team.season_year`, `team_type.name`, and `name`) makes the calc available wherever a `Team` is loaded. `TeamMembership.display_label` is left unchanged — it uses a different `season_year` source and serves a different rendering context (player profile membership history). The calcs are intentionally parallel, not duplicates. **Decision: calcs live on Team; TeamMembership.display_label is untouched.**

### Two display label variants

Calendar event titles should not include the year (`"40+ 4.0 - Team Name v. Springfield"` reads more naturally inline), but other views that show memberships across years need year disambiguation (`"2026 40+ 4.0 - Team Name"`). **Decision: `:display_label` includes year, `:short_display_label` omits it.**

### iCal LOCATION field format

The iCal `LOCATION` property supports an `ALTREP` parameter for a URI (e.g. a Google Maps URL). When present, Apple Calendar and Google Calendar render a tappable map link. The text value of the property should be the venue name and formatted address separated by `\n`. When `google_maps_url` is nil, the `ALTREP` parameter is omitted. When `location_id` is nil on the match, the `LOCATION` property is omitted entirely.

```
LOCATION;ALTREP="https://maps.google.com/...":West Side TC\n123 Main St\, Springfield\, IL 62701
```

### Controller auth

Any authenticated group member can export a team's calendar. This matches the intent for `PlayerCSVController` (same `verify_membership` check). Authorization is handled at the controller level; no new Ash policy needed.

## Risks / Trade-offs

- **iCal line length**: The iCal spec requires long lines to be folded at 75 octets. Line folding is explicitly out of scope (see Non-Goals). All major consumer calendar clients tolerate unfolded lines for downloaded `.ics` files; this only becomes an issue if a CalDAV subscription endpoint is added in the future.
- **TZID portability**: Using IANA timezone names (`America/Chicago`) requires the receiving calendar client to know the timezone. All major calendar apps (Apple, Google, Outlook) support IANA names. Obscure or legacy clients may not.
- **duration_minutes accuracy**: The 90-minute default is a calendar placeholder; real matches run longer. The iCal event end time reflects `duration_minutes`, not actual match duration. No mitigation — this is expected behavior, not a bug.

## Migration Plan

No production data exists. The migration is a single-step cutover:

1. Add `street_address`, `city`, `state`, `postal_code` as non-nullable fields; remove `address` from the `Location` resource
2. Rework seeds file with structured address data
3. Generate Ash migration: `mix ash_postgres.generate_migrations --name structured_location_address`
4. Run `mix ecto.reset` — drops, recreates, migrates, and reseeds in one step

Rollback: `mix ecto.rollback` then revert the resource changes. No production data at risk.
