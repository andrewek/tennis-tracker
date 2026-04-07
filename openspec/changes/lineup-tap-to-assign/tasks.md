## 1. Update Event Handlers in `lineup_edit_live.ex`

- [ ] 1.1 Update `handle_event("select_player", ...)` to unconditionally set `selected_player_id` to the tapped player's ID (remove the toggle — `if current == player_id, do: nil` logic)
- [ ] 1.2 Add `handle_event("deselect_player", _params, socket)` that sets `selected_player_id` to `nil`
- [ ] 1.3 Remove `handle_event("assign_selected_player", ...)` — dead code once the modal handles all tap interactions

## 2. Update Template in `lineup_edit_live.ex`

- [ ] 2.1 Remove the `assign_event` attr from all `<.lineup_slot_zone>` calls in the template
- [ ] 2.2 Add `<.player_detail_modal>` rendered when `@selected_player_id` is not nil, with:
  - `player` — look up the player struct from `@available` and `@assignments` by `@selected_player_id`
  - `group_slug={@current_group.slug}`
  - `on_close={JS.push("deselect_player")}`
  - `:actions` slot containing:
    - An Available button: `phx-click="move_lineup_player"`, `phx-value-player_id={selected_player.id}`, `phx-value-target_id="available"`, styled `btn-primary` if the player is currently in Available (unassigned), `btn-outline` otherwise — same convention as slot buttons
    - One button per slot, iterating `@lineup_columns` then their slots: labeled `"{column.name} - {slot.name}"`, `phx-click="move_lineup_player"`, `phx-value-player_id={selected_player.id}`, `phx-value-target_id={slot.id}`, styled `btn-primary` if the player is currently assigned to that slot, `btn-outline btn-primary` otherwise
- [ ] 2.3 Verify the `selected` attr on player cards still passes `@selected_player_id == player.id` so the tapped card shows a highlighted ring while the modal is open

## 3. Tests

- [ ] 3.1 Add test: tapping a player card in the Available column opens the modal (modal element is present, player name is shown)
- [ ] 3.2 Add test: tapping a player card in a slot opens the modal
- [ ] 3.2a Add test: when a player in Available opens the modal, the Available button is styled as filled (`btn-primary`) and slot buttons are outline
- [ ] 3.3 Add test: tapping a slot button in the modal assigns the player to that slot and closes the modal
- [ ] 3.4 Add test: tapping the Available button in the modal unassigns the player and closes the modal
- [ ] 3.5 Add test: dismissing the modal (close button) makes no assignment change
- [ ] 3.6 Run `mix precommit` and confirm all tests pass with no warnings
