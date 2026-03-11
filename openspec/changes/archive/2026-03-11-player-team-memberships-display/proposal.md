## Why

The player detail page shows profile information but gives no visibility into a player's team history. Coaches need to see at a glance which teams a player has been on across seasons without navigating to the roster planner.

## What Changes

- The `has_many :team_memberships` relationship on `Player` gains a filter (exclude pseudo teams) and a sort (season_year desc, age_group asc, ntrp_level desc)
- The player show page loads and displays a player's real team memberships, formatted as "2026 40+ 4.0 - Team Alpha"
- If Ash does not support sorting a `has_many` relationship by calculated fields on a related `belongs_to` resource, `age_group` and `ntrp_level` will be denormalized onto `TeamMembership` (requiring a migration)

## Capabilities

### New Capabilities

- `player-team-history`: Display a player's team memberships (all seasons, non-pseudo only) on the player detail page, sorted by year desc then age group then NTRP level

### Modified Capabilities

- `player-detail-view`: The player detail page gains a team membership list section

## Impact

- `lib/tennis_tracker/tennis/player.ex` — updated `has_many :team_memberships` relationship
- `lib/tennis_tracker/tennis/team_membership.ex` — possibly new denormalized fields + migration
- `lib/tennis_tracker_web/live/players/show_live.ex` — load memberships via Ash, render list
- Migration required only if denormalization path is taken
