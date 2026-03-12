## Context

The Roster Planner LiveView contains two private function components (`player_card`, `board_column`) and an inline modal template. These are tightly coupled to Roster Planner's event model and cannot be reused. A forthcoming Lineup Setter feature requires the same drag-and-drop board primitives with different column semantics (lineup positions instead of teams) and different modal actions (assign to position instead of move to team).

The current JS hooks (`.RosterDrag`, `.RosterDrop`) are colocated in the LiveView template — a Phoenix mechanism that scopes hooks to a single LiveView. Reuse across LiveViews requires moving them to `app.js`.

## Goals / Non-Goals

**Goals:**
- Extract `player_card`, `board_column`, and player detail modal into a shared `board_components.ex`
- Make hooks reusable by moving them to `app.js` with configurable event names and target IDs
- Add a player show page link to the player detail modal
- Leave all Roster Planner behavior and event handlers unchanged

**Non-Goals:**
- Building the Lineup Setter feature
- Changing any Ash domain logic or data loading
- Generalizing the board beyond player-card-in-column (e.g., arbitrary draggable items)
- Making `board_column` aware of lineup slot constraints (capacity limits, position rules)

## Decisions

### Components go in `board_components.ex`, not `core_components.ex`

`core_components.ex` holds generic UI primitives (buttons, inputs, tables). The board components are domain-aware — they know about players, NTRP ratings, violation states, and the player show page route. Keeping them separate preserves that distinction and avoids bloating `core_components.ex`.

### `target_id` replaces `team_id` on `board_column`

The drop zone needs an identifier for "where this player landed." In Roster Planner that's a team ID; in Lineup Setter it will be a position ID or slot identifier. The generic name `target_id` keeps the component unaware of what kind of thing a column represents. The LiveView interprets the value in context.

### Hooks move to `app.js`, configured via `data-*` attributes

**Alternatives considered:**
- *Copy colocated hooks into each LiveView* — simple, but duplicates JS logic and diverges over time.
- *Extract into a LiveComponent* — encapsulates well, but adds complexity and fights the existing streaming/PubSub model in Roster Planner.

`app.js`-level hooks with `data-drop-event` and `data-target-id` keep JS in one place while letting each LiveView configure behavior declaratively. The hooks stay simple (< 20 lines each).

### `player_detail_modal` uses a named `:actions` slot

The always-present content (player name, NTRP, show page link, close button) is baked in. Context-specific actions (move-to-team buttons, assign-to-position buttons) are passed by the caller via `:actions`. An empty `:actions` slot is valid — the modal degrades gracefully to a read-only player card.

### `board_column` uses a named `:header_actions` slot

Team edit/delete buttons are Roster Planner concerns. The column component renders whatever the caller puts in `:header_actions`. Lineup Setter columns may have different header controls (or none). This removes the `deletable`, `modal_open`, and `team` attrs that were leaking Roster Planner semantics into a would-be generic component.

## Risks / Trade-offs

[Hook rename] Renaming `.RosterDrag`/`.RosterDrop` to `DraggableCard`/`DropZone` is a hard cut — any session holding the old LiveView during deploy will lose drag-and-drop until they reload. → Acceptable; this is a dev-only app with no concurrent users across deploys.

[`phx-click="select_player"`] The player card fires a hardcoded `select_player` event. If a future LiveView needs a different event name, it will need either a `select_event` attr on `player_card` or a JS-only toggle approach. → Accept for now; add `select_event` attr when the second consumer exists.

[`player_detail_modal` close button] The modal renders a `phx-click="deselect_player"` close button. This event name is hardcoded, same situation as above. → Accept for now.

## Open Questions

None — all decisions reached during exploration. Lineup slot constraint modeling (capacity per position, etc.) is explicitly deferred.
