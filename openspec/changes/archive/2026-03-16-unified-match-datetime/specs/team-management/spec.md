## ADDED Requirements

### Requirement: Team has a default timezone for match scheduling and display
The `Team` resource SHALL have an optional `default_timezone` attribute (`:string`, nullable, column default `"America/Chicago"`). This value SHALL be used when converting local date+time inputs to UTC at match creation, and when displaying match times on all pages. Valid values are IANA timezone identifiers (e.g. `"America/Chicago"`). No server-side validation of IANA name correctness is required; all teams are assumed to be in US timezones.

#### Scenario: Team created without default_timezone has column default applied
- **WHEN** a team is created without specifying `default_timezone`
- **THEN** `team.default_timezone` is `"America/Chicago"` (applied by the database default)

#### Scenario: Team default_timezone is used when creating a match
- **WHEN** a team has `default_timezone = "America/New_York"`
- **AND** a match is created for that team with date 2026-05-01 and time 10:00
- **THEN** the match is stored with `match_start_datetime = 2026-05-01T14:00:00Z` (Eastern Daylight, UTC-4 in May)

#### Scenario: Team default_timezone drives match display
- **WHEN** a team has `default_timezone = "America/Chicago"`
- **AND** a match with `match_start_datetime = 2026-05-01T14:00:00Z` is displayed
- **THEN** the displayed time is "9:00 AM"
