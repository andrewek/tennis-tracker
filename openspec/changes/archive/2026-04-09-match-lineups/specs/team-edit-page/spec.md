## ADDED Requirements

### Requirement: Team edit page includes a slot management section
The team edit page SHALL include a section for managing lineup slots, accessible to team captains and group owners.

#### Scenario: Slot management section visible to captain
- **WHEN** a team captain visits the team edit page
- **THEN** a lineup slots section SHALL be visible listing the current slots with options to add, edit, reorder, and delete

#### Scenario: Slot management section hidden from non-captains
- **WHEN** a regular group member visits the team edit page
- **THEN** the slot management section SHALL NOT be rendered

#### Scenario: Empty slot list shows prompt to add first slot
- **WHEN** the team has no lineup slots defined
- **THEN** the section SHALL show an empty state prompting the captain to add the first slot

### Requirement: Captain can add a new slot from the team edit page
The slot management section SHALL include a form or inline control for creating a new TeamLineupSlot.

#### Scenario: Add slot with all fields
- **WHEN** a captain submits a new slot with name, expected_count, and include_in_clipboard
- **THEN** the slot SHALL be created, appended to the end of the slot list (sort_order auto-assigned), and appear in the slot list

#### Scenario: Add slot with optional expected_count omitted
- **WHEN** a captain creates a slot without specifying expected_count
- **THEN** the slot SHALL be created with nil expected_count (unbounded)

### Requirement: Captain can edit an existing slot inline
Each slot in the list SHALL be editable inline or via an edit form.

#### Scenario: Edit slot fields
- **WHEN** a captain edits a slot's name, expected_count, or include_in_clipboard flag
- **THEN** the updated values SHALL be persisted

### Requirement: Captain can reorder lineup slots
The slot management section SHALL provide a mechanism for a captain to change the sort order of existing slots.

#### Scenario: Reorder slots
- **WHEN** a captain uses the move-up or move-down buttons to change the order of slots
- **THEN** the updated sort_order values SHALL be persisted and the slot list SHALL reflect the new sequence

### Requirement: Captain can delete a slot from the team edit page
Each slot in the list SHALL have a delete control.

#### Scenario: Delete slot with confirmation
- **WHEN** a captain confirms deletion of a slot
- **THEN** the slot SHALL be destroyed along with any associated MatchLineupAssignments
