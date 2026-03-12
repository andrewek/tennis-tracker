## Requirements

### Requirement: board_column renders a droppable column with a configurable header actions slot
The `board_column` component SHALL render a titled, droppable column that accepts player cards as its inner content and exposes a `:header_actions` slot for caller-defined header controls (such as rename/delete buttons).

#### Scenario: Column renders title and count
- **WHEN** `board_column` is rendered with a title and count
- **THEN** the column header SHALL display the title text and the count as a badge

#### Scenario: Header actions slot renders caller content
- **WHEN** `board_column` is rendered with content in the `:header_actions` slot
- **THEN** that content SHALL appear in the column header area

#### Scenario: Header actions slot is optional
- **WHEN** `board_column` is rendered without a `:header_actions` slot
- **THEN** the column SHALL render without error and the header SHALL contain only title and count

#### Scenario: Column acts as a drop target
- **WHEN** a draggable player card is dropped onto the column
- **THEN** the column SHALL push a LiveView event with `player_id` and `target_id` in the payload

#### Scenario: Drop event name is configurable
- **WHEN** a column is rendered with a `data-drop-event` attribute on the drop zone element
- **THEN** the hook SHALL push that event name instead of the default `"move_player"`

#### Scenario: Violations render as inline alerts
- **WHEN** `board_column` is rendered with a non-empty `violations` list
- **THEN** each violation SHALL render as a small alert with appropriate warning or caution styling

### Requirement: player_card renders a draggable player with violation and selection state
The `player_card` component SHALL render a single player as a draggable card that indicates NTRP rating, selection state, and health violation state.

#### Scenario: Player name and NTRP displayed
- **WHEN** a player card is rendered for a player with a name and NTRP rating
- **THEN** both the name and rating SHALL be visible on the card

#### Scenario: Missing NTRP shows indicator
- **WHEN** a player card is rendered for a player with no NTRP rating
- **THEN** a "?" indicator SHALL appear in place of the rating

#### Scenario: Violation state shown
- **WHEN** `has_violation` is true
- **THEN** the card SHALL display a warning indicator (e.g., ⚠) and a warning-colored border

#### Scenario: Selected state shown
- **WHEN** `selected` is true
- **THEN** the card SHALL display a visible selection ring

#### Scenario: Card is draggable
- **WHEN** a player card is rendered
- **THEN** the card SHALL be draggable via the `DraggableCard` hook, transferring the player's ID

#### Scenario: Card click fires select_player event
- **WHEN** a player card is clicked
- **THEN** a `select_player` LiveView event SHALL be pushed with the player's ID as `player_id`

### Requirement: player_detail_modal renders player info with an optional actions slot and always includes a show page link
The `player_detail_modal` component SHALL render a modal overlay displaying the player's name, NTRP rating, and a navigation link to the player's show page. It SHALL expose an optional `:actions` slot for context-specific action buttons and SHALL always render a close button.

#### Scenario: Modal renders player name and NTRP
- **WHEN** `player_detail_modal` is rendered with a player
- **THEN** the player's name and NTRP rating SHALL be visible in the modal

#### Scenario: Modal always shows link to player show page
- **WHEN** `player_detail_modal` is rendered
- **THEN** a navigation link to `/players/:id` SHALL be present regardless of what is in the `:actions` slot

#### Scenario: Actions slot renders caller content
- **WHEN** `player_detail_modal` is rendered with content in the `:actions` slot
- **THEN** that content SHALL appear in the modal below the player info

#### Scenario: Actions slot is optional
- **WHEN** `player_detail_modal` is rendered without an `:actions` slot
- **THEN** the modal SHALL render without error, showing only player info, the show page link, and a close button

#### Scenario: Close button fires deselect_player event
- **WHEN** the close button in `player_detail_modal` is clicked
- **THEN** a `deselect_player` LiveView event SHALL be pushed
