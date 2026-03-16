## Context

The team show page currently has a schedule section rendering hardcoded placeholder data. The Tennis domain has established Ash resources (Team, Player, TeamMembership, TeamType, Season) but no concept of matches or venues. Team captains need to input their season schedule and players need to see when and where matches are happening.

Calendar export (iCal/ICS) is a stated future goal. The data model must support it without requiring a migration later.

## Goals / Non-Goals

**Goals:**
- `Location` resource: shared, pre-seeded venues with name, address, and a Google Maps URL
- `Match` resource: belongs to a Team; has a date, a start time, an opponent name, a home/away flag, and a location
- Team show page: replace placeholder schedule with real match data, split into upcoming and past sections
- Match show page: full details for a single match
- Seed data for the most common known locations

**Non-Goals:**
- Calendar export (future work — data model will support it)
- Match lineup / player availability management
- Recurring match templates
- Mobile deep-link handling for map apps (future work)
- Admin CRUD UI for locations (seed via Elixir seed script for now)

## Decisions

### 1. Store match datetime as separate `date` (`:date`) and `time` (`:time`) fields, plus an IANA timezone string and a `duration_minutes` integer

**Rationale:** Tennis matches are scheduled in local time. Storing a naive local date + time + explicit timezone string allows the system to convert to UTC for iCal export (`DTSTART;TZID=America/Chicago:...`) without losing the "human" scheduled time that users entered. Storing a single UTC timestamp would require knowing the timezone at write time and would make the display value derived; storing only naive local datetime would block accurate iCal export.

`duration_minutes` defaults to 90 and maps to iCal `DURATION:PT90M` (or can be used to compute `DTEND`). It is stored now so the export path is clean; a UI to edit it is future scope.

**Alternatives considered:**
- Single `DateTime` (UTC): requires timezone at write time, harder to display correctly across DST boundaries.
- `NaiveDateTime`: simpler, but iCal export requires a timezone — we'd have to store it somewhere anyway.
- Separate `end_time` field: requires computing and storing a derived value on create; `duration_minutes` is simpler and equally expressive for iCal.

**Default timezone:** The app currently serves a single tennis league; we will default to `America/Chicago` (configurable via application config) and store it per-match for correctness.

**"Today" for upcoming/past split:** Computed as today's date in the match's stored IANA timezone (`DateTime.now!(timezone) |> DateTime.to_date()`), so the boundary reflects the match's local calendar day rather than the server's UTC date.

### 2. `Location` is a standalone resource, not embedded in `Match`; `location_id` on `Match` is nullable

**Rationale:** Locations are shared between teams and stable across seasons. Captains should pick from a list rather than type free-form text each time. A standalone resource allows seeding, management, and reuse. A `google_maps_url` attribute is stored directly on the resource.

`location_id` is nullable because a match may be created before the venue is confirmed. The UI shows "TBD" when no location is set. Location deletion is not supported in this scope; archiving is a future addition (see todo.md).

**Alternatives considered:**
- Embedded map / string field on `Match`: simpler but doesn't support the "pick from known venues" UX.
- Non-nullable `location_id`: too strict — captains often enter the schedule before all venues are confirmed.
- Separate `Address` resource: over-engineered for current needs.

### 3. Upcoming vs. past split on the team show page — done at the query level

**Rationale:** AGENTS.md prohibits Elixir-level filtering; DB-level `filter` in a read action or `Ash.Query.filter` is required. We will define two read actions on `Match` (or filter in the LiveView with `Ash.Query.filter(date >= today)` / `date < today`) and stream them into separate assigns.

### 4. Match show page uses a separate LiveView at `/matches/:id`

**Rationale:** Keeps routing simple and decoupled from the team URL hierarchy. A match belongs to exactly one team; the show page can link back to the team.

### 5. No captain/auth guard on match creation for this scope

**Rationale:** The app currently uses a single `:user` role with no role-based write restrictions on team data. Adding captain-only writes is future scope.

### 6. Seed locations via `priv/repo/seeds.exs` using Ash domain functions

**Rationale:** Consistent with how other seed data would be added. `on_conflict: :nothing` (or equivalent Ash upsert) avoids duplicate inserts on re-seed.

## Risks / Trade-offs

- **Timezone default assumption** → Mitigation: Store timezone per-match (not globally). If the league ever expands or someone schedules a match while traveling, the stored timezone is still correct. The upcoming/past boundary is computed in the match's local timezone to avoid UTC-vs-local drift; see todo.md for a note on a future explicit `completed` flag as a more robust alternative.
- **`home_or_away` enum** → Use `Ash.Type.Enum` (a dedicated module) rather than a plain `:atom` type; this ensures correct form casting and changeset error messages.
- **Location list grows stale** → Mitigation: Admin CRUD for locations is a small future addition; the standalone resource makes it straightforward to add later.
- **Ash stream reset pattern for past/upcoming** → The two sections cannot share one stream. We will use two separate streams (`stream(:upcoming_matches, ...)` and `stream(:past_matches, ...)`), each fed by a separate filtered query. This is consistent with the established pattern in this codebase.

## Migration Plan

1. Add `Location` and `Match` Ash resources
2. Run `mix ash_postgres.generate_migrations --name add_locations_and_matches`
3. Run `mix ecto.migrate`
4. Seed known locations via `mix run priv/repo/seeds.exs`
5. Update team show LiveView to replace placeholder with real streams
6. Add match show LiveView and route
7. Update router

Rollback: drop the two new tables (no existing data depends on them).

## Open Questions

- Should match creation/editing be in scope for this change, or only display? (Assumed: yes, basic CRUD for matches is in scope so the schedule isn't empty.)
- Who can create/edit matches — any authenticated user, or only the team captain? (Assumed: any authenticated user for now, consistent with current app behavior.)
