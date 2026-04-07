## MODIFIED Requirements

### Requirement: Captain can assign a player via tap-to-assign
On any device, a captain SHALL be able to assign players via a modal interaction: tap a player card anywhere on the board to open a destination picker modal, then tap a button in the modal to complete the move.

#### Scenario: Tap player card to open modal
- **WHEN** a captain taps a player card anywhere on the board (in the Available column or already in a slot)
- **THEN** a modal SHALL open showing the player's name and one button per lineup slot plus an Available button
- **AND** slot buttons SHALL be labeled `{column_name} - {slot_name}` (e.g. "Singles - #1")
- **AND** the button corresponding to the player's current location (the assigned slot, or Available if the player is unassigned) SHALL be visually distinct from all other buttons (e.g. filled vs. outline styling)
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

#### Scenario: Dismiss modal without action
- **WHEN** a captain dismisses the modal without tapping a slot or Available button (e.g. taps the close button or outside the modal)
- **THEN** the modal SHALL close with no assignment change made
