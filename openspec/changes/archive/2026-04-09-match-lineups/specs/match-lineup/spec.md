## ADDED Requirements

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

### Requirement: Lineup setter board renders columns for Available pool and each slot
The board SHALL render an "Available" column containing all team members not assigned to any slot for this match, followed by one column per TeamLineupSlot in sort_order.

#### Scenario: Unassigned players appear in Available
- **WHEN** a team member has no MatchLineupAssignment for the match
- **THEN** that player SHALL appear in the Available column

#### Scenario: Assigned players appear in their slot column
- **WHEN** a player has a MatchLineupAssignment for the match pointing to a slot
- **THEN** that player SHALL appear in that slot's column and NOT in the Available column

#### Scenario: Slot columns ordered by sort_order
- **WHEN** the lineup board is rendered
- **THEN** slot columns SHALL appear left-to-right in ascending sort_order after the Available column

### Requirement: Captain can assign a player to a slot by dragging
A captain SHALL be able to drag a player card from any column and drop it onto a slot column to assign that player to the slot.

#### Scenario: Drag from Available to slot
- **WHEN** a captain drags a player from Available and drops onto a slot column
- **THEN** a MatchLineupAssignment SHALL be created for that player and slot for this match
- **AND** the player SHALL move from Available to the slot column

#### Scenario: Drag between slot columns
- **WHEN** a captain drags a player from one slot column and drops onto a different slot column
- **THEN** the player's MatchLineupAssignment SHALL be updated to reference the new slot

#### Scenario: Drag from slot back to Available
- **WHEN** a captain drags a player from a slot column and drops onto the Available column
- **THEN** the player's MatchLineupAssignment SHALL be destroyed
- **AND** the player SHALL return to the Available column

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
