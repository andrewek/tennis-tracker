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

### Requirement: TeamMembership records can be destroyed via the admin panel
The system SHALL allow `TeamMembership` records to be destroyed via the admin panel. This enables cleanup of stale or broken membership records without requiring console access.

#### Scenario: Admin can destroy a TeamMembership record
- **WHEN** an admin destroys a TeamMembership record via the admin panel
- **THEN** the record SHALL be removed from the database
- **AND** the affected player SHALL appear in the Unassigned column the next time the relevant planning board is loaded

### Requirement: TeamMembership has an add_to_roster action authorized for captains and owners
The system SHALL provide an `:add_to_roster` create action on TeamMembership. This action SHALL accept `player_id`, `team_id`, `team_type_id`, `season_year`, and `group_id`. It SHALL be authorized for users who are a team captain for the target team OR are a group owner. This action is distinct from the primary `:create` action, which remains owner-only (used by the roster planner).

#### Scenario: Team captain can create a membership via add_to_roster
- **WHEN** a user with a captain TeamRole for the target team calls `:add_to_roster`
- **THEN** the TeamMembership is created successfully

#### Scenario: Group owner can create a membership via add_to_roster
- **WHEN** a group owner calls `:add_to_roster`
- **THEN** the TeamMembership is created successfully

#### Scenario: Group member (non-captain, non-owner) is denied add_to_roster
- **WHEN** a user who is neither a captain for the target team nor a group owner calls `:add_to_roster`
- **THEN** the action is denied with an authorization error

---

### Requirement: TeamMembership has a remove_from_roster action with a match-assignment guard
The system SHALL provide a `:remove_from_roster` destroy action on TeamMembership. This action SHALL verify that the player has no existing match lineup assignments for the team before destroying the record. If the player is assigned to any match lineup, the action SHALL fail with a validation error. It SHALL be authorized for team captains and group owners (same policy as `:add_to_roster`). This action is distinct from the primary `:destroy` action, which remains owner-only.

#### Scenario: remove_from_roster succeeds when player has no match assignments
- **WHEN** a captain or owner calls `:remove_from_roster` on a TeamMembership where the player has no match lineup assignments for this team
- **THEN** the TeamMembership is destroyed

#### Scenario: remove_from_roster is rejected when player has match assignments
- **WHEN** a captain or owner calls `:remove_from_roster` on a TeamMembership where the player is assigned to at least one match lineup
- **THEN** the action fails with a validation error
- **AND** the TeamMembership is not destroyed

#### Scenario: Group member (non-captain, non-owner) is denied remove_from_roster
- **WHEN** a user who is neither a captain for the target team nor a group owner calls `:remove_from_roster`
- **THEN** the action is denied with an authorization error
