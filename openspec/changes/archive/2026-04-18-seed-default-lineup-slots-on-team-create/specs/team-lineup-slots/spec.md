## MODIFIED Requirements

### Requirement: Each team has exactly one exclusion slot, auto-provisioned at team creation
A team SHALL have exactly one slot where `is_exclusion_slot == true`. When a non-pseudo team is created, a default "Reserve" column and a default "Out" exclusion slot in that column SHALL be created automatically. Additionally, a default "Assigned" column SHALL be created with six default playing slots: "#1 Singles", "#2 Singles", "#1 Doubles", "#2 Doubles", "#3 Doubles", and "Sub". Creating a second exclusion slot for the same team is rejected. The exclusion slot cannot be deleted. The exclusion slot must be assigned to a column (enforced by the general requirement that all slots have a column).

#### Scenario: Team creation auto-provisions a Reserve column and Out exclusion slot
- **WHEN** a non-pseudo team is created
- **THEN** a "Reserve" column with sort_order 1 SHALL be created for that team
- **AND** an "Out" slot with is_exclusion_slot = true SHALL be created in that column

#### Scenario: Team creation auto-provisions an Assigned column with default playing slots
- **WHEN** a non-pseudo team is created
- **THEN** an "Assigned" column with sort_order 0 SHALL be created for that team
- **AND** the following slots SHALL be created in that column, in order: "#1 Singles", "#2 Singles", "#1 Doubles", "#2 Doubles", "#3 Doubles", "Sub"
- **AND** the slots SHALL be assigned sort_order 0–5 respectively, in the order listed above
- **AND** all six slots SHALL have participation_type = :playing, is_exclusion_slot = false, and include_in_clipboard = true

#### Scenario: Create second exclusion slot is blocked
- **WHEN** a team already has an exclusion slot and a captain attempts to create another slot with is_exclusion_slot = true
- **THEN** the action SHALL be rejected with a validation error

#### Scenario: Exclusion slot without a column is rejected
- **WHEN** a captain attempts to create or update a slot with is_exclusion_slot = true and no team_lineup_column_id
- **THEN** the action SHALL be rejected with a validation error

#### Scenario: Delete exclusion slot is blocked
- **WHEN** a captain attempts to delete the team's exclusion slot
- **THEN** the action SHALL be rejected with an error indicating the exclusion slot cannot be deleted
