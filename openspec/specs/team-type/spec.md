### Requirement: TeamType records exist as seeded reference data
The system SHALL provide a set of seeded `TeamType` records representing supported USTA league formats. Each `TeamType` SHALL have a name, age group, top NTRP level, and list of allowed NTRP levels. TeamTypes SHALL NOT be creatable or editable through the application UI in this phase.

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
