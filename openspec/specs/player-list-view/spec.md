## Requirements

### Requirement: Players list displays age brackets as inline chips
The players index table SHALL display each player's age bracket eligibility as inline badge chips next to the player's name, rather than as separate columns.

#### Scenario: Eligible player shows bracket chips
- **WHEN** a player is eligible for one or more age brackets (18+, 40+, 55+)
- **THEN** the corresponding bracket labels SHALL be displayed as small badge chips in the same cell as the player's name

#### Scenario: No bracket columns in table
- **WHEN** the players index page is rendered
- **THEN** the table SHALL NOT have columns labeled "18+ Eligible?", "40+ Eligible?", or "55+ Eligible?"

#### Scenario: Player with no brackets shows no chips
- **WHEN** a player is not eligible for any age bracket
- **THEN** no age bracket chips SHALL be displayed for that player

### Requirement: Players list is sorted by NTRP then name by default
The players index SHALL display players sorted by NTRP rating ascending, then by name ascending. This sort is always applied and cannot be changed by the user.

#### Scenario: Default sort order applied
- **WHEN** the players index page is loaded without any filter parameters
- **THEN** players SHALL be ordered with lower NTRP ratings first, and players with the same rating ordered alphabetically by name

#### Scenario: Sort order preserved with filters
- **WHEN** the players index page is loaded with name, NTRP, or bracket filter parameters
- **THEN** the filtered results SHALL still be sorted by NTRP ascending then name ascending
