## MODIFIED Requirements

### Requirement: Player show page displays team membership history section
The player show page SHALL display a team membership history section below the existing player detail information.

#### Scenario: Team membership section renders
- **WHEN** a player show page is rendered
- **THEN** a team membership history section SHALL be present on the page

#### Scenario: Memberships listed in correct order
- **WHEN** the player has non-pseudo team memberships
- **THEN** each membership SHALL appear as a line formatted as "YYYY TT - TN" (year, team type name, team name), ordered newest season first
