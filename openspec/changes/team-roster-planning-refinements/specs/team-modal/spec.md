## ADDED Requirements

### Requirement: Team create, edit, and delete actions use a single modal
The planning board SHALL present a single modal overlay for creating a team, editing a team name, and confirming a team deletion. Only one modal MAY be open at a time. The modal MUST be explicitly closed (via submit or cancel) before another modal can be opened.

#### Scenario: Open create modal
- **WHEN** a user clicks "New Team" on the planning board
- **THEN** the modal opens in create mode with an empty name field

#### Scenario: Open edit modal
- **WHEN** a user clicks the rename/edit button on a team column header
- **THEN** the modal opens in edit mode with the current team name pre-filled

#### Scenario: Open delete modal
- **WHEN** a user clicks the delete button on a team column header
- **THEN** the modal opens in delete mode showing a confirmation prompt for that team

#### Scenario: Only one modal can be open at a time
- **WHEN** a modal is already open
- **THEN** the edit and delete buttons on all team columns are non-functional until the modal is closed

### Requirement: Team create and edit forms display validation errors
The create and edit forms within the modal SHALL display field-level validation errors when submission fails. The form SHALL be driven by AshPhoenix.Form.

#### Scenario: Submit create form with empty name
- **WHEN** a user submits the create form with an empty or blank team name
- **THEN** a validation error is displayed on the name field
- **AND** no team is created
- **AND** the modal remains open

#### Scenario: Submit edit form with empty name
- **WHEN** a user submits the edit form with an empty or blank team name
- **THEN** a validation error is displayed on the name field
- **AND** the team name is not updated
- **AND** the modal remains open

#### Scenario: Successful create closes the modal
- **WHEN** a user submits the create form with a valid name
- **THEN** the team is created
- **AND** the modal closes
- **AND** the new team column appears on the board

#### Scenario: Successful edit closes the modal
- **WHEN** a user submits the edit form with a valid name
- **THEN** the team name is updated
- **AND** the modal closes
- **AND** the updated name is shown in the team column header

### Requirement: Team deletion requires explicit confirmation in the modal
The delete modal SHALL display the team name and require a confirm action before deleting. Canceling SHALL close the modal without deleting.

#### Scenario: Confirm delete
- **WHEN** a user confirms deletion in the delete modal
- **THEN** the team and all its memberships are deleted
- **AND** the modal closes
- **AND** the board reflects the removal

#### Scenario: Cancel delete
- **WHEN** a user cancels from the delete modal
- **THEN** the modal closes without any data changes
