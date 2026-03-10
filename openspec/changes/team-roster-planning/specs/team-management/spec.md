## ADDED Requirements

### Requirement: Teams can be created within a planning context
The system SHALL allow users to create a new `Team` within a given planning context (team type + season year). Each team SHALL have a name and an optional captain. A team belongs to exactly one `TeamType` and one season year.

#### Scenario: Create a new team from the planning board
- **WHEN** a user clicks "New Team" on the planning board
- **THEN** a form is presented to enter a team name and optional captain name
- **AND** upon submission, the new team appears as a column on the planning board

#### Scenario: Team name is required
- **WHEN** a user submits the new team form without a name
- **THEN** an error is shown and the team is not created

#### Scenario: Multiple teams can exist in the same planning context
- **WHEN** two teams are created with the same TeamType and season year
- **THEN** both teams coexist and appear as separate columns on the planning board

### Requirement: Teams can be renamed
The system SHALL allow users to rename an existing team.

#### Scenario: Rename a team
- **WHEN** a user edits a team's name and saves
- **THEN** the updated name is reflected on the planning board immediately

### Requirement: Pseudo-teams are created automatically per planning context
The system SHALL automatically create a "Not Participating" pseudo-team when a planning context is first accessed, if one does not already exist. Pseudo-teams SHALL NOT be user-creatable, renameable, or deletable.

#### Scenario: Not Participating pseudo-team is auto-created
- **WHEN** a planning board is loaded for a (team_type, season_year) with no existing pseudo-team
- **THEN** a "Not Participating" column is present on the board
- **AND** a Team record with is_pseudo: true exists for that context in the database

#### Scenario: Not Participating pseudo-team is not created twice
- **WHEN** a planning board is loaded for a context that already has a pseudo-team
- **THEN** only one "Not Participating" column appears on the board
