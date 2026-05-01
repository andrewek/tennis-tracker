## ADDED Requirements

### Requirement: TeamMembership records have a membership_type attribute
The system SHALL add a `membership_type` attribute to the `TeamMembership` resource. The attribute SHALL be an atom enum with values `:playing` and `:non_playing`. The default value SHALL be `:playing`. All existing records receive the default value via migration. The attribute SHALL be non-nullable.

#### Scenario: New membership created without specifying membership_type defaults to playing
- **WHEN** a TeamMembership is created without providing a `membership_type`
- **THEN** the record has `membership_type: :playing`

#### Scenario: New membership created as non-playing
- **WHEN** a TeamMembership is created with `membership_type: :non_playing`
- **THEN** the record has `membership_type: :non_playing`

---

### Requirement: TeamMembership has an add_to_roster action authorized for captains and owners
The system SHALL provide an `:add_to_roster` create action on TeamMembership. This action SHALL accept `player_id`, `team_id`, `team_type_id`, `season_year`, `group_id`, and `membership_type`. It SHALL be authorized for users who are a team captain for the target team OR are a group owner. This action is distinct from the primary `:create` action, which remains owner-only (used by the roster planner).

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

---

### Requirement: TeamMembership has a for_roster read action returning all members
The system SHALL provide a `:for_roster` read action on TeamMembership that returns all records for a given team regardless of `membership_type`. This action is used by the Roster tab LiveView to display both playing and non-playing members. It is distinct from `:for_team`, which filters to playing members only for the lineup editor.

#### Scenario: for_roster returns both playing and non-playing members
- **WHEN** a team has both playing and non-playing members
- **AND** the `:for_roster` action is called for that team
- **THEN** all members are returned regardless of membership_type

---

### Requirement: The for_team read action filters to playing members only
The `TeamMembership` `:for_team` read action (used by the lineup editor to build the available-player pool) SHALL filter results to records where `membership_type == :playing`. Non-playing members SHALL not appear in the lineup's available pool.

#### Scenario: for_team excludes non-playing members
- **WHEN** a team has both playing and non-playing members
- **AND** the `:for_team` action is called for that team
- **THEN** only playing members are returned

#### Scenario: for_team includes all playing members
- **WHEN** a team has multiple playing members
- **AND** the `:for_team` action is called
- **THEN** all playing members are returned
