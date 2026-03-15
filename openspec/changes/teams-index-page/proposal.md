## Why

Users need a dedicated Teams index page to browse all teams at a glance, currently there is no such page — the home page links to teams but no listing exists. This provides a central hub for navigating to individual team pages.

## What Changes

- Add a `/teams` route with a new `Teams.IndexLive` LiveView
- Update the home page link to point to `/teams`
- Display all teams as cards sorted by season year (desc), age group (asc), NTRP level (desc), then name (asc) — the existing Team primary read action's default sort
- Each card shows: team name, category (age group + NTRP level), and placeholder next-match info

## Capabilities

### New Capabilities
- `teams-index`: A paginated/listed index page showing all teams as cards with name, category, and placeholder next-match data

### Modified Capabilities
- `home-page`: Update the teams link to point to `/teams` instead of current placeholder

## Impact

- New LiveView: `lib/tennis_tracker_web/live/teams/index_live.ex`
- Router: new `/teams` live route
- `lib/tennis_tracker_web/controllers/page_html/home.html.heex`: update Teams card `href` to `/teams`
- `lib/tennis_tracker_web/live/teams/show_live.ex`: update back link from `/` to `/teams`
- `lib/tennis_tracker/tennis/team.ex`: new `:list_real` read action and `team_type_name` calculation
