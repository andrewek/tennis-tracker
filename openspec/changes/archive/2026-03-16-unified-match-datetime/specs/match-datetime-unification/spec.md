## ADDED Requirements

### Requirement: Match start time is stored as a UTC datetime
The system SHALL store the match start moment as a single `match_start_datetime` field of type `:utc_datetime` (PostgreSQL `timestamptz`). The separate `match_date` and `match_time` fields SHALL be removed. The `timezone` field SHALL be retained on `Match` and SHALL be set to the team's `default_timezone` at creation time (falling back to `"America/Chicago"` if nil).

#### Scenario: Match is stored with UTC datetime
- **WHEN** a match is created with a local date, time, and the team's timezone
- **THEN** the `match_start_datetime` stored in the database is the UTC equivalent of that local time

#### Scenario: Match with America/Chicago timezone is converted correctly
- **WHEN** a match is created for a team with `default_timezone = "America/Chicago"`, date 2026-04-01, time 10:00 (CDT, UTC-5 in April)
- **THEN** `match_start_datetime` is stored as `2026-04-01T15:00:00Z`

#### Scenario: match.timezone is set to team default at creation
- **WHEN** a match is created for a team with `default_timezone = "America/Chicago"`
- **THEN** `match.timezone` is `"America/Chicago"`

#### Scenario: match.timezone falls back to America/Chicago when team has no default
- **WHEN** a match is created for a team with `default_timezone = nil`
- **THEN** `match.timezone` is `"America/Chicago"`

### Requirement: Upcoming matches are filtered by UTC datetime
The `list_upcoming_matches_for_team` and `next_upcoming_match_for_team` read actions SHALL return matches where `match_start_datetime >= NOW()` (UTC). Sorting SHALL be by `match_start_datetime` ascending.

#### Scenario: Future match appears in upcoming list
- **WHEN** a match has a `match_start_datetime` in the future (UTC)
- **THEN** it is returned by `list_upcoming_matches_for_team`

#### Scenario: Past match is excluded from upcoming list
- **WHEN** a match has a `match_start_datetime` in the past (UTC)
- **THEN** it is NOT returned by `list_upcoming_matches_for_team`

#### Scenario: Upcoming matches are sorted by start time ascending
- **WHEN** multiple upcoming matches exist for a team
- **THEN** they are returned in ascending `match_start_datetime` order

### Requirement: Past matches are filtered by UTC datetime
The `list_past_matches_for_team` read action SHALL return matches where `match_start_datetime < NOW()` (UTC). Sorting SHALL be by `match_start_datetime` descending.

#### Scenario: Past match appears in past list
- **WHEN** a match has a `match_start_datetime` in the past (UTC)
- **THEN** it is returned by `list_past_matches_for_team`

#### Scenario: Past matches are sorted by start time descending
- **WHEN** multiple past matches exist for a team
- **THEN** they are returned in descending `match_start_datetime` order

### Requirement: Match creation form accepts a local date and time, converted using the team's timezone
The match creation form SHALL present separate date and time inputs. No per-match timezone selector is shown. Upon save, the LiveView SHALL combine the date and time using the team's `default_timezone` (falling back to `"America/Chicago"`) to produce a UTC `match_start_datetime`. If the date or time value cannot be parsed, the form SHALL display a human-readable error message ("Date or time is invalid — please check the values you entered") rather than surfacing the raw Ash field name.

#### Scenario: Form saves with UTC conversion using team timezone
- **WHEN** a user enters date 2026-05-01 and time 09:00 for a team with `default_timezone = "America/Chicago"` and submits
- **THEN** the match is created with `match_start_datetime = 2026-05-01T14:00:00Z` and `timezone = "America/Chicago"`

#### Scenario: Invalid date shows human-readable error
- **WHEN** a user submits the form with an unparseable date or time value
- **THEN** a human-readable error is shown (not a raw field name like "match_start_datetime")
- **AND** the match is not created

#### Scenario: Validation errors appear as the user fills in the form
- **WHEN** a user fills in some form fields but not others
- **THEN** validation feedback reflects the current field values without crashing the form

### Requirement: Matches are displayed in the team's timezone
All display sites (team show page, match show page, teams index page) SHALL convert `match_start_datetime` from UTC to the match's stored `timezone` before formatting. Since `match.timezone` is set to `team.default_timezone` at creation, this is equivalent to displaying in the team's timezone.

#### Scenario: Team show page displays local date and time
- **WHEN** a match with `match_start_datetime = 2026-05-01T14:00:00Z` and `timezone = "America/Chicago"` is displayed on the team show page
- **THEN** the date shown is "May 1" and the time shown is "9:00 AM"

#### Scenario: Match show page displays local date and time with timezone label
- **WHEN** a match is displayed on the match show page
- **THEN** the date and time are shown converted to `match.timezone`
- **AND** the timezone label (e.g. "America/Chicago") is shown alongside

### Requirement: Team next-match aggregate uses UTC datetime
The `Team` resource SHALL expose a single `next_match_start_datetime` aggregate (`:utc_datetime`) replacing the former `next_match_date` and `next_match_time` aggregates. The Teams IndexLive SHALL convert this value to `team.default_timezone` for display.

#### Scenario: next_match_start_datetime reflects the nearest upcoming match
- **WHEN** a team has multiple upcoming matches
- **THEN** `next_match_start_datetime` equals the `match_start_datetime` of the earliest upcoming match

#### Scenario: next_match_start_datetime is nil when no upcoming matches exist
- **WHEN** a team has no upcoming matches
- **THEN** `next_match_start_datetime` is nil

#### Scenario: IndexLive displays next match time in team's timezone
- **WHEN** a team with `default_timezone = "America/Chicago"` has a next match at `2026-05-01T14:00:00Z`
- **THEN** the teams index shows "May 1 · 9:00 AM" (or equivalent single-line format)

### Requirement: tzdata is available for timezone conversion
The application SHALL include the `tzdata` library and configure `Tzdata.TimeZoneDatabase` as the Elixir time zone database. This enables `DateTime.shift_zone/2` for all timezone conversions.

#### Scenario: Timezone conversion succeeds for US zones
- **WHEN** the application converts a UTC datetime to "America/Chicago"
- **THEN** the conversion succeeds without error
