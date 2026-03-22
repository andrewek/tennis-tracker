## 1. Location Resource — Structured Address Fields

- [ ] 1.1 Add `street_address`, `city`, `state`, `postal_code` attributes to `Location` resource (all nullable — address fields are optional); remove `address` attribute; update `:create` and `:update` actions to accept the new fields; add `trim/1` string preparation to each new field to strip leading/trailing whitespace
- [ ] 1.2 Add `formatted_address` expression calculation to `Location` resource composing the four fields into `"street_address, city, state postal_code"`; return nil when all four fields are nil; all display contexts using `formatted_address` must handle nil gracefully (omit the address line rather than rendering "nil")
- [ ] 1.3 Rework `priv/repo/seeds.exs` to use the four structured address fields for all seeded locations (two locations for the small group, one or more for the large group)
- [ ] 1.4 Generate Ash migration: `mix ash_postgres.generate_migrations --name structured_location_address`
- [ ] 1.5 Run `mix ecto.reset` to drop, recreate, migrate, and reseed the dev DB
- [ ] 1.6 Update the location settings index LiveView to display `location.formatted_address` where `location.address` was shown; handle nil `formatted_address` gracefully (omit or show a placeholder)
- [ ] 1.7 Update the location settings form LiveView (`new` and `edit`) to replace the single `address` input with four optional inputs: `street_address`, `city`, `state`, `postal_code`
- [ ] 1.8 Update the match show LiveView to replace `@match.location.address` with `@match.location.formatted_address`; keep `@match.location.name` as the prominent venue name display; handle nil `formatted_address` (omit address line when nil)
- [ ] 1.9 Update `location_test.exs` to use the new structured address fields instead of `address`

## 2. Team Resource — Display Label Calculations and Domain Function

- [ ] 2.1 Add `:display_label` expression calculation to `Team` resource (with year, e.g. `"2026 18+ 3.5 - Team Name"`) using a SQL fragment: `CAST(season_year AS text) || ' ' || team_type.name || ' - ' || name`
- [ ] 2.2 Add `:short_display_label` expression calculation to `Team` resource (without year, e.g. `"18+ 3.5 - Team Name"`): `team_type.name || ' - ' || name`
- [ ] 2.3 Leave `TeamMembership.display_label` unchanged — it uses `TeamMembership.season_year` which is a different field from `Team.season_year`; the calcs are intentionally parallel, not duplicates
- [ ] 2.4 Add a `get_team!/2` domain function to `TennisTracker.Tennis` using `define` with `get_by: [:id]`; this provides a clean way to load a team by ID with explicit `load:` options without pulling in the full roster

## 3. Match Domain — All-Matches Read Action

- [ ] 3.1 Add a `:list_all_matches_for_team` read action to the `Match` resource that accepts a `:team_id` argument, filters by `team_id`, and sorts ascending by `match_start_datetime`
- [ ] 3.2 Add a `list_all_matches_for_team!/2` domain function to `TennisTracker.Tennis` using `define`

## 4. Calendar Export Controller

- [ ] 4.1 Add route `GET /g/:group_slug/teams/:team_id/calendar.ics` to the router as a plain `get` inside the same `scope "/"` block as the CSV export route (before the `ash_authentication_live_session` block)
- [ ] 4.2 Create `TennisTrackerWeb.TeamCalendarController` following the `PlayerCSVController` pattern: resolve group from `group_slug`, verify membership; add error handling for an invalid or missing `team_id` (redirect with error flash, consistent with how the team show LiveView handles missing teams)
- [ ] 4.3 Load the team via `Tennis.get_team!/2` with `load: [:display_label, :short_display_label]` and `tenant: group.id, actor: current_user`; guard against pseudo-teams (`is_pseudo == true`) by redirecting with an error flash, consistent with the team show LiveView
- [ ] 4.4 Load all matches via `Tennis.list_all_matches_for_team!/2` with `load: [location: [:formatted_address]]` to ensure the `formatted_address` calculation is available in the iCal builder
- [ ] 4.5 Implement iCal string builder: VCALENDAR wrapper with `VERSION:2.0`, `PRODID:-//TennisTracker//EN`, `X-WR-CALNAME` set to `team.display_label`, `CALSCALE:GREGORIAN`
- [ ] 4.6 Implement VEVENT generation per match: `UID` as `"match-#{match.id}@tennis-tracker"` (stable, uses match UUID), `DTSTAMP` as current UTC in `YYYYMMDDTHHmmssZ` format, `DTSTART;TZID=<match.timezone>` and `DTEND;TZID=<match.timezone>` in local wall-clock time, `SUMMARY` as `"#{team.short_display_label} v. #{match.opponent}"`
- [ ] 4.7 Build `DESCRIPTION` per event using the full format matrix: `"Home | Venue Name"` or `"Away | Venue Name"` when a location is assigned; `"Home"` or `"Away"` when no location is assigned
- [ ] 4.8 Implement `LOCATION` property: when match has a location with a non-nil `formatted_address`, format as `location.name\n#{formatted_address}` with commas escaped as `\,`; when location is present but `formatted_address` is nil, use just `location.name`; include `ALTREP="<google_maps_url>"` parameter when `google_maps_url` is present; omit the `LOCATION` property entirely when `location_id` is nil
- [ ] 4.9 Send response with `content-type: text/calendar` and `content-disposition: attachment; filename="calendar.ics"`

## 5. Team Show Page — Export Calendar Link

- [ ] 5.1 Add "Export Calendar" link to the team show page pointing to `~p"/g/#{@current_group.slug}/teams/#{@team.id}/calendar.ics"`

## 6. Tests

- [ ] 6.1 Update existing location tests in `location_test.exs` to use the new structured address fields
- [ ] 6.2 Write unit tests for the `formatted_address` calculation on `Location`: full address present, all fields nil
- [ ] 6.3 Write unit tests for `Team.display_label` and `Team.short_display_label` calculations
- [ ] 6.4 Write controller tests for `TeamCalendarController`: authenticated member can download, unauthenticated user is redirected, non-member is redirected, invalid team_id is handled gracefully, pseudo-team is rejected
- [ ] 6.5 Write controller tests verifying iCal output: correct SUMMARY format, DTSTART uses TZID, DESCRIPTION includes venue name when location present, DESCRIPTION is home/away only when no location, LOCATION includes formatted address when present, LOCATION is venue name only when address nil, LOCATION omitted when no location assigned
- [ ] 6.6 Run `mix precommit` and fix any warnings or failures
