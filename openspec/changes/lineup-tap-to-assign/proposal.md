## Why

The lineup planner page supports drag-and-drop to assign players to slots, but drag-and-drop is unusable on touch devices. The `match-lineup` spec includes a tap-to-assign requirement that is not yet working correctly. The roster planner solves the same problem with a modal pattern — tapping a player opens a bottom sheet with destination buttons — and the same pattern should be applied here.

## What Changes

- Tapping a player card on the lineup board opens a `player_detail_modal` (bottom sheet) showing one button per slot and an Available button.
- Slot buttons are labeled `{column_name} - {slot_name}` (e.g. "Singles - #1"). The player's currently assigned slot button is styled as filled; all others are outline.
- Tapping any button moves the player to that destination and closes the modal. Dismissing the modal without tapping a button makes no change.
- All moves route through the existing `move_lineup_player` event handler — no new assignment logic is needed.
- The `assign_selected_player` event handler and slot zone click wiring are removed as dead code.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `match-lineup`: Replace the in-progress select-then-tap implementation with the modal pattern. Update the four tap-to-assign scenarios to reflect the new interaction.

## Impact

- `lib/tennis_tracker_web/components/board_components.ex` — no changes needed (reuse `player_detail_modal` as-is)
- `lib/tennis_tracker_web/live/matches/lineup_edit_live.ex` — update `select_player` handler, add `deselect_player` handler, remove `assign_selected_player` handler, update template
- `test/tennis_tracker_web/live/matches/lineup_edit_live_test.exs` — new scenarios for tap-to-assign interactions
