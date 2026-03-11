## MODIFIED Requirements

### Requirement: Teams can be created within a planning context
The system SHALL allow users to create a new `Team` within a given planning context (team type + season year). Each team SHALL have a name. A team belongs to exactly one `TeamType` and one season year.

#### Scenario: Create a new team from the planning board
- **WHEN** a user submits the new team modal with a valid name
- **THEN** the new team appears as a column on the planning board
- **AND** the modal closes

#### Scenario: Team name is required
- **WHEN** a user submits the new team form without a name
- **THEN** a validation error is shown and the team is not created

#### Scenario: Multiple teams can exist in the same planning context
- **WHEN** two teams are created with the same TeamType and season year
- **THEN** both teams coexist and appear as separate columns on the planning board

### Requirement: Teams can be renamed via modal
The system SHALL allow users to rename an existing team via a modal form. The modal SHALL display a validation error if the updated name is blank.

#### Scenario: Rename a team
- **WHEN** a user opens the edit modal for a team, enters a new name, and saves
- **THEN** the updated name is reflected on the planning board immediately
- **AND** the modal closes

#### Scenario: Rename with blank name shows error
- **WHEN** a user submits the edit modal with a blank name
- **THEN** a validation error is shown and the team name is not changed

### Requirement: Teams can be deleted via modal confirmation
The system SHALL allow users to delete a real team from the current planning context via a modal. When a team is deleted, all of its `TeamMembership` records SHALL be deleted, returning those players to the Unassigned pool. Deletion SHALL require explicit confirmation within the modal. Pseudo-teams (Not Participating) SHALL NOT be deletable.

#### Scenario: Delete a team with players assigned
- **WHEN** a user confirms deletion of a team that has players assigned to it
- **THEN** the team and all its memberships are deleted
- **AND** those players appear in the Unassigned column
- **AND** the team column is removed from the board

#### Scenario: Delete a team with no players assigned
- **WHEN** a user confirms deletion of a team with no players
- **THEN** the team is deleted and its column is removed from the board

#### Scenario: Cancel delete closes modal without action
- **WHEN** a user opens the delete modal and then cancels
- **THEN** the modal closes and no data is changed

#### Scenario: Not Participating pseudo-team cannot be deleted
- **WHEN** the planning board is displayed
- **THEN** the Not Participating column has no delete button

### Requirement: Team records are sorted by year, age group, NTRP level, and name
Teams returned from any read action SHALL be sorted in the following order by default: season year descending, then age group ascending (nil values last), then NTRP level descending (nil values last), then name ascending.

#### Scenario: Teams sorted by year descending
- **WHEN** teams from multiple season years are listed
- **THEN** teams from the most recent year appear first

#### Scenario: Teams sorted by NTRP level descending within a year
- **WHEN** teams with different NTRP levels exist in the same year
- **THEN** higher NTRP level teams appear before lower NTRP level teams (e.g. 4.0 before 3.5 before 3.0)

#### Scenario: Teams with nil NTRP level appear last within their year
- **WHEN** a team type has no NTRP level set
- **THEN** those teams appear after all teams with a non-nil NTRP level in the same sort group

### Requirement: SeasonRules roster size and on-level constraints are optional
The `min_roster`, `max_roster`, and `on_level_min_pct` fields on `SeasonRules` SHALL be nullable. When present, `min_roster` and `max_roster` SHALL be positive integers. When present, `on_level_min_pct` SHALL be a decimal value between 0.0 and 100.0 inclusive. These validations SHALL apply on both create and update.

#### Scenario: SeasonRules created without roster limits
- **WHEN** a SeasonRules record is created with null min_roster and max_roster
- **THEN** the record is saved successfully

#### Scenario: SeasonRules created without on-level percentage
- **WHEN** a SeasonRules record is created with null on_level_min_pct
- **THEN** the record is saved successfully

#### Scenario: Roster size must be positive if provided
- **WHEN** a SeasonRules record is created or updated with min_roster or max_roster set to 0 or a negative number
- **THEN** a validation error is returned

#### Scenario: On-level percentage must be 0–100 if provided
- **WHEN** a SeasonRules record is created or updated with on_level_min_pct outside the range 0.0–100.0
- **THEN** a validation error is returned

### Requirement: TeamType NTRP level and age group are optional
The `ntrp_level` and `age_group` attributes on `TeamType` SHALL be nullable. When present, each SHALL be validated against its allowed set of values.

#### Scenario: TeamType created without NTRP level
- **WHEN** a TeamType is created with a null ntrp_level
- **THEN** the record is saved successfully

#### Scenario: TeamType created without age group
- **WHEN** a TeamType is created with a null age_group
- **THEN** the record is saved successfully

#### Scenario: Invalid NTRP level is rejected when present
- **WHEN** a TeamType is created or updated with a non-null ntrp_level not in the allowed set
- **THEN** a validation error is returned

## REMOVED Requirements

### Requirement: Teams can be created within a planning context (captain field)
**Reason:** The `captain` attribute is removed from `Team`. Captain information will be conveyed implicitly through team naming conventions.
**Migration:** Remove any references to `captain` in seeds, tests, or UI. No data migration needed for the spike branch.
