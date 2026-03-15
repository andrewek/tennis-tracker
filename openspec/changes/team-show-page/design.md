## Context

The app currently has a roster planner (a planning/editing tool) and a player show page. There is no standalone read-only view for a team. Teams need a public-facing page that shows their identity, roster, and eventually a match schedule. This change introduces that page and wires it up from the player show page.

The Team resource has `name`, `season_year`, `is_pseudo`, and `belongs_to :team_type`. TeamType carries `name`, `age_group`, and `ntrp_level`. Memberships join teams to players. No schema changes are needed.

## Goals / Non-Goals

**Goals:**
- Read-only team show page at `/teams/:id` behind login
- Displays team identity (name, type, age group, NTRP level, year)
- Displays roster sorted alphabetically, mirroring the planner's player card style (name + NTRP)
- Displays placeholder match schedule
- Player names open a quick-look modal with a link to the full player profile
- Team names on the player show page link to `/teams/:id`
- Responsive on mobile and desktop

**Non-Goals:**
- Match schedule schema/data model (future change)
- `/teams` index page (future change)
- Editing team data from this page
- Public (unauthenticated) access

## Decisions

**Load strategy: non-bang `get_team_with_roster/1` returning `{:ok, team}` or `{:error, reason}`**

A new domain function `get_team_with_roster/1` loads the team by ID and preloads `:team_type` and `memberships: [:player]`. Returns `{:ok, team}` on success, `{:error, :not_found}` if the ID doesn't exist or the team is a pseudo-team. `handle_params` pattern-matches on the result and redirects with a flash error on `{:error, _}`.

Non-bang is preferred here because the error case is a normal control-flow outcome (stale link, pseudo-team ID) rather than a programmer error — using `rescue` in `handle_params` would be awkward.

Players are sorted in Elixir (`Enum.sort_by(&(&1.name))`) after loading since the membership read action doesn't have an alphabetical-by-player-name sort built in. Acceptable — rosters are small (typically < 10 players).

Alternative considered: add a dedicated read action on TeamMembership sorted by player name. Rejected as over-engineering for the current scale.

**Guard against pseudo-teams and missing teams: redirect to `/` with flash error**

If `get_team_with_roster/1` returns `{:error, _}`, redirect to `/` with a flash error message. (`/teams` does not exist yet and would itself 404.)

**Placeholder match data: module attribute**

Match schedule data lives as a `@placeholder_matches` module attribute in the LiveView until the real schema is built. This keeps the placeholder obviously temporary and easy to replace.

**Roster card styling: extend `player_card` with `readonly` and `on_click` attrs**

The show page roster mirrors the roster planner's player cards (same `bg-base-100 hover:bg-base-300` card with name left / NTRP right). Two new attrs on `BoardComponents.player_card`:

- `readonly` (boolean, default `false`): when `true`, omits `draggable`, `phx-hook="DraggableCard"`, `data-player-id`, and the violation indicator
- `on_click` (string, default `"select_player"`): the `phx-click` event name

The board passes `on_click="select_player"` implicitly via the default. The show page passes `readonly={true}` and `on_click="show_player"`. No existing board usages need to change.

**Player modal: ephemeral socket assign**

`@selected_player` holds nil or a full player struct. Set on `"show_player"` event (looked up from already-loaded players list), cleared on `"close_player_modal"`. No additional DB call needed. Pass `current_team={team.name}` to show which team the player is on (consistent with the board modal). No selected-card highlight — all cards remain visually neutral while the modal is open.

**Back link: placeholder pointing to `/`**

The page includes a "← Back to Teams" link. Until `/teams` (the index) is built, it points to `/` with a TODO comment in the code to update it.

**Layout: `Layouts.app` with responsive grid**

The roster planner uses `Layouts.full_bleed` for its drag-and-drop board. The team show page is informational, so `Layouts.app` (standard constrained-width layout) fits better. Desktop: `grid grid-cols-1 md:grid-cols-2 gap-6`. Mobile: single column stack.

**Player show page: load `team` alongside `display_label` on memberships**

The existing load is `load: [:display_label]` applied to memberships returned by `list_real_memberships_for_player!/2`. Update to `load: [:display_label, :team]` — loading the `team` relationship directly on each membership so `membership.team.id` is available for the link href while `membership.display_label` provides the display text. (`memberships: [:team]` would be the syntax when loading from a parent resource; here we're loading on the membership structs directly.)

## Risks / Trade-offs

- **Placeholder data will look odd** if the page goes live before real match data exists → Mitigation: label the section clearly as "Match Schedule" with a note that data is coming, or just ship with realistic-looking placeholder values
- **Alphabetical sort in Elixir vs DB** → Fine at current roster sizes; revisit if rosters grow significantly
- **No `/teams` index yet** → The show page is navigable only from player profiles until the index is built; acceptable as an interim state

## Open Questions

- **PubSub roster streaming**: The roster planner already emits Ash PubSub notifications on topic `"roster:#{team_type_id}:#{season_year}"` whenever a membership changes. Explore whether the team show page should subscribe to the same topic and reload its roster on `handle_info(%Ash.Notifier.Notification{})`, so live updates from the planner (or any other source) are reflected in real time without a page refresh. This mirrors the pattern already used in `RosterPlannerLive`. The main question is whether this adds meaningful value for a read-only view, or if a stale roster until next navigation is acceptable.
