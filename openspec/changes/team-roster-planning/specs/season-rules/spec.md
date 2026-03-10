## ADDED Requirements

### Requirement: SeasonRules define variable roster constraints per team type per year
The system SHALL support `SeasonRules` records that capture the roster constraints for a given `TeamType` in a given season year. Each combination of `(team_type_id, season_year)` SHALL have at most one `SeasonRules` record. SeasonRules SHALL be managed outside the application UI (via seed scripts or console) in this phase.

#### Scenario: SeasonRules are unique per team type and season
- **WHEN** a SeasonRules record already exists for a (team_type_id, season_year) pair
- **THEN** attempting to create a second record for the same pair SHALL fail with a uniqueness error

#### Scenario: SeasonRules capture min and max roster size
- **WHEN** a SeasonRules record is queried for 18+ 3.5 in season 2026
- **THEN** it exposes a min_roster integer and a max_roster integer

#### Scenario: SeasonRules capture on-level minimum percentage
- **WHEN** a SeasonRules record is queried
- **THEN** it exposes an on_level_min_pct decimal representing the minimum fraction of the roster that must be rated at the team's top NTRP level (e.g. 0.60 for 60%)

### Requirement: Health checks degrade gracefully when SeasonRules are absent
The system SHALL NOT error if no SeasonRules exist for the current planning context. Instead, roster health indicators SHALL be suppressed or show a "no rules configured" state.

#### Scenario: No SeasonRules exist for the context
- **WHEN** a planning board is loaded for a (team_type, season_year) with no SeasonRules record
- **THEN** the board loads successfully and no rule-based health warnings are shown
