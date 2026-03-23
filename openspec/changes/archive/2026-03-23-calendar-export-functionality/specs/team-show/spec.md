## ADDED Requirements

### Requirement: Team show page provides an Export Calendar link
The team show page SHALL include an "Export Calendar" link visible to all authenticated group members. The link SHALL point to `GET /g/:group_slug/teams/:team_id/calendar.ics` and trigger a file download when clicked.

#### Scenario: Export Calendar link is present for group members
- **WHEN** an authenticated group member views the team show page
- **THEN** an "Export Calendar" link is visible on the page

#### Scenario: Export Calendar link points to the correct route
- **WHEN** the team show page renders for team with id `abc` in group `my-group`
- **THEN** the Export Calendar link href is `/g/my-group/teams/abc/calendar.ics`
