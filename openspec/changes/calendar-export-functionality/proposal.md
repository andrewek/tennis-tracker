## Why

Team captains need a way to distribute the full match schedule to team members at the start of a season. Since captains often manage multiple overlapping teams, calendar events need enough context (team identity, division, year) to be distinguishable at a glance.

## What Changes

- **NEW**: `TeamCalendarController` — serves a downloadable `.ics` file for any team, accessible to all authenticated group members via `GET /g/:group_slug/teams/:team_id/calendar.ics`
- **NEW**: Two display label calculations on the `Team` resource: `:display_label` (with year, e.g. `"2026 40+ 4.0 - Team Name"`) and `:short_display_label` (without year, e.g. `"40+ 4.0 - Team Name"`)
- **MODIFIED**: `TeamMembership.display_label` delegates to `team.display_label` instead of duplicating the SQL fragment
- **BREAKING**: `Location.address` (single string) replaced with four structured fields: `street_address`, `city`, `state`, `postal_code` — all required
- **NEW**: `Location.formatted_address` expression calculation composing the structured fields
- Seeds file reworked to use structured address fields; dev DB reset required
- Location management settings pages updated to use new structured address fields
- "Export Calendar" button added to team show page

## Capabilities

### New Capabilities
- `calendar-export`: iCal (.ics) download for a team's full match schedule, covering all matches (past and upcoming), with structured location data, local-time events, and team-identity-rich event titles

### Modified Capabilities
- `locations`: `address` field replaced with structured `street_address`, `city`, `state`, `postal_code` fields; new `formatted_address` calculation; uniqueness and nullability requirements updated accordingly
- `location-management`: Create and edit forms updated to use four structured address fields instead of single address string
- `team-show`: "Export Calendar" link/button added to the page

## Impact

- `Location` Ash resource: field changes require a new Ash migration; seeds rework; dev DB reset
- `Team` Ash resource: two new expression calculations added
- `TeamMembership` Ash resource: `display_label` calc updated to delegate
- New Phoenix controller and route
- Location settings LiveViews updated for new fields
- Team show LiveView updated with export link
