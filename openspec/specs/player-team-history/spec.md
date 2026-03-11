## Requirements

### Requirement: Team memberships are loadable via Ash association on Player
The `has_many :team_memberships` relationship on `Player` SHALL filter out pseudo teams and sort results by season_year descending, then age_group ascending, then ntrp_level descending, at the database level.

#### Scenario: Pseudo team memberships are excluded
- **WHEN** a player's team_memberships are loaded via the Ash relationship
- **THEN** memberships whose associated team has `is_pseudo: true` SHALL NOT be returned

#### Scenario: Memberships are sorted correctly
- **WHEN** a player has memberships across multiple seasons and team types
- **THEN** the results SHALL be ordered by season_year descending, then age_group ascending, then ntrp_level descending

### Requirement: Player team history is displayed on the player show page
The player show page SHALL display a list of all non-pseudo team memberships for the player across all seasons.

#### Scenario: Memberships displayed for player with history
- **WHEN** a player has one or more non-pseudo team memberships
- **THEN** each membership SHALL be displayed as a single line in the format "2026 40+ 4.0 - Team Alpha" (season_year, team_type name, team name)

#### Scenario: All seasons shown
- **WHEN** a player has memberships in multiple seasons
- **THEN** all seasons SHALL be shown, not just the current or most recent season

#### Scenario: No memberships section shown when player has no history
- **WHEN** a player has no non-pseudo team memberships
- **THEN** the page SHALL indicate there are no team memberships (e.g., an empty state message)
