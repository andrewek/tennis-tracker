## Context

The lineup planner already has partial tap-to-assign wiring: `selected_player_id` in assigns, `handle_event("select_player")`, `handle_event("assign_selected_player")`, and `phx-click={@assign_event}` on `lineup_slot_zone`. This approach — select a player, then tap a destination slot — is error-prone on touch (click bubbling between player cards and their parent slot zones) and harder to use than the roster planner's modal pattern.

The roster planner solves the same problem with `player_detail_modal`: tapping a player opens a bottom sheet listing destination buttons. The same component and pattern are reused here.

## Goals / Non-Goals

**Goals:**
- Tap a player card anywhere on the board → modal opens listing slot and Available buttons
- Tap a slot button → player is assigned to that slot, modal closes
- Tap the Available button → player is unassigned, modal closes
- Dismiss the modal without tapping a button → no change made
- Works on all screen sizes

**Non-Goals:**
- The inline select-then-tap approach (replaced by this change)
- Supporting multi-player slot assignment via tap (drag-and-drop handles more complex scenarios)
- Any visual hint on the board while the modal is open (the modal is self-explanatory)

## Decisions

### Reuse `player_detail_modal` from `board_components.ex`

**Decision**: Use the existing `player_detail_modal` component unchanged. Pass slot and Available buttons via the `:actions` slot.

**Rationale**: The component already handles bottom-sheet presentation, player name title, NTRP display, and "View profile" link. No new component needed.

### Slot button labels

**Decision**: Label each slot button `"{column_name} - {slot_name}"` (e.g. "Singles - #1"). Iterate `@lineup_columns` in the template, then `lineup_slots` filtered to each column, to build the button list in the same order as the board.

**Rationale**: Matches the visual grouping on the board so the captain can orient from the modal to the board easily.

### Current slot visual differentiation

**Decision**: Buttons for slots the selected player is currently assigned to use `btn-primary` (filled). All other slot buttons use `btn-outline btn-primary`. The Available button uses `btn-outline` (no color modifier) when the player has any slot assignment, and `btn-primary` when the player is already fully unassigned (i.e. in Available).

**Rationale**: Mirrors the roster planner convention where the current destination button is visually distinct. The captain can see at a glance where the player is and tap another slot to move them.

### All moves route through `move_lineup_player`

**Decision**: Modal action buttons fire `phx-click="move_lineup_player"` with `phx-value-player_id` and `phx-value-target_id`. The Available button uses `target_id="available"`. This is identical to the drag-and-drop event.

**Rationale**: `move_lineup_player` already handles all three assignment modes (`:one_per_match`, `:one_per_column`, `:many_per_match`) and unassign. No new server logic is needed.

### Remove `assign_selected_player` and slot zone click handlers

**Decision**: Remove `handle_event("assign_selected_player")` from `lineup_edit_live.ex` and remove the `assign_event` attr from all `<.lineup_slot_zone>` calls in the template.

**Rationale**: These are dead code once the modal handles all tap interactions. Removing them avoids confusion for future maintainers.

### `select_player` becomes open-modal; add `deselect_player`

**Decision**: Update `handle_event("select_player")` to unconditionally set `selected_player_id` (remove the toggle). Add `handle_event("deselect_player")` that sets `selected_player_id` to `nil`. Pass `on_close={JS.push("deselect_player")}` to the modal.

**Rationale**: Toggling was only useful in the select-then-tap model. With a modal, the close button handles deselection.

## Risks / Trade-offs

- **`player_detail_modal` does not receive `current_team`**: That attr is used in the roster planner to show a "Currently: X" text line. For the lineup planner it is omitted (`default: nil`) — the current-slot indication is handled entirely by button styling.
- **Board data required for modal buttons**: The modal iterates `@lineup_columns` and `@lineup_slots` to render buttons. These are already loaded in `load_board/3` and available as assigns. No additional data loading is needed.
