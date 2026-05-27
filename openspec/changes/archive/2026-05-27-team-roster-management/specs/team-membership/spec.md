## ADDED Requirements

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
