## MODIFIED Requirements

### Requirement: Player show page displays team membership history section
The player show page SHALL display a team membership history section below the existing player detail information. Each membership entry SHALL be a navigable link to the corresponding team's show page (`/teams/:id`).

#### Scenario: Team membership section renders
- **WHEN** a player show page is rendered
- **THEN** a team membership history section SHALL be present on the page

#### Scenario: Memberships listed in correct order
- **WHEN** the player has non-pseudo team memberships
- **THEN** each membership SHALL appear as a line formatted as "YYYY TT - TN" (year, team type name, team name), ordered newest season first

#### Scenario: Each membership entry links to the team show page
- **WHEN** a membership entry is rendered
- **THEN** the entry text SHALL be wrapped in a link that navigates to `/teams/:id` for that team
