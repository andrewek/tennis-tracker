## ADDED Requirements

### Requirement: Any authenticated group member can download a team's calendar
The system SHALL expose a `GET /g/:group_slug/teams/:team_id/calendar.ics` route that returns an iCalendar file for the specified team. Any authenticated user with a membership in the group SHALL be permitted to download the file. Unauthenticated users and users without group membership SHALL be redirected with an error flash.

#### Scenario: Authenticated group member downloads the calendar
- **WHEN** an authenticated user with group membership requests `/g/:group_slug/teams/:team_id/calendar.ics`
- **THEN** the response has content-type `text/calendar`
- **THEN** the response has a `content-disposition: attachment` header with filename `calendar.ics`
- **THEN** the body is a valid iCalendar document

#### Scenario: Unauthenticated user is redirected
- **WHEN** an unauthenticated user requests the calendar export URL
- **THEN** they are redirected to the login page

#### Scenario: Authenticated user not in the group is redirected
- **WHEN** an authenticated user without membership in the group requests the calendar export URL
- **THEN** they are redirected with an error flash

### Requirement: Calendar export includes all matches for the team
The exported `.ics` file SHALL include all matches for the team — both past and upcoming — ordered by `match_start_datetime` ascending. No matches SHALL be filtered out based on date.

#### Scenario: Team with past and upcoming matches exports all of them
- **WHEN** a team has three past matches and two upcoming matches
- **THEN** the exported file contains five VEVENT entries

#### Scenario: Team with no matches exports an empty but valid calendar
- **WHEN** a team has no matches
- **THEN** the exported file is a valid VCALENDAR with no VEVENT entries

### Requirement: Calendar-level name reflects the team's full display label
The exported VCALENDAR SHALL include an `X-WR-CALNAME` property set to the team's `:display_label` (with season year), e.g. `"2026 40+ 4.0 - Team Name"`.

#### Scenario: Calendar name includes season year and team identity
- **WHEN** the calendar file is downloaded for a team with season_year 2026, team_type "40+ 4.0", and name "Team Name"
- **THEN** the `X-WR-CALNAME` property equals `"2026 40+ 4.0 - Team Name"`

### Requirement: Each match is represented as a VEVENT with correct fields
Each match SHALL produce one VEVENT with the following properties:
- `UID`: `"match-{match_id}@tennis-tracker"` — stable across downloads
- `DTSTAMP`: current UTC datetime (time of file generation, in `YYYYMMDDTHHmmssZ` format)
- `DTSTART;TZID={match.timezone}`: match start time in local wall-clock time
- `DTEND;TZID={match.timezone}`: match start time plus `duration_minutes`
- `SUMMARY`: `"{team.short_display_label} v. {match.opponent}"`, e.g. `"40+ 4.0 - Team Name v. Springfield"`
- `DESCRIPTION`: includes the home/away designation and, when a location is assigned, the venue name — formatted as `"Home | Woods Tennis Center"` or `"Away | Woods Tennis Center"` when a location is present, or `"Home"` / `"Away"` when no location is assigned

#### Scenario: VEVENT summary uses short display label and opponent
- **WHEN** the calendar is exported for a team with short_display_label "40+ 4.0 - Team Name" and a match against "Springfield"
- **THEN** the VEVENT SUMMARY is `"40+ 4.0 - Team Name v. Springfield"`

#### Scenario: VEVENT times are in local timezone
- **WHEN** a match has match_start_datetime 2026-04-01 15:00:00 UTC and timezone "America/Chicago"
- **THEN** the DTSTART property is `DTSTART;TZID=America/Chicago:20260401T100000`
- **THEN** the DTEND property reflects start time plus duration_minutes

#### Scenario: VEVENT UID is stable
- **WHEN** the same team's calendar is downloaded twice
- **THEN** each VEVENT has the same UID both times for each match

#### Scenario: VEVENT description contains home/away and venue name when location assigned
- **WHEN** a match has home_or_away :home and a location named "Woods Tennis Center"
- **THEN** the DESCRIPTION is `"Home | Woods Tennis Center"`

#### Scenario: VEVENT description contains home/away and venue name for away match with location
- **WHEN** a match has home_or_away :away and a location named "Woods Tennis Center"
- **THEN** the DESCRIPTION is `"Away | Woods Tennis Center"`

#### Scenario: VEVENT description contains only home/away when no location assigned
- **WHEN** a match has home_or_away :home and no location assigned
- **THEN** the DESCRIPTION is `"Home"`
- **WHEN** a match has home_or_away :away and no location assigned
- **THEN** the DESCRIPTION is `"Away"`

### Requirement: LOCATION field is included when a match has an assigned location
When a match has a non-nil `location_id`, the VEVENT SHALL include a `LOCATION` property. When the location's `formatted_address` is non-nil, the property value SHALL be the venue name and formatted address separated by `\n`. When `formatted_address` is nil (no address fields set), the property value SHALL be the venue name alone. If `google_maps_url` is present on the location, the `ALTREP` parameter SHALL be included. When `location_id` is nil on the match, the `LOCATION` property SHALL be omitted entirely.

#### Scenario: Match with location, full address, and google_maps_url
- **WHEN** a match has a location with name "West Side TC", formatted_address "123 Main St, Springfield, IL 62701", and google_maps_url "https://maps.google.com/..."
- **THEN** the LOCATION property is `LOCATION;ALTREP="https://maps.google.com/...":West Side TC\n123 Main St\, Springfield\, IL 62701`

#### Scenario: Match with location and address but no google_maps_url omits ALTREP
- **WHEN** a match has a location with a formatted_address but no google_maps_url
- **THEN** the LOCATION property is present without an ALTREP parameter

#### Scenario: Match with location but no address fields set
- **WHEN** a match has a location with a name but nil formatted_address
- **THEN** the LOCATION property value is just the venue name (no `\n` or address appended)

#### Scenario: Match without a location omits the LOCATION property
- **WHEN** a match has a nil location_id
- **THEN** no LOCATION property appears in the VEVENT

### Requirement: Export Calendar button is present on the team show page
The team show page SHALL include an "Export Calendar" link that points to the calendar export route for that team. The link SHALL be visible to all authenticated group members.

#### Scenario: Export Calendar link is present on team show page
- **WHEN** an authenticated group member views the team show page
- **THEN** an "Export Calendar" link is visible that points to the `.ics` download URL
