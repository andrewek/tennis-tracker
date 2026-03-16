## Requirements

### Requirement: Team show page displays upcoming matches

The team show page SHALL display an "Upcoming Matches" section listing all matches with `match_date >= today` (in the match's local timezone), sorted ascending (soonest first). Each match entry SHALL display the day of week, date, time (in the match's local timezone), home/away designation, opponent name, and location name (or "TBD" if no location is set).

#### Scenario: Team with upcoming matches shows them in order
- **WHEN** a team has multiple upcoming matches
- **THEN** the upcoming matches section lists them from soonest to furthest
- **THEN** each match displays the date, time, home/away label, opponent, and location name

#### Scenario: Team with no upcoming matches shows empty state
- **WHEN** a team has no matches with `match_date >= today`
- **THEN** the upcoming matches section displays an empty state message (e.g. "No upcoming matches")

### Requirement: Team show page displays past matches

The team show page SHALL display a "Past Matches" section listing all matches with `match_date < today` (in the match's local timezone), sorted descending (most recent first). Each match entry SHALL display the same fields as upcoming matches.

#### Scenario: Team with past matches shows them most-recent first
- **WHEN** a team has multiple past matches
- **THEN** the past matches section lists them from most-recent to oldest

#### Scenario: Team with no past matches shows empty state
- **WHEN** a team has no matches with `match_date < today`
- **THEN** the past matches section displays an empty state message (e.g. "No past matches")

### Requirement: Match creation form is accessible from the team show page

The team show page SHALL include a control that allows authenticated users to add a new match to the team's schedule. The form SHALL allow selecting a location from the pre-seeded list of known venues (location is optional), and entering date, time, opponent, and home/away status.

#### Scenario: User opens match creation form
- **WHEN** an authenticated user clicks the "Add Match" control on a team show page
- **THEN** a match creation form appears (inline, modal, or separate page)
- **THEN** the location field shows a list of known venues to select from, with an option for no location

#### Scenario: User submits valid match
- **WHEN** the user fills in all required fields and submits
- **THEN** the new match appears in the appropriate section (upcoming or past) of the team schedule
