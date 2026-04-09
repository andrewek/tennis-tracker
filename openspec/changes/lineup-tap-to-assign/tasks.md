## 1. Update Event Handlers in `lineup_edit_live.ex`

- [x] 1.1 Update `handle_event("select_player", ...)` to set `selected_player_id` only when it is currently `nil` (no modal open); if a modal is already open the event is a no-op — remove the old toggle logic (`if current == player_id, do: nil`)
- [x] 1.2 Add `handle_event("deselect_player", _params, socket)` that sets `selected_player_id` to `nil`
- [x] 1.3 Remove `handle_event("assign_selected_player", ...)` — dead code once the modal handles all tap interactions

## 2. Update Template in `lineup_edit_live.ex`

- [x] 2.1 Remove the `assign_event` attr from all `<.lineup_slot_zone>` calls in the template
- [x] 2.2 Add `<.player_detail_modal>` rendered when `@selected_player_id` is not nil, with:
  - `player` — look up the player struct from `@available` and `@assignments` by `@selected_player_id`
  - `group_slug={@current_group.slug}`
  - `on_close={JS.push("deselect_player")}`
  - `:actions` slot containing:
    - An Available button: `phx-click="move_lineup_player"`, `phx-value-player_id={selected_player.id}`, `phx-value-target_id="available"`, styled `btn-primary` if the player is currently unassigned (in Available), `btn-outline btn-primary` otherwise
    - One button per slot, iterating `@lineup_columns` then their slots: labeled `"{column.name} - {slot.name}"`, `phx-click="move_lineup_player"`, `phx-value-player_id={selected_player.id}`, `phx-value-target_id={slot.id}`, styled `btn-primary` if the player is currently assigned to that slot, `btn-outline btn-primary` otherwise
- [x] 2.3 Remove the `selected` attr from all player card calls in the template — the modal title identifies the player, no board-level highlight is needed (`@selected_player_id` stays in assigns for modal rendering)

## 3. Tests

- [x] 3.1 Add test: tapping a player card in the Available column opens the modal (modal element is present, player name is shown)
- [x] 3.2 Add test: tapping a player card in a slot opens the modal
- [x] 3.3 Add test: when a player in Available opens the modal, the Available button is styled as filled (`btn-primary`) and slot buttons are `btn-outline btn-primary`
- [x] 3.4 Add test: when a player already assigned to a slot opens the modal, that slot's button is styled `btn-primary` and all other buttons (including Available) are `btn-outline btn-primary`
- [x] 3.5 Add test: tapping a slot button in the modal assigns the player to that slot and closes the modal
- [x] 3.6 Add test: tapping the Available button in the modal unassigns the player and closes the modal
- [x] 3.7 Add test: dismissing the modal via the close button makes no assignment change. (Clicking outside the modal is handled by `phx-click-away` on the modal component — no separate test needed.)
- [x] 3.8 Add test: tapping a different player card while the modal is open leaves the modal open showing the original player (no switch)
- [x] 3.9 Run `mix precommit` and confirm all tests pass with no warnings
