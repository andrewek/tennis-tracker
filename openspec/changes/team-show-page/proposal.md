## Why

Users need a way to view a team's details — its roster and match schedule — without going through the roster planner. The planner is a planning tool; teams need a standalone, read-only home page accessible from any context (future index, player profiles, etc.).

## What Changes

- Add a read-only Team Show page at `/teams/:id` displaying the team header (name, type, age group, NTRP level, year), a roster of players sorted alphabetically, and a match schedule section (placeholder data for now)
- Add a player quick-look modal on the team show page that links to the player's full profile
- Add a `get_team_with_roster!/1` domain function to load a team with its type and roster
- Update the Player Show page so team names in the memberships list link to `/teams/:id`

## Capabilities

### New Capabilities

- `team-show`: Read-only page displaying a team's identity, roster, and match schedule; accessible at `/teams/:id` behind login

### Modified Capabilities

- `player-show`: Team names in the player's membership list become navigable links to the corresponding team show page

## Impact

- New LiveView: `lib/tennis_tracker_web/live/teams/show_live.ex`
- Modified: `lib/tennis_tracker_web/router.ex` (new route)
- Modified: `lib/tennis_tracker/tennis.ex` (new domain function)
- Modified: `lib/tennis_tracker_web/live/players/show_live.ex` (team links)
- No schema changes, no migrations
