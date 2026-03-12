## Why

The Roster Planner's player card, board column, and player detail modal are private components tightly coupled to that LiveView. Extracting them into a shared `board_components.ex` enables reuse in a forthcoming Lineup Setter feature (and any other "move items between columns" UI), while also improving the Roster Planner modal with a link to each player's detail page.

## What Changes

- New `lib/tennis_tracker_web/components/board_components.ex` with three public components: `board_column`, `player_card`, and `player_detail_modal`
- `board_column`: generalized from the private `RosterPlannerLive` component; `team_id` attr renamed to `target_id`; hardcoded team edit/delete buttons replaced with a named `:header_actions` slot; dead `selected_player_id` attr removed
- `player_card`: extracted from `RosterPlannerLive`; `column_id` attr removed (was unused); `phx-hook` updated from colocated `.RosterDrag` to app-level `DraggableCard`
- `player_detail_modal`: new component replacing the inline modal in `RosterPlannerLive`; always renders player name, NTRP rating, and a link to `/players/:id`; context-specific actions (move-to-team buttons) provided via named `:actions` slot
- `assets/js/app.js`: add `DraggableCard` and `DropZone` hooks (migrated from colocated scripts); `DropZone` reads `data-drop-event` and `data-target-id` for configurability
- `RosterPlannerLive`: updated to use shared components; colocated hook `<script>` blocks removed; team edit/delete buttons moved into `:header_actions` slots; `move_player` event handler and all socket logic unchanged

## Capabilities

### New Capabilities

- `board-components`: Shared drag-and-drop board UI primitives (`board_column`, `player_card`, `player_detail_modal`) usable across any LiveView that moves players between columns

### Modified Capabilities

- `player-detail-view`: The player detail modal on the Roster Planner now includes a navigation link to the player's show page — a new user-visible behavior on that surface

## Impact

- `lib/tennis_tracker_web/live/roster_planner_live.ex` — significant internal refactor; no behavior changes except the new player show page link in the modal
- `assets/js/app.js` — two new hooks added; hook names change from `.RosterDrag`/`.RosterDrop` to `DraggableCard`/`DropZone` (the old colocated names disappear with their `<script>` blocks)
- No database changes, no API changes, no other LiveViews affected
