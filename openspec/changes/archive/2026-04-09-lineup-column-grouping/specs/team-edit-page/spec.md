## ADDED Requirements

### Requirement: Team edit page includes a lineup column management section
The team edit page SHALL include a section for managing lineup columns, visible to team captains and group owners, positioned above the lineup slots section.

#### Scenario: Column management section visible to captain
- **WHEN** a team captain visits the team edit page
- **THEN** a lineup columns section SHALL be visible listing current columns with options to add, rename, reorder, and delete

#### Scenario: Column management section hidden from non-captains
- **WHEN** a regular group member visits the team edit page
- **THEN** the column management section SHALL NOT be rendered

#### Scenario: Empty column list shows prompt to add first column
- **WHEN** the team has no lineup columns defined
- **THEN** the section SHALL show an empty state prompting the captain to add the first column

### Requirement: Captain can add a new column from the team edit page
The column management section SHALL include a form or inline control for creating a new TeamLineupColumn.

#### Scenario: Add column
- **WHEN** a captain submits a new column name
- **THEN** the column SHALL be created with sort_order `MAX(existing sort_orders) + 1` (or `1` if no columns exist), appended to the end of the column list, and appear in the list

### Requirement: Captain can reorder columns from the team edit page
The column management section SHALL provide move-up and move-down controls for reordering columns.

#### Scenario: Reorder columns
- **WHEN** a captain uses the move-up or move-down buttons to change the order of columns
- **THEN** the updated sort_order values SHALL be persisted and the list SHALL reflect the new sequence

#### Scenario: Move-up disabled for first column
- **WHEN** a column is first in the list
- **THEN** its move-up button SHALL be disabled

#### Scenario: Move-down disabled for last column
- **WHEN** a column is last in the list
- **THEN** its move-down button SHALL be disabled

### Requirement: Captain can rename a column from the team edit page
The column management section SHALL provide an inline edit control for renaming each column.

#### Scenario: Rename column
- **WHEN** a captain edits a column's name and submits
- **THEN** the updated name SHALL be persisted and reflected in the column list

#### Scenario: Rename to duplicate name is rejected
- **WHEN** a captain attempts to rename a column to a name already used by another column on the same team
- **THEN** the action SHALL be rejected with a validation error and the column SHALL retain its previous name

### Requirement: Captain can delete an empty column from the team edit page
Each column in the list SHALL have a delete control. A column can only be deleted when it has no slots assigned to it.

#### Scenario: Delete empty column
- **WHEN** a captain deletes a column that has no slots assigned
- **THEN** the column SHALL be destroyed

#### Scenario: Delete column with slots is blocked
- **WHEN** a captain attempts to delete a column that has slots assigned to it
- **THEN** an error SHALL be shown indicating the column cannot be deleted until all slots are reassigned or deleted
- **AND** the column SHALL NOT be destroyed

### Requirement: Captain can assign a slot to a column from the team edit page
Each slot row in the slot management section SHALL include a required column assignment dropdown. A column assignment is required; there is no uncolumned option.

#### Scenario: Assign slot to column
- **WHEN** a captain selects a column for a slot using the column assignment control
- **THEN** the slot's team_lineup_column_id SHALL be updated and the change SHALL be persisted

### Requirement: Team edit page includes a lineup assignment mode setting
The team edit page SHALL include a setting for `lineup_assignment_mode`, visible and editable by team captains and group owners.

#### Scenario: Captain can view and change lineup assignment mode
- **WHEN** a captain views the team edit page
- **THEN** the current lineup_assignment_mode SHALL be shown
- **AND** the captain SHALL be able to change it to any valid mode (:one_per_match, :one_per_column, :many_per_match)

#### Scenario: Change is persisted
- **WHEN** a captain saves a new lineup_assignment_mode
- **THEN** the team's lineup_assignment_mode SHALL reflect the new value

#### Scenario: Mode change blocked when existing assignments would violate the new mode
- **WHEN** a captain attempts to change lineup_assignment_mode to a more restrictive mode and existing match assignments across the team's matches would violate the new constraint
- **THEN** the change SHALL be rejected with a validation error
- **AND** the team's lineup_assignment_mode SHALL retain its current value
- **AND** the error SHALL indicate that conflicting assignments must be resolved first

#### Scenario: Mode change to many_per_match always succeeds
- **WHEN** a captain changes lineup_assignment_mode to :many_per_match
- **THEN** the change SHALL be accepted regardless of existing assignments

#### Scenario: Non-captain cannot change lineup assignment mode
- **WHEN** a regular group member views the team edit page
- **THEN** the lineup_assignment_mode setting SHALL NOT be rendered or editable
