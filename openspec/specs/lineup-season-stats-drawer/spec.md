## ADDED Requirements

### Requirement: Stats drawer toggle
A toggle button in the lineup editor header SHALL show and hide the season stats drawer.

#### Scenario: Drawer is closed by default
- **WHEN** a captain opens the lineup editor
- **THEN** the stats drawer SHALL not be visible

#### Scenario: Toggle button opens the drawer
- **WHEN** a captain clicks the stats toggle button
- **THEN** the stats drawer SHALL become visible

#### Scenario: Toggle button closes the drawer
- **GIVEN** the stats drawer is open
- **WHEN** a captain clicks the stats toggle button
- **THEN** the stats drawer SHALL be hidden

---

### Requirement: Drawer shows all roster players
The stats drawer SHALL show one row per player on the team's current roster, regardless of whether they have any assignments.

#### Scenario: All roster players appear
- **GIVEN** a team has N players on its roster
- **WHEN** the stats drawer is open
- **THEN** the drawer SHALL show exactly N rows, one per player

#### Scenario: Player with no assignments shows zeros
- **GIVEN** a player is on the roster but has no lineup assignments for this season
- **WHEN** the stats drawer is open
- **THEN** that player's row SHALL show 0 for Played, Planned, and Out

---

### Requirement: Drawer shows correct participation counts
Each player row SHALL display counts derived from their `:playing`, `:out`, and `:neutral` assignments for this team's current season.

#### Scenario: Played count reflects past :playing assignments
- **GIVEN** a player has been assigned to a `:playing` slot on a match that has already occurred
- **WHEN** the stats drawer is open
- **THEN** that player's Played count SHALL include that match

#### Scenario: Planned count reflects future :playing assignments
- **GIVEN** a player is assigned to a `:playing` slot on a match scheduled in the future
- **WHEN** the stats drawer is open
- **THEN** that player's Planned count SHALL include that match
- **AND** the Played count SHALL NOT include it

#### Scenario: Total shown as played+planned over total matches
- **GIVEN** a player has 2 past playing assignments and 1 future playing assignment
- **AND** the team has 10 matches this season
- **WHEN** the stats drawer is open
- **THEN** that player's Total SHALL be shown as "3 / 10"

#### Scenario: Out count reflects :out assignments regardless of timing
- **GIVEN** a player has an `:out` assignment on a past match and another on a future match
- **WHEN** the stats drawer is open
- **THEN** that player's Out count SHALL be 2

#### Scenario: :out assignments do not count toward Played or Planned
- **GIVEN** a player has only `:out` assignments
- **WHEN** the stats drawer is open
- **THEN** that player's Played and Planned counts SHALL both be 0

#### Scenario: Stats are scoped to this team only
- **GIVEN** a player is on two different teams and has playing assignments on both
- **WHEN** the stats drawer is open on Team A's lineup editor
- **THEN** only assignments from Team A's matches SHALL be reflected in the counts

---

### Requirement: Neutral slot columns
The stats drawer SHALL show one column per neutral slot defined on the team, always visible even if all counts are zero.

#### Scenario: Neutral slot column appears for each team neutral slot
- **GIVEN** a team has two neutral slots (e.g. "Beer Duty" and "Snack Duty")
- **WHEN** the stats drawer is open
- **THEN** the drawer SHALL show a "Beer Duty" column and a "Snack Duty" column

#### Scenario: Neutral slot column shown even with all-zero counts
- **GIVEN** a team has a neutral slot but no player has been assigned to it yet
- **WHEN** the stats drawer is open
- **THEN** the neutral slot column SHALL still be shown with zero counts for all players

#### Scenario: Neutral assignment counted under the correct slot column
- **GIVEN** a player has been assigned to the "Beer Duty" neutral slot on one match
- **WHEN** the stats drawer is open
- **THEN** that player's "Beer Duty" count SHALL be 1
- **AND** any other neutral slot columns for that player SHALL remain 0

#### Scenario: Neutral assignments counted regardless of match timing
- **GIVEN** a player has a neutral slot assignment on a past match and another on a future match
- **WHEN** the stats drawer is open
- **THEN** that player's neutral slot count SHALL be 2

#### Scenario: Neutral assignments do not count toward Played or Planned
- **GIVEN** a player has only neutral slot assignments
- **WHEN** the stats drawer is open
- **THEN** that player's Played and Planned counts SHALL both be 0

---

### Requirement: Drawer is sortable
The drawer header SHALL offer sort controls; selecting one re-orders all rows.

#### Scenario: Default sort is by name A–Z
- **WHEN** the stats drawer is opened for the first time
- **THEN** rows SHALL be ordered alphabetically ascending by player full name

#### Scenario: Sort by Total ascending (fewest first)
- **WHEN** a captain selects "Fewest played"
- **THEN** rows SHALL be ordered by total (played + planned) ascending, fewest first
- **AND** ties SHALL be broken by player name A–Z

#### Scenario: Sort by Total descending (most first)
- **WHEN** a captain selects "Most played"
- **THEN** rows SHALL be ordered by total descending, most first
- **AND** ties SHALL be broken by player name A–Z

#### Scenario: Sort by Out descending (most restricted first)
- **WHEN** a captain selects "Most out"
- **THEN** rows SHALL be ordered by out count descending
- **AND** ties SHALL be broken by player name A–Z

---

### Requirement: Drawer updates live as assignments change
The drawer stats SHALL reflect the current assignment state without a page reload.

#### Scenario: Stats update when a player is assigned to a future match slot
- **GIVEN** the stats drawer is open
- **WHEN** a captain assigns a player to a `:playing` slot on the current match
- **AND** the current match is scheduled in the future
- **THEN** that player's Planned count SHALL increase by 1 immediately

#### Scenario: Stats update when a player is assigned to a past match slot
- **GIVEN** the stats drawer is open
- **WHEN** a captain assigns a player to a `:playing` slot on the current match
- **AND** the current match has already occurred
- **THEN** that player's Played count SHALL increase by 1 immediately
