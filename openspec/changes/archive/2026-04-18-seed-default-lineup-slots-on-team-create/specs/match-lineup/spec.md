## MODIFIED Requirements

### Requirement: lineup_assignment_mode defaults to one_per_column
Each team SHALL have a `lineup_assignment_mode` attribute (default `:one_per_column`) that determines how many slots a single player may occupy for a given match.

#### Scenario: Default mode is one_per_column
- **WHEN** a new team is created without specifying lineup_assignment_mode
- **THEN** its lineup_assignment_mode SHALL default to :one_per_column
