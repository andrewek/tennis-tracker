## Requirements

### Requirement: SeasonRules define variable roster constraints per team type per year
The system SHALL support `SeasonRules` records that capture the roster constraints for a given `TeamType` in a given season year. Each combination of `(team_type_id, season_year)` SHALL have at most one `SeasonRules` record within a group. SeasonRules are tenant-scoped by `group_id` and SHALL NOT be shared across groups. SeasonRules MAY be managed via the admin panel in addition to seed scripts or console.

#### Scenario: SeasonRules are unique per team type and season within a group
- **WHEN** a SeasonRules record already exists for a (team_type_id, season_year) pair within a group
- **THEN** attempting to create a second record for the same pair in the same group SHALL fail with a uniqueness error

#### Scenario: SeasonRules with the same team type and season in different groups are allowed
- **WHEN** two groups each have a SeasonRules record with the same team_type_id and season_year
- **THEN** both records coexist and are valid

#### Scenario: SeasonRules capture min and max roster size
- **WHEN** a SeasonRules record is queried for 18+ 3.5 in season 2026
- **THEN** it exposes a min_roster integer and a max_roster integer

#### Scenario: SeasonRules capture on-level minimum percentage
- **WHEN** a SeasonRules record is queried
- **THEN** it exposes an on_level_min_pct decimal representing the minimum fraction of the roster that must be rated at the team's top NTRP level (e.g. 0.60 for 60%)

### Requirement: SeasonRules records can be destroyed
The system SHALL allow `SeasonRules` records to be destroyed via the `:destroy` action.

#### Scenario: SeasonRules record can be destroyed
- **WHEN** a SeasonRules record is destroyed
- **THEN** the record SHALL be removed from the database

#### Scenario: Destroying SeasonRules suppresses health warnings for that context
- **WHEN** a SeasonRules record for a planning context is destroyed
- **THEN** the planning board for that context SHALL load without rule-based health warnings

### Requirement: Health checks degrade gracefully when SeasonRules are absent
The system SHALL NOT error if no SeasonRules exist for the current planning context. Instead, roster health indicators SHALL be suppressed or show a "no rules configured" state.

#### Scenario: No SeasonRules exist for the context
- **WHEN** a planning board is loaded for a (team_type, season_year) with no SeasonRules record
- **THEN** the board loads successfully and no rule-based health warnings are shown

### Requirement: SeasonRules management requires group owner role
Only users with a `GroupMembership.role == :owner` for the current group (or system admins) SHALL be permitted to create, update, or destroy SeasonRules records.

#### Scenario: Group owner can create season rules
- **WHEN** a user with GroupMembership :owner creates a SeasonRules record
- **THEN** the record is saved successfully

#### Scenario: Group member cannot create season rules
- **WHEN** a user with GroupMembership :member attempts to create a SeasonRules record
- **THEN** the action is denied
