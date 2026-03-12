## 1. JS Hooks — migrate to app.js

- [x] 1.1 Add `DraggableCard` hook to `assets/js/app.js`: on `dragstart`, transfer `data-player-id` via `dataTransfer`
- [x] 1.2 Add `DropZone` hook to `assets/js/app.js`: handle `dragover`, `dragleave`, and `drop`; on drop push event named by `data-drop-event` (default `"move_player"`) with `{ player_id, target_id }` from `data-target-id`
- [x] 1.3 Register both hooks in the `liveSocket` hooks object in `app.js`

## 2. Create board_components.ex

- [x] 2.1 Create `lib/tennis_tracker_web/components/board_components.ex` with `use TennisTrackerWeb, :html` and module doc
- [x] 2.2 Implement `board_column/1`: attrs `id`, `title`, `count`, `target_id`, `violations` (default `[]`); slots `:header_actions` and `:inner_block`; uses `phx-hook="DropZone"` and `data-target-id={@target_id}`
- [x] 2.3 Implement `player_card/1`: attrs `player`, `has_violation` (default `false`), `selected` (default `false`); uses `phx-hook="DraggableCard"`, `data-player-id={@player.id}`, `phx-click="select_player"`, `phx-value-player_id={@player.id}`
- [x] 2.4 Implement `player_detail_modal/1`: attr `player`; slot `:actions`; renders player name, NTRP rating, `<.link navigate={~p"/players/#{@player.id}"}>View profile</.link>`, `render_slot(@actions)` (when non-empty), and a `phx-click="deselect_player"` close button

## 3. Update RosterPlannerLive

- [x] 3.1 Add `import TennisTrackerWeb.BoardComponents` (or alias as appropriate) to `RosterPlannerLive`
- [x] 3.2 Replace `board_column` calls in `render/1`: change `team_id=` to `target_id=`; move team edit/delete `<button>` elements into `<:header_actions>` slots; remove `selected_player_id=` and `modal_open=` attrs
- [x] 3.3 Replace `player_card` calls in `render/1`: remove `column_id=` attr; keep `player=`, `has_violation=`, `selected=` as-is
- [x] 3.4 Replace the inline "Mobile: destination picker modal" div (lines 467–519) with `<.player_detail_modal :if={@selected_player_id} player={...}>` — note: requires finding the selected player struct from board assigns by `@selected_player_id`
- [x] 3.5 Add move-to-team buttons into the `<:actions>` slot of `player_detail_modal` (unassigned, each real team, not-participating)
- [x] 3.6 Remove the two colocated `<script :type={Phoenix.LiveView.ColocatedHook}>` blocks (`.RosterDrag` and `.RosterDrop`) from the bottom of `render/1`
- [x] 3.7 Update `handle_event("move_player", ...)` pattern matches: change `"team_id"` key to `"target_id"` in both clauses (the hook now pushes `target_id`, not `team_id`)

## 4. Wire up selected player struct

- [x] 4.1 The `player_detail_modal` needs the full player struct (not just the ID); add a `selected_player` assign to the socket (set alongside `selected_player_id` in `select_player` and cleared in `deselect_player` and `move_player` handlers)
- [x] 4.2 Update `player_detail_modal` usage in the template to use `player={@selected_player}`

## 5. Update existing tests

- [x] 5.1 In `roster_planner_live_test.exs`, update all `render_click(view, "move_player", %{"team_id" => ...})` calls to use `"target_id"` — this is a direct consequence of the handler rename in task 3.7

## 6. Write new tests

- [x] 6.1 Test that clicking a player card fires `select_player` and the player detail modal appears: use `render_click(view, "select_player", %{"player_id" => player.id})` and assert `has_element?(view, "[data-player-modal]")` (or equivalent selector on the modal)
- [x] 6.2 Test that the player detail modal shows the player's name
- [x] 6.3 Test that the player detail modal contains a "View profile" link pointing to `/players/:id` for the selected player — use `has_element?(view, "a[href='/players/#{player.id}']")`
- [x] 6.4 Test that firing `deselect_player` closes the modal: after `select_player`, call `render_click(view, "deselect_player", %{})` and assert the modal is no longer present
- [x] 6.5 Test that firing `move_player` also closes the modal: `select_player` then `move_player`, assert modal absent after

## 7. Verify and clean up

- [x] 7.1 Run `mix phx.server` and manually verify drag-and-drop still works on the Roster Planner board
- [x] 7.2 Verify tap-to-assign modal opens, shows player name + NTRP + "View profile" link, and move-to-team buttons work
- [x] 7.3 Verify "View profile" link navigates to the correct player show page
- [x] 7.4 Run `mix precommit` (compile with warnings-as-errors, format, tests) and fix any issues
