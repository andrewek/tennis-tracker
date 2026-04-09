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

### Requirement: Captain can assign a player via tap-to-assign
On any device, a captain SHALL be able to assign players via a modal interaction: tap a player card anywhere on the board to open a destination picker modal, then tap a button in the modal to complete the move.

#### Scenario: Tap player card to open modal
- **WHEN** a captain taps a player card anywhere on the board (in the Available column or already in a slot)
- **THEN** a modal SHALL open showing the player's name and one button per lineup slot plus an Available button
- **AND** slot buttons SHALL be labeled `{column_name} - {slot_name}` (e.g. "Singles - #1")
- **AND** the button corresponding to the player's current location (the assigned slot, or Available if the player is unassigned) SHALL be styled filled (`btn-primary`); all other buttons SHALL be styled as colored outline (`btn-outline btn-primary`)
- **AND** no assignment SHALL be made as a result of opening the modal alone

#### Scenario: Tap slot button in modal assigns the player
- **WHEN** a captain taps a slot button in the modal
- **THEN** the selected player SHALL be assigned to that slot (same outcome as drag-and-drop)
- **AND** the modal SHALL close

#### Scenario: Tap Available button in modal unassigns the player
- **WHEN** a captain taps the Available button in the modal
- **THEN** all playing-slot assignments for that player in this match SHALL be removed
- **AND** the player SHALL reappear in the Available column
- **AND** the modal SHALL close

#### Scenario: Tap a second player card while modal is open
- **WHEN** a captain taps a different player card while the modal is already open
- **THEN** the modal SHALL update to show the new player
- **NOTE** In real browsers, the modal overlay (fixed full-screen backdrop) intercepts pointer events on background cards, so this scenario is enforced client-side; if a `select_player` event fires for a second player, the server always switches the modal to the new player

#### Scenario: Dismiss modal without action
- **WHEN** a captain dismisses the modal without tapping a slot or Available button (e.g. taps the close button or outside the modal)
- **THEN** the modal SHALL close with no assignment change made

### Requirement: Lineup edit page is accessible only to captains and group owners
The lineup edit page at `/matches/:id/lineup-edit` SHALL redirect non-captains to the match show page.

#### Scenario: Captain can access the lineup edit page
- **WHEN** a captain navigates to `/matches/:id/lineup-edit`
- **THEN** the lineup board SHALL be rendered

#### Scenario: Non-captain is redirected from the lineup edit page
- **WHEN** a regular group member navigates to `/matches/:id/lineup-edit`
- **THEN** they SHALL be redirected to the match show page

### Requirement: Lineup setter shows an empty state when no slots are defined
When the team has no lineup slots defined, the lineup edit page SHALL render an empty state message with a link to the team edit page to define slots.

#### Scenario: No slots defined — captain view
- **WHEN** a captain views the lineup edit page for a match on a team with no lineup slots
- **THEN** an empty state message SHALL be shown with a navigable link to the team edit page

### Requirement: Lineup setter shows a warning when assignment count does not match expected_count
When a slot has an `expected_count` set and the number of assigned players does not exactly match it, the slot column header SHALL display a warning indicator. No drop is ever blocked.

#### Scenario: Slot count matches expected — no warning
- **WHEN** a slot with expected_count 2 has exactly 2 players assigned
- **THEN** no warning SHALL be shown on that column

#### Scenario: Slot count under expected — warning shown
- **WHEN** a slot with expected_count 2 has fewer than 2 players assigned
- **THEN** a warning indicator SHALL appear on the slot column header

#### Scenario: Slot count over expected — warning shown
- **WHEN** a slot with expected_count 2 has more than 2 players assigned
- **THEN** a warning indicator SHALL appear on the slot column header

#### Scenario: Nil expected_count slot never warns
- **WHEN** a slot has nil expected_count (e.g. Out, Sub)
- **THEN** no warning SHALL ever be shown regardless of assignment count

### Requirement: Any group member can copy the lineup to the clipboard
A "Copy Lineup" button SHALL be visible to all group members (captains and non-captains alike) and SHALL generate formatted lineup text and copy it to the system clipboard.

#### Scenario: Clipboard text includes match header
- **WHEN** a group member clicks "Copy Lineup"
- **THEN** the first line of the clipboard text SHALL be the match date and time formatted using the app's standard `MatchHelpers.format_match_datetime/2` output (e.g. `Sun, Mar 29 · 2:00 PM`) followed by the venue name in parentheses, e.g. `Sun, Mar 29 · 2:00 PM (Genesis Westroads)`

#### Scenario: Clipboard includes only include_in_clipboard slots
- **WHEN** a group member clicks "Copy Lineup"
- **THEN** only slots with include_in_clipboard = true SHALL appear as lines in the output

#### Scenario: Clipboard slot block format for filled slots
- **WHEN** a clipboard-included slot has one or more players assigned
- **THEN** the slot SHALL be rendered as the slot name followed by a colon on one line, then one player name per line, sorted alphabetically by full name

#### Scenario: Clipboard slot block format for empty slots
- **WHEN** a clipboard-included slot has no players assigned
- **THEN** the slot SHALL be rendered as the slot name followed by a colon on one line, then `---` on the next line

#### Scenario: Clipboard slots appear in sort_order
- **WHEN** clipboard text is generated
- **THEN** slot lines SHALL appear in ascending sort_order of the TeamLineupSlot

#### Scenario: Clipboard copy shows success flash
- **WHEN** the clipboard write succeeds
- **THEN** a "Copied!" flash message SHALL be displayed to the user

#### Scenario: Clipboard API failure shows fallback
- **WHEN** the browser clipboard API is unavailable or the write fails
- **THEN** a hidden textarea containing the formatted lineup text SHALL be revealed in-page so the user can select and copy it manually

#### Scenario: Clipboard text when no slots are defined
- **WHEN** a group member clicks "Copy Lineup" and the team has no lineup slots defined
- **THEN** the clipboard text SHALL contain only the match header line (date, time, venue)

### Requirement: Lineup board updates in real-time for all concurrent viewers
When any captain makes a lineup change, all group members currently viewing the same match show page SHALL see the updated board without a page refresh.

#### Scenario: Concurrent viewer sees new assignment
- **WHEN** a captain drags a player into a slot
- **THEN** other group members currently viewing the same match show page SHALL see the player appear in that slot without refreshing

#### Scenario: Concurrent viewer sees player removed from slot
- **WHEN** a captain drags a player back to the Available column
- **THEN** other group members currently viewing the same match show page SHALL see the player return to Available without refreshing

### Requirement: Lineup assignments are scoped to a match and tenant
MatchLineupAssignment records SHALL be tenant-scoped and SHALL only be readable and writable by users with access to the group that owns the match's team.

#### Scenario: Assignments are tenant-scoped
- **WHEN** a user queries lineup assignments
- **THEN** only assignments belonging to matches in their group SHALL be returned

## Removed Requirements

### Requirement: Lineup setter board renders columns for Available pool and each slot
**Reason:** Replaced by the grouped column layout. Individual slots no longer get their own top-level column in the board.
**Migration:** Slots are now grouped under `TeamLineupColumn` headers. The Available pool remains the leftmost item. See the new "Lineup board uses a grouped column layout" requirement.
