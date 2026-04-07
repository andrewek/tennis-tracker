## Requirements

### Requirement: Teams have a lineup_assignment_mode
Each team SHALL have a `lineup_assignment_mode` attribute (default `:one_per_match`) that determines how many slots a single player may occupy for a given match.

#### Scenario: Default mode is one_per_match
- **WHEN** a team is created without specifying lineup_assignment_mode
- **THEN** its lineup_assignment_mode SHALL default to :one_per_match

### Requirement: one_per_match mode — player may occupy at most one slot
When a team's `lineup_assignment_mode` is `:one_per_match`, a player SHALL have at most one `MatchLineupAssignment` per match. Attempting to assign a player who is already assigned elsewhere SHALL update the existing assignment to the new slot (upsert behavior).

#### Scenario: Assign player already in a slot to a different slot
- **WHEN** a team is in one_per_match mode and a player is assigned to slot A and then assigned to slot B
- **THEN** the player's assignment SHALL be updated to slot B
- **AND** only one assignment SHALL exist for that player and match

#### Scenario: Total count is one after reassignment
- **WHEN** a captain reassigns a player multiple times in one_per_match mode
- **THEN** there SHALL be exactly one MatchLineupAssignment for that player for the match at all times

### Requirement: one_per_column mode — player may occupy at most one slot per column
When a team's `lineup_assignment_mode` is `:one_per_column`, a player SHALL have at most one `MatchLineupAssignment` per column group per match. Assignments in different columns are independent.

#### Scenario: Player can be assigned to slots in different columns
- **WHEN** a team is in one_per_column mode and a player is assigned to a slot in the Singles column and then to a slot in the Doubles column
- **THEN** both assignments SHALL persist

#### Scenario: Dragging a player to a different slot in the same column reassigns them
- **WHEN** a team is in one_per_column mode and a captain drags a player from one slot to another slot in the same column
- **THEN** the player's existing assignment in that column SHALL be destroyed
- **AND** the player SHALL be assigned to the target slot
- **AND** only one assignment SHALL exist for that player in that column

#### Scenario: Assigning to a second slot in the same column via a new assignment is blocked
- **WHEN** a team is in one_per_column mode and a player is already assigned to a slot in the Singles column and a captain attempts to create a second independent assignment to a different slot also in the Singles column
- **THEN** the second assignment SHALL be rejected with an error

### Requirement: many_per_match mode — player may occupy any number of slots
When a team's `lineup_assignment_mode` is `:many_per_match`, a player MAY have multiple `MatchLineupAssignment` records for a match, subject only to the constraint that they cannot occupy the same slot twice.

#### Scenario: Player assigned to multiple slots
- **WHEN** a team is in many_per_match mode and a captain assigns a player to slot A and then to slot B
- **THEN** both assignments SHALL exist independently

#### Scenario: Assigning a player to the same slot twice is blocked
- **WHEN** a team is in many_per_match mode and a player already has an assignment for a specific slot
- **THEN** a second assignment to the same slot SHALL be rejected

### Requirement: Lineup board uses a grouped column layout
The lineup board SHALL render slots grouped under their parent `TeamLineupColumn` headers rather than one column per slot. The Available pool is always the leftmost column group. Column groups are ordered by `TeamLineupColumn.sort_order`. Slots within a column are stacked vertically in ascending `TeamLineupSlot.sort_order`.

#### Scenario: Slots grouped under column headers
- **WHEN** a team has a "Singles" column containing #1 Singles and #2 Singles
- **THEN** the board SHALL render a "Singles" column group header with both slots stacked vertically beneath it

#### Scenario: Empty columns are not rendered on the board
- **WHEN** a team has a column with no slots assigned to it
- **THEN** that column SHALL NOT appear on the lineup board
- **AND** the column SHALL remain visible in the team settings column management section

#### Scenario: Available column is always leftmost
- **WHEN** the lineup board is rendered
- **THEN** the Available column SHALL always appear as the leftmost column group regardless of column sort_order values

### Requirement: Available column behavior varies by assignment mode
The Available column SHALL adapt its behavior based on the team's `lineup_assignment_mode`.

#### Scenario: one_per_match — assigned players leave the Available column
- **WHEN** a team is in one_per_match mode and a player is assigned to any slot
- **THEN** that player SHALL no longer appear in the Available column

#### Scenario: one_per_column — all non-excluded players always appear in the Available column
- **WHEN** a team is in one_per_column mode
- **THEN** the Available column SHALL show all team members who are not in an exclusion slot, regardless of their playing slot assignments
- **AND** each player card SHALL display badges indicating which column groups they are currently assigned to

#### Scenario: many_per_match — all non-excluded players always appear in Available column
- **WHEN** a team is in many_per_match mode
- **THEN** all team members who are not assigned to the exclusion slot SHALL appear in the Available column regardless of how many playing slots they are assigned to

### Requirement: Captain can assign a player via tap-to-assign on mobile
On touch devices, a captain SHALL be able to assign players via a two-tap interaction: tap a player card anywhere on the board (Available column or in a slot) to select them, then tap a destination slot to assign.

#### Scenario: Tap player to select
- **WHEN** a captain taps a player card anywhere on the board (in the Available column or already in a slot)
- **THEN** the player card SHALL show a selected visual state (highlighted ring)

#### Scenario: Tap slot after selecting player assigns the player
- **WHEN** a captain has a player selected and taps a slot's drop zone
- **THEN** the player SHALL be assigned to that slot (same outcome as drag-and-drop)
- **AND** the selected state SHALL be cleared

#### Scenario: Tap selected player again to deselect
- **WHEN** a captain taps the currently-selected player card again
- **THEN** the selection SHALL be cleared with no assignment made

## Removed Requirements

### Requirement: Lineup setter board renders columns for Available pool and each slot
**Reason:** Replaced by the grouped column layout. Individual slots no longer get their own top-level column in the board.
**Migration:** Slots are now grouped under `TeamLineupColumn` headers. The Available pool remains the leftmost item. See the new "Lineup board uses a grouped column layout" requirement.
