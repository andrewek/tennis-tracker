### Requirement: NTRP level constants are defined in a single shared module
The system SHALL define all valid NTRP level values in `TennisTracker.Tennis.NtrpLevels`. No resource or module SHALL hardcode NTRP level lists inline; all SHALL reference this module.

#### Scenario: Player validation uses shared constants
- **WHEN** a player record is created or updated with an invalid NTRP rating
- **THEN** the validation references the list returned by `NtrpLevels.player_levels/0`
- **AND** valid ratings are 2.5, 3.0, 3.5, 4.0, 4.5, 5.0

#### Scenario: TeamType validation uses shared constants
- **WHEN** a team type record is created or updated with an invalid NTRP level
- **THEN** the validation references the list returned by `NtrpLevels.team_levels/0`
- **AND** valid levels are 3.0, 3.5, 4.0, 4.5

#### Scenario: Team levels are a subset of player levels
- **WHEN** `NtrpLevels.team_levels/0` is called
- **THEN** every value it returns is also present in `NtrpLevels.player_levels/0`
