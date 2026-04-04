## ADDED Requirements

### Requirement: Slots have an is_exclusion_slot flag
Each lineup slot SHALL have an `is_exclusion_slot` boolean (default false). When true, being assigned to this slot is mutually exclusive with being assigned to any playing slot (a slot where `is_exclusion_slot == false`) for the same match.

#### Scenario: is_exclusion_slot defaults to false
- **WHEN** a captain creates a slot without specifying is_exclusion_slot
- **THEN** the slot SHALL be created with is_exclusion_slot = false

#### Scenario: Exclusion slot can be created explicitly
- **WHEN** a captain creates a slot with is_exclusion_slot = true
- **THEN** the slot SHALL be persisted with is_exclusion_slot = true

### Requirement: Assigning a player to an exclusion slot removes their playing slot assignments
When a player is assigned to an exclusion slot for a match, any existing playing slot assignments for that player in that match SHALL be automatically destroyed before the exclusion assignment is created.

#### Scenario: Move player from playing slot to exclusion slot
- **WHEN** a captain assigns a player who is currently in a playing slot to an exclusion slot
- **THEN** the player's playing slot assignment SHALL be destroyed
- **AND** the player SHALL be assigned to the exclusion slot

#### Scenario: Assigning to exclusion slot with no prior assignments
- **WHEN** a captain assigns a player who has no current match assignments to an exclusion slot
- **THEN** the player SHALL be assigned to the exclusion slot with no other side effects

### Requirement: Assigning an excluded player to a playing slot is blocked
When a player is assigned to an exclusion slot for a match, any attempt to assign that same player to a playing slot for the same match SHALL be rejected with an error.

#### Scenario: Attempt to assign excluded player to playing slot
- **WHEN** a player is in an exclusion slot for a match and a captain attempts to assign them to a playing slot
- **THEN** the assignment SHALL be rejected with an error
- **AND** the player SHALL remain in the exclusion slot

#### Scenario: Assign to playing slot when player has no exclusion assignment
- **WHEN** a player has no exclusion slot assignment for the match
- **THEN** assigning them to a playing slot SHALL succeed normally

### Requirement: Each team has exactly one exclusion slot, auto-provisioned at team creation
A team SHALL have exactly one slot where `is_exclusion_slot == true`. When a team is created, a default "Reserve" column and a default "Out" exclusion slot in that column SHALL be created automatically. Creating a second exclusion slot for the same team is rejected. The exclusion slot cannot be deleted. The exclusion slot must be assigned to a column (enforced by the general requirement that all slots have a column).

#### Scenario: Team creation auto-provisions a Reserve column and Out exclusion slot
- **WHEN** a team is created
- **THEN** a "Reserve" column with sort_order 1 SHALL be created for that team
- **AND** an "Out" slot with is_exclusion_slot = true SHALL be created in that column

#### Scenario: Create second exclusion slot is blocked
- **WHEN** a team already has an exclusion slot and a captain attempts to create another slot with is_exclusion_slot = true
- **THEN** the action SHALL be rejected with a validation error

#### Scenario: Exclusion slot without a column is rejected
- **WHEN** a captain attempts to create or update a slot with is_exclusion_slot = true and no team_lineup_column_id
- **THEN** the action SHALL be rejected with a validation error

#### Scenario: Delete exclusion slot is blocked
- **WHEN** a captain attempts to delete the team's exclusion slot
- **THEN** the action SHALL be rejected with an error indicating the exclusion slot cannot be deleted

### Requirement: Deleting a slot with existing assignments removes those assignments
When a captain deletes a lineup slot, any existing `MatchLineupAssignment` records referencing that slot SHALL be destroyed. The captain SHALL be shown a confirmation dialog warning about existing match assignments before the slot and its assignments are deleted.

#### Scenario: Delete slot that has match assignments
- **WHEN** a captain confirms deletion of a slot that has one or more MatchLineupAssignment records
- **THEN** the slot SHALL be destroyed
- **AND** all associated MatchLineupAssignments SHALL be destroyed

#### Scenario: Delete slot with no assignments
- **WHEN** a captain deletes a slot that has no MatchLineupAssignment records
- **THEN** the slot SHALL be destroyed with no side effects on assignments
