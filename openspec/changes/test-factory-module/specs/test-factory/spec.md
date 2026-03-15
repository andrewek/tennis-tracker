## ADDED Requirements

### Requirement: Factory creates players with unique defaults

The system SHALL provide `Factory.player/1` that creates and persists a valid `Player` via `Tennis.create_player!/1`. Defaults SHALL be: a unique name, email, and phone number (each incorporating `System.unique_integer([:positive])`), `ntrp_rating: Decimal.new("3.5")`, and `eligible_18_plus: true`.

#### Scenario: Create player with no arguments

- **WHEN** `Factory.player()` is called
- **THEN** a `Player` is persisted with a unique name, email, phone number, `ntrp_rating: Decimal.new("3.5")`, and `eligible_18_plus: true`

#### Scenario: Create player with attr overrides

- **WHEN** `Factory.player(name: "Alice", ntrp_rating: Decimal.new("3.5"))` is called
- **THEN** a `Player` is persisted with the provided name and NTRP rating

#### Scenario: Player trait :unrated

- **WHEN** `Factory.player(traits: [:unrated])` is called
- **THEN** a `Player` is persisted with `ntrp_rating: nil`

#### Scenario: Player trait :eligible_40_plus

- **WHEN** `Factory.player(traits: [:eligible_40_plus])` is called
- **THEN** a `Player` is persisted with `eligible_40_plus: true`

#### Scenario: Player trait :eligible_55_plus

- **WHEN** `Factory.player(traits: [:eligible_55_plus])` is called
- **THEN** a `Player` is persisted with `eligible_55_plus: true`

#### Scenario: Player trait :ineligible

- **WHEN** `Factory.player(traits: [:ineligible])` is called
- **THEN** a `Player` is persisted with `eligible_18_plus: false`, `eligible_40_plus: false`, and `eligible_55_plus: false`

#### Scenario: Explicit attrs override traits

- **WHEN** `Factory.player(traits: [:unrated], ntrp_rating: Decimal.new("3.5"))` is called
- **THEN** a `Player` is persisted with `ntrp_rating: Decimal.new("3.5")`, not nil

---

### Requirement: Factory creates team types with unique defaults and NTRP traits

The system SHALL provide `Factory.team_type/1` that creates and persists a valid `TeamType` via `Tennis.create_team_type!/1`. Traits SHALL encode internally consistent combinations of `age_group`, `ntrp_level`, and `allowed_ntrp_levels`.

#### Scenario: Create team type with no arguments

- **WHEN** `Factory.team_type()` is called
- **THEN** a `TeamType` is persisted with a unique name and valid default NTRP configuration

#### Scenario: TeamType trait :_35

- **WHEN** `Factory.team_type(traits: [:_35])` is called
- **THEN** a `TeamType` is persisted with `age_group: "18_plus"`, `ntrp_level: Decimal.new("3.5")`, and `allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]`

#### Scenario: TeamType trait :_40

- **WHEN** `Factory.team_type(traits: [:_40])` is called
- **THEN** a `TeamType` is persisted with `age_group: "18_plus"`, `ntrp_level: Decimal.new("4.0")`, and `allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]`

#### Scenario: TeamType trait :_40_plus_35

- **WHEN** `Factory.team_type(traits: [:_40_plus_35])` is called
- **THEN** a `TeamType` is persisted with `age_group: "40_plus"`, `ntrp_level: Decimal.new("3.5")`, and `allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]`

#### Scenario: TeamType trait :_40_plus_40

- **WHEN** `Factory.team_type(traits: [:_40_plus_40])` is called
- **THEN** a `TeamType` is persisted with `age_group: "40_plus"`, `ntrp_level: Decimal.new("4.0")`, and `allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]`

#### Scenario: Explicit attrs override TeamType traits

- **WHEN** `Factory.team_type(traits: [:_35], name: "Custom Name")` is called
- **THEN** a `TeamType` is persisted with the `:_35` NTRP configuration and `name: "Custom Name"`

---

### Requirement: Factory creates teams with auto-created or explicit TeamType

The system SHALL provide `Factory.team/1` that creates and persists a valid `Team` via `Tennis.create_team!/1`. When no `team_type:` key is given, a `TeamType` SHALL be auto-created. When `team_type:` is given, its `id` SHALL be used as `team_type_id`. `season_year` SHALL default to `Date.utc_today().year`.

#### Scenario: Create team with no arguments

- **WHEN** `Factory.team()` is called
- **THEN** a `Team` and a `TeamType` are persisted; the team references the auto-created team type

#### Scenario: Create team with explicit TeamType

- **WHEN** `Factory.team(team_type: my_tt)` is called
- **THEN** a `Team` is persisted referencing `my_tt.id` as `team_type_id`; no new `TeamType` is created

#### Scenario: Create team with attr overrides

- **WHEN** `Factory.team(team_type: my_tt, name: "West Side", season_year: 2025)` is called
- **THEN** a `Team` is persisted with `name: "West Side"` and `season_year: 2025`

#### Scenario: Team trait :pseudo

- **WHEN** `Factory.team(traits: [:pseudo])` is called
- **THEN** a `Team` is persisted with `is_pseudo: true`

---

### Requirement: Factory creates season rules with auto-created or explicit TeamType

The system SHALL provide `Factory.season_rules/1` that creates and persists a valid `SeasonRules` record via `Tennis.create_season_rules!/1`. When no `team_type:` key is given, a `TeamType` SHALL be auto-created. `season_year` SHALL default to `Date.utc_today().year`.

#### Scenario: Create season rules with no arguments

- **WHEN** `Factory.season_rules()` is called
- **THEN** a `SeasonRules` and a `TeamType` are persisted with sensible defaults

#### Scenario: Create season rules with explicit TeamType

- **WHEN** `Factory.season_rules(team_type: my_tt)` is called
- **THEN** a `SeasonRules` is persisted referencing `my_tt.id`; no new `TeamType` is created

#### Scenario: Create season rules with attr overrides

- **WHEN** `Factory.season_rules(team_type: my_tt, min_roster: 6, max_roster: 12)` is called
- **THEN** a `SeasonRules` is persisted with the provided `min_roster` and `max_roster` values

---

### Requirement: Factory creates team memberships with auto-created or explicit Player and Team

The system SHALL provide `Factory.team_membership/1` that creates and persists a valid `TeamMembership` via `Tennis.assign_player/4`. `team_type_id` and `season_year` SHALL be derived from the `team:` record. When no `player:` or `team:` is given, they SHALL be auto-created.

#### Scenario: Create membership with no arguments

- **WHEN** `Factory.team_membership()` is called
- **THEN** a `TeamMembership`, a `Player`, a `Team`, and a `TeamType` are all persisted and correctly linked

#### Scenario: Create membership with explicit player and team

- **WHEN** `Factory.team_membership(player: my_player, team: my_team)` is called
- **THEN** a `TeamMembership` is persisted linking `my_player` and `my_team`; `team_type_id` and `season_year` are derived from `my_team`

#### Scenario: team_type_id derived from team

- **WHEN** `Factory.team_membership(team: my_team)` is called
- **THEN** the persisted membership has `team_type_id` equal to `my_team.team_type_id`

#### Scenario: season_year derived from team

- **WHEN** `Factory.team_membership(team: my_team)` is called
- **THEN** the persisted membership has `season_year` equal to `my_team.season_year`

---

### Requirement: Factory is available in all test cases without explicit alias

The system SHALL alias `TennisTracker.Factory` in `TennisTracker.DataCase` and `TennisTrackerWeb.ConnCase` so that all tests can call `Factory.player()`, `Factory.team()`, etc. without additional setup in each test module.

#### Scenario: Factory available in DataCase tests

- **WHEN** a test module uses `TennisTracker.DataCase`
- **THEN** `Factory.player()` and other factory functions are callable via the `Factory.*` prefix without an additional alias

#### Scenario: Factory available in ConnCase tests

- **WHEN** a test module uses `TennisTrackerWeb.ConnCase`
- **THEN** `Factory.player()` and other factory functions are callable via the `Factory.*` prefix without an additional alias
