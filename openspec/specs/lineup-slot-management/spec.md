## MODIFIED Requirements

### Requirement: Slots have a participation_type, not is_exclusion_slot
`TeamLineupSlot` SHALL use a `participation_type` enum (`:playing`, `:out`, `:neutral`) in place of the `is_exclusion_slot` boolean.

#### Scenario: Default slot on team create is :out type
- **GIVEN** a captain creates a new team
- **THEN** the automatically created "Out" slot SHALL have `participation_type: :out`
- **AND** no `is_exclusion_slot` attribute SHALL exist on the slot

#### Scenario: Existing exclusion slots migrate to :out
- **GIVEN** a team had an exclusion slot before the migration
- **THEN** that slot SHALL have `participation_type: :out` after the migration
- **AND** all other existing slots SHALL have `participation_type: :playing`

---

### Requirement: Slot creation UI uses participation_type select
The slot creation form in the team edit page SHALL offer a `participation_type` select instead of an `is_exclusion_slot` checkbox.

#### Scenario: participation_type select shown on slot create
- **WHEN** a captain opens the slot creation form on the team edit page
- **THEN** a select control for `participation_type` SHALL be shown with options: Playing, Out, Neutral

#### Scenario: :out option disabled when team already has an :out slot
- **GIVEN** the team already has a slot with `participation_type: :out`
- **WHEN** a captain opens the slot creation form
- **THEN** the `:out` option in the `participation_type` select SHALL be disabled

#### Scenario: Creating a :playing slot succeeds
- **WHEN** a captain creates a new slot with `participation_type: :playing`
- **THEN** the slot SHALL be saved and appear in the team's slot list

#### Scenario: Creating a :neutral slot succeeds
- **WHEN** a captain creates a new slot with `participation_type: :neutral`
- **THEN** the slot SHALL be saved and appear in the team's slot list

#### Scenario: Creating an :out slot succeeds when none exists
- **GIVEN** the team has no `:out` slot
- **WHEN** a captain creates a new slot with `participation_type: :out`
- **THEN** the slot SHALL be saved

#### Scenario: Creating a second :out slot is rejected
- **GIVEN** the team already has a slot with `participation_type: :out`
- **WHEN** a captain attempts to create another slot with `participation_type: :out`
- **THEN** the creation SHALL fail with a validation error
- **AND** the team SHALL still have exactly one `:out` slot

---

### Requirement: participation_type is immutable after creation
A slot's `participation_type` SHALL NOT be changeable after the slot is created. The slot edit form (for renaming, reordering, etc.) SHALL NOT expose a `participation_type` field.

#### Scenario: No participation_type control in slot edit form
- **WHEN** a captain opens the edit form for an existing slot
- **THEN** no `participation_type` input SHALL be shown
- **AND** the slot's type SHALL remain unchanged after saving the edit

---

### Requirement: Slot delete guard protects the :out slot
The `:out` slot SHALL not be deletable from the team edit UI.

#### Scenario: Delete button absent for the :out slot
- **WHEN** a captain views the slot list on the team edit page
- **THEN** no delete button SHALL be shown for any slot with `participation_type: :out`

#### Scenario: Delete button present for :playing and :neutral slots
- **WHEN** a captain views the slot list on the team edit page
- **THEN** a delete button SHALL be shown for slots with `participation_type: :playing` or `:neutral`
