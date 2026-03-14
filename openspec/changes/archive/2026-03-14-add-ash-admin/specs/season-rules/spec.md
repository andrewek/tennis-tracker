## MODIFIED Requirements

### Requirement: SeasonRules define variable roster constraints per team type per year
The system SHALL support `SeasonRules` records that capture the roster constraints for a given `TeamType` in a given season year. Each combination of `(team_type_id, season_year)` SHALL have at most one `SeasonRules` record. SeasonRules MAY be managed via the admin panel in addition to seed scripts or console.

#### Scenario: SeasonRules are unique per team type and season
- **WHEN** a SeasonRules record already exists for a (team_type_id, season_year) pair
- **THEN** attempting to create a second record for the same pair SHALL fail with a uniqueness error

#### Scenario: SeasonRules capture min and max roster size
- **WHEN** a SeasonRules record is queried for 18+ 3.5 in season 2026
- **THEN** it exposes a min_roster integer and a max_roster integer

#### Scenario: SeasonRules capture on-level minimum percentage
- **WHEN** a SeasonRules record is queried
- **THEN** it exposes an on_level_min_pct decimal representing the minimum fraction of the roster that must be rated at the team's top NTRP level (e.g. 0.60 for 60%)

## ADDED Requirements

### Requirement: SeasonRules records can be destroyed
The system SHALL allow `SeasonRules` records to be destroyed via the `:destroy` action.

#### Scenario: SeasonRules record can be destroyed
- **WHEN** a SeasonRules record is destroyed
- **THEN** the record SHALL be removed from the database

#### Scenario: Destroying SeasonRules suppresses health warnings for that context
- **WHEN** a SeasonRules record for a planning context is destroyed
- **THEN** the planning board for that context SHALL load without rule-based health warnings
