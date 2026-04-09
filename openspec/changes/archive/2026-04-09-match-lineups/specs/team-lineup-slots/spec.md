## ADDED Requirements

### Requirement: Captain can define lineup slots on a team
A team captain or group owner SHALL be able to create named lineup slots on a team. Each slot has a name (unique within the team, 1–12 characters), expected_count (optional), sort order, and a flag for whether it appears in the clipboard output.

#### Scenario: Create a playing slot
- **WHEN** a captain creates a slot with name "#1 Doubles", expected_count 2, and include_in_clipboard true
- **THEN** the slot SHALL be persisted and associated with the team

#### Scenario: Create an unbounded slot
- **WHEN** a captain creates a slot with name "Out" and no expected_count specified
- **THEN** the slot SHALL be persisted with a nil expected_count (unbounded)

#### Scenario: Clipboard flag defaults to true
- **WHEN** a captain creates a slot without specifying include_in_clipboard
- **THEN** include_in_clipboard SHALL default to true

#### Scenario: Name is required
- **WHEN** a captain attempts to create a slot with a blank name
- **THEN** the action SHALL be rejected with a validation error

#### Scenario: Name max length enforced
- **WHEN** a captain attempts to create a slot with a name longer than 12 characters
- **THEN** the action SHALL be rejected with a validation error

#### Scenario: Name must be unique within the team
- **WHEN** a captain attempts to create a slot with a name already used by another slot on the same team
- **THEN** the action SHALL be rejected with a validation error

#### Scenario: Non-captain cannot create slots
- **WHEN** a regular group member attempts to create a slot
- **THEN** the action SHALL be unauthorized and no slot SHALL be created

### Requirement: Captain can edit lineup slots
A team captain or group owner SHALL be able to update any field on an existing slot.

#### Scenario: Update slot name
- **WHEN** a captain updates a slot's name
- **THEN** the slot SHALL reflect the new name

#### Scenario: Toggle include_in_clipboard
- **WHEN** a captain sets include_in_clipboard to false on a slot
- **THEN** that slot SHALL be excluded from clipboard output going forward

### Requirement: Captain can delete lineup slots
A team captain or group owner SHALL be able to delete a lineup slot. All MatchLineupAssignments referencing that slot SHALL be cascade-deleted.

#### Scenario: Delete slot removes assignments
- **WHEN** a captain deletes a slot that has existing match lineup assignments
- **THEN** the slot AND all its assignments SHALL be destroyed

#### Scenario: Non-captain cannot delete slots
- **WHEN** a regular group member attempts to delete a slot
- **THEN** the action SHALL be unauthorized

### Requirement: Slots are ordered by sort_order
Lineup slots SHALL be retrieved and displayed in ascending sort_order.

#### Scenario: Slots display in defined order
- **WHEN** a team has slots with sort_order 1, 2, 3
- **THEN** they SHALL appear in that sequence in the lineup setter and clipboard output

### Requirement: Slots are scoped to a team
Lineup slots SHALL belong to exactly one team and SHALL NOT be visible to users of other groups.

#### Scenario: Slots are tenant-scoped
- **WHEN** a user queries lineup slots
- **THEN** only slots belonging to teams in their group SHALL be returned
