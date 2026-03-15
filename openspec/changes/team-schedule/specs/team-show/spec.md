## MODIFIED Requirements

### Requirement: Match schedule section is displayed with real match data

The page SHALL display an "Upcoming Matches" section and a "Past Matches" section. These sections SHALL be populated from real `Match` records associated with the team, not placeholder data. Each match entry SHALL show the day of week, date, time, home/away designation with opponent name, and location name. Each match entry SHALL link to the match show page (`/matches/:id`).

#### Scenario: Match schedule renders real upcoming matches
- **WHEN** the team show page loads for a team with upcoming matches
- **THEN** the upcoming matches section is visible with real match data
- **THEN** each match shows date, time, opponent, home/away label, and location name

#### Scenario: Match schedule renders real past matches
- **WHEN** the team show page loads for a team with past matches
- **THEN** the past matches section is visible with real match data

#### Scenario: Team with no matches shows empty state in both sections
- **WHEN** the team show page loads for a team with no matches
- **THEN** both sections display an empty state message rather than no content
