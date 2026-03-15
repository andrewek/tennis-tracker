## 1. Shared Components

- [ ] 1.1 Add `readonly` boolean attr (default `false`) and `on_click` string attr (default `"select_player"`) to `BoardComponents.player_card`; when `readonly: true`, omit `draggable`, `phx-hook`, `data-player-id`, and violation indicator; use `on_click` as the `phx-click` value — all existing board usages are unaffected
- [ ] 1.2 Add `on_close` attr to `BoardComponents.player_detail_modal` (JS command, required); replace the hardcoded `JS.push("deselect_player")` with `@on_close`; update the existing board usage to pass `on_close={JS.push("deselect_player")}` explicitly

## 2. Domain Layer

- [ ] 2.1 Add `get_team_with_roster/1` (non-bang) to `lib/tennis_tracker/tennis.ex` — returns `{:ok, team}` with `:team_type` and `memberships: [:player]` loaded, or `{:error, :not_found}` if the ID doesn't exist or the team is a pseudo-team
- [ ] 2.2 Add the corresponding `define` entry in the Tennis domain for the new function

## 3. Routing

- [ ] 3.1 Add `live "/teams/:id", TennisTrackerWeb.Teams.ShowLive, :show` inside the authenticated live session in `lib/tennis_tracker_web/router.ex`

## 4. Team Show LiveView

- [ ] 4.1 Create `lib/tennis_tracker_web/live/teams/show_live.ex` with module skeleton, `mount/3`, and `handle_params/3`
- [ ] 4.2 In `handle_params`, call `Tennis.get_team_with_roster/1`; on `{:error, _}` redirect to `/` with a flash error; on `{:ok, team}` sort players alphabetically and assign placeholder matches from `@placeholder_matches`
- [ ] 4.3 Add `"show_player"` event handler — find player from assigns by ID, assign to `@selected_player`
- [ ] 4.4 Add `"close_player_modal"` event handler — assign `@selected_player` to nil
- [ ] 4.5 Implement the HEEx template:
  - Header: team name (h1), subtitle with type name / age group / NTRP level / year
  - Responsive two-column grid (`grid grid-cols-1 md:grid-cols-2 gap-6`)
  - Roster card: player count, `<.player_card readonly={true} on_click="show_player">` for each player; empty state message when roster is empty
  - Match schedule card: list of placeholder matches, each showing day/date/time, home-or-away opponent, location
  - Player modal (conditional on `@selected_player`) using `<.player_detail_modal on_close={JS.push("close_player_modal")} current_team={@team.name}>`: player name + "View full profile" link to `/players/:id`
  - "← Back to Teams" link pointing to `/` with a `# TODO: update to ~p"/teams" once the index page exists` comment

## 5. Tests

- [ ] 5.1 Create `test/tennis_tracker_web/live/teams/show_live_test.exs` with LiveView smoke tests:
  - Test that a team with players renders the team name and each player's name
  - Test that navigating to a pseudo-team ID redirects to `/teams` with a flash error
  - Test that navigating to a non-existent team ID redirects to `/teams` with a flash error

## 6. Player Show Page Update

- [ ] 6.1 In `lib/tennis_tracker_web/live/players/show_live.ex`, update `load: [:display_label]` to `load: [:display_label, :team]` (loading `:team` directly on each membership struct so `membership.team.id` is available)
- [ ] 6.2 In the template, wrap each membership's `display_label` text in `<.link navigate={~p"/teams/#{membership.team.id}"}>` instead of rendering it as plain text
