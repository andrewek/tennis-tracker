## ADDED Requirements

### Requirement: Captain can define lineup columns on a team
A team captain or group owner SHALL be able to create named lineup columns on a team. Each column has a name (unique within the team, 1–50 characters) and a sort_order (auto-assigned on create, reorderable via move-up/move-down).

#### Scenario: Create a column
- **WHEN** a captain creates a column with name "Singles"
- **THEN** the column SHALL be persisted, associated with the team, and assigned sort_order `MAX(existing sort_orders) + 1`, or `1` if no columns exist yet

#### Scenario: Name is required
- **WHEN** a captain attempts to create a column with a blank name
- **THEN** the action SHALL be rejected with a validation error

#### Scenario: Name max length enforced
- **WHEN** a captain attempts to create a column with a name longer than 50 characters
- **THEN** the action SHALL be rejected with a validation error

#### Scenario: Name must be unique within the team
- **WHEN** a captain attempts to create a column with a name already used by another column on the same team
- **THEN** the action SHALL be rejected with a validation error

#### Scenario: Non-captain cannot create columns
- **WHEN** a regular group member attempts to create a column
- **THEN** the action SHALL be unauthorized and no column SHALL be created

### Requirement: Captain can rename a lineup column
A team captain or group owner SHALL be able to update the name of an existing column.

#### Scenario: Rename a column
- **WHEN** a captain updates a column's name
- **THEN** the column SHALL reflect the new name

#### Scenario: Rename to a name already in use is rejected
- **WHEN** a captain attempts to rename a column to a name already used by another column on the same team
- **THEN** the action SHALL be rejected with a validation error
- **AND** the column SHALL retain its previous name

### Requirement: Captain can reorder lineup columns
The column management UI SHALL provide move-up and move-down controls for reordering columns.

#### Scenario: Move column up
- **WHEN** a captain moves a column up
- **THEN** the column SHALL swap sort_order with the column immediately above it and the list SHALL reflect the new sequence

#### Scenario: Move column down
- **WHEN** a captain moves a column down
- **THEN** the column SHALL swap sort_order with the column immediately below it and the list SHALL reflect the new sequence

#### Scenario: Move-up disabled for first column
- **WHEN** a column is first in the list (no column above it)
- **THEN** its move-up control SHALL be disabled

#### Scenario: Move-down disabled for last column
- **WHEN** a column is last in the list (no column below it)
- **THEN** its move-down control SHALL be disabled

### Requirement: Captain can delete an empty lineup column
A team captain or group owner SHALL be able to delete a lineup column only when the column has no slots assigned to it. Attempting to delete a column that has slots assigned SHALL be rejected.

#### Scenario: Delete empty column
- **WHEN** a captain deletes a column that has no slots assigned to it
- **THEN** the column SHALL be destroyed

#### Scenario: Delete column with assigned slots is blocked
- **WHEN** a captain attempts to delete a column that still has slots assigned to it
- **THEN** the action SHALL be rejected with an error
- **AND** the captain SHALL be informed they must reassign or delete all slots in the column first
- **AND** the column SHALL NOT be destroyed

#### Scenario: Non-captain cannot delete columns
- **WHEN** a regular group member attempts to delete a column
- **THEN** the action SHALL be unauthorized

### Requirement: Columns are ordered by sort_order
Lineup columns SHALL be retrieved and displayed in ascending sort_order.

#### Scenario: Columns display in defined order
- **WHEN** a team has columns with different sort_order values
- **THEN** they SHALL appear in ascending sort_order sequence in both the management UI and the lineup board

### Requirement: Columns are scoped to a team and tenant
Lineup columns SHALL belong to exactly one team and SHALL NOT be visible to users of other groups.

#### Scenario: Columns are tenant-scoped
- **WHEN** a user queries lineup columns
- **THEN** only columns belonging to teams in their group SHALL be returned

### Requirement: Slots must be assigned to a column
Every lineup slot MUST belong to a column. A slot cannot be created or updated without a `team_lineup_column_id`. Attempting to create a slot without specifying a column SHALL be rejected with a validation error.

#### Scenario: Assign slot to column on create
- **WHEN** a captain creates a slot and specifies a team_lineup_column_id
- **THEN** the slot SHALL be associated with that column

#### Scenario: Assign slot to column on update
- **WHEN** a captain updates a slot's team_lineup_column_id
- **THEN** the slot SHALL be reassigned to the specified column

#### Scenario: Creating a slot without a column is rejected
- **WHEN** a captain attempts to create a slot without specifying a team_lineup_column_id
- **THEN** the action SHALL be rejected with a validation error
