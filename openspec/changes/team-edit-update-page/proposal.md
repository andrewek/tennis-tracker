## Why

The team show page currently mixes read-only display with mutation operations (adding matches, editing the team name via the roster planner). This makes the show page harder to reason about and leaves no clean home for future editing features. A dedicated edit page gives mutations a single, predictable location and makes the show page purely informational.

## What Changes

- Add a dedicated team edit page at `/teams/:id/edit` for editing team name, default timezone, and managing the match schedule (add, edit, delete)
- Add a dedicated match edit page at `/matches/:id/edit` for editing match fields and deleting a match
- Strip the team show page of all mutation events and the add-match modal; add an "Edit Team" link pointing to the edit page
- Add an "Edit Match" link on the match show page pointing to the match edit page
- Add `update` and `destroy` actions to the `Match` resource (currently only `create` exists)
- Extract the `format_match_datetime/2` helper into a shared module to eliminate duplication across LiveViews
- Add two new routes to the router

## Capabilities

### New Capabilities
- `team-edit-page`: Dedicated page at `/teams/:id/edit` for editing team name, default timezone, and managing the team's match schedule (add / edit / delete matches)
- `match-edit-page`: Dedicated page at `/matches/:id/edit` for editing match fields (opponent, home/away, date, time, location) and deleting a match

### Modified Capabilities
- `team-show`: The match schedule section becomes fully read-only; an "Edit Team" link is added to the page header

## Impact

- `lib/tennis_tracker/tennis/match.ex` — new `update` and `destroy` actions
- `lib/tennis_tracker/tennis.ex` — new `update_match` and `destroy_match` domain defines
- `lib/tennis_tracker_web/router.ex` — two new live routes
- `lib/tennis_tracker_web/live/teams/show_live.ex` — remove mutation events and match modal
- `lib/tennis_tracker_web/live/matches/show_live.ex` — add Edit Match link
- New files: `Teams.EditLive`, `Matches.EditLive`, shared `MatchHelpers` module
