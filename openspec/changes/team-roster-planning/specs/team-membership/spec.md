## ADDED Requirements

### Requirement: Players can be assigned to a team in a planning context
The system SHALL allow a player to be assigned to exactly one team (or pseudo-team) within a given planning context (team type + season year). A player with no assignment in a context is considered "Unassigned."

#### Scenario: Assign an unassigned player to a team
- **WHEN** a user moves a player from the Unassigned column to a team column
- **THEN** a TeamMembership record is created linking that player to that team
- **AND** the player no longer appears in the Unassigned column

#### Scenario: Move a player from one team to another
- **WHEN** a user moves a player from Team A to Team B within the same planning context
- **THEN** the existing TeamMembership record is updated to reference Team B
- **AND** the player appears in Team B's column and not Team A's

#### Scenario: Move a player to Not Participating
- **WHEN** a user moves a player to the Not Participating column
- **THEN** a TeamMembership record is created (or updated) linking the player to the pseudo-team
- **AND** the player no longer appears in any real team column or Unassigned

#### Scenario: Move a player back to Unassigned
- **WHEN** a user moves a player back to the Unassigned column
- **THEN** the player's TeamMembership record for this context is deleted
- **AND** the player reappears in the Unassigned column

### Requirement: A player can hold at most one membership per team type per season
The system SHALL enforce that a player has at most one TeamMembership record for a given (team_type_id, season_year) combination. This is enforced at the database level.

#### Scenario: Duplicate membership is rejected
- **WHEN** an attempt is made to create a second TeamMembership for the same player in the same (team_type_id, season_year)
- **THEN** the operation fails with a uniqueness error

### Requirement: A player may hold memberships on teams of different types in the same season
The system SHALL allow a player to have TeamMembership records in multiple planning contexts (different team types) within the same season year.

#### Scenario: Player on two different team types
- **WHEN** a player is assigned to an 18+ 3.5 team and also to an 18+ 4.0 team in the same season
- **THEN** both membership records exist and neither is rejected

### Requirement: Not Participating membership is persisted and survives session restarts
The system SHALL persist a player's "Not Participating" status so that it is present when the planning session is resumed.

#### Scenario: Not Participating status persists across sessions
- **WHEN** a player is marked Not Participating in a planning context
- **AND** the browser is closed and the planning board is reopened
- **THEN** the player still appears in the Not Participating column
