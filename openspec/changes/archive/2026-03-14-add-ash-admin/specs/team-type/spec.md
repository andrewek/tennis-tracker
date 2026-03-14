## MODIFIED Requirements

### Requirement: TeamType records exist as seeded reference data
The system SHALL provide a set of seeded `TeamType` records representing supported USTA league formats. Each `TeamType` SHALL have a name, age group, top NTRP level, and list of allowed NTRP levels. TeamTypes MAY be updated or deleted through the admin panel.

#### Scenario: Seed produces expected team types
- **WHEN** the seed script is run
- **THEN** 8 TeamType records exist: 18+ and 40+ age groups, each with NTRP levels 3.0, 3.5, 4.0, and 4.5

#### Scenario: 3.5 team type has correct allowed levels
- **WHEN** the 18+ 3.5 TeamType is queried
- **THEN** its allowed_ntrp_levels includes 3.0 and 3.5, and does not include 2.5, 4.0, 4.5, or 5.0

#### Scenario: 3.0 team type has correct allowed levels
- **WHEN** any 3.0 TeamType is queried
- **THEN** its allowed_ntrp_levels includes only 3.0

#### Scenario: 4.0 team type has correct allowed levels
- **WHEN** any 4.0 TeamType is queried
- **THEN** its allowed_ntrp_levels includes 3.5 and 4.0, and does not include 3.0, 4.5, or 5.0

#### Scenario: TeamType name is human-readable
- **WHEN** a TeamType is queried
- **THEN** its name is a human-readable string such as "18+ 3.5" or "40+ 4.0"

## ADDED Requirements

### Requirement: TeamType records can be updated
The system SHALL allow `TeamType` records to be updated via the `:update` action.

#### Scenario: TeamType name can be updated
- **WHEN** a TeamType record is updated with a new name
- **THEN** the record SHALL reflect the new name

#### Scenario: TeamType allowed_ntrp_levels can be updated
- **WHEN** a TeamType record is updated with a new allowed_ntrp_levels list
- **THEN** the record SHALL reflect the updated list

### Requirement: TeamType records can be destroyed
The system SHALL allow `TeamType` records to be destroyed via the `:destroy` action. Destroying a TeamType that has associated Teams SHALL fail at the database level due to the foreign key constraint.

#### Scenario: TeamType with no associated teams can be destroyed
- **WHEN** a TeamType with no associated Team records is destroyed
- **THEN** the record SHALL be removed from the database

#### Scenario: TeamType with associated teams cannot be destroyed
- **WHEN** an attempt is made to destroy a TeamType that has one or more associated Team records
- **THEN** the operation SHALL fail with a constraint error
