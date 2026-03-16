## MODIFIED Requirements

### Requirement: Match schedule section is displayed read-only with real match data
The page SHALL display upcoming and past matches for the team. Match rows SHALL be read-only — no add, edit, or delete controls SHALL appear on the show page. Each match row SHALL link to `/matches/:id`. The page SHALL include an "Edit Team" link to `/teams/:id/edit`.

#### Scenario: Upcoming matches are listed read-only
- **WHEN** the team show page loads for a team with upcoming matches
- **THEN** each upcoming match is displayed with opponent, date, time, and location
- **THEN** no "Add Match", "Edit", or "Delete" controls are present on the page

#### Scenario: Past matches are listed read-only
- **WHEN** the team show page loads for a team with past matches
- **THEN** each past match is displayed with opponent, date, time, and location
- **THEN** no mutation controls are present

#### Scenario: Edit Team link is present
- **WHEN** the team show page renders
- **THEN** a link to `/teams/:id/edit` is visible

#### Scenario: Empty upcoming matches
- **WHEN** the team has no upcoming matches
- **THEN** an empty state message is displayed in the upcoming matches section

#### Scenario: Empty past matches
- **WHEN** the team has no past matches
- **THEN** an empty state message is displayed in the past matches section
