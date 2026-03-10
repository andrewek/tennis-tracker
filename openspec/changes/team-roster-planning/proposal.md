## Why

Captains need a way to plan USTA team rosters each season — assigning players to teams, tracking who's sitting out, and collaborating with other captains in real time. There is currently no team or roster concept in the app.

## What Changes

- Introduce `TeamType` as seeded reference data describing the structure of a USTA league format (age group, NTRP level, allowed ratings)
- Introduce `SeasonRules` to capture per-year configuration (min/max roster size, on-level percentage requirements) for each team type
- Introduce `Team` as an actual team competing in a season, belonging to a team type
- Introduce `TeamMembership` linking players to teams, with a "Not Participating" pseudo-team for explicitly tracking non-participants per planning context
- Add a `/roster-planner` route with a planning board UI: select a season + team type, then drag-and-drop (desktop) or tap-to-assign (mobile) players across team columns
- Real-time collaborative sync via Phoenix PubSub so multiple people can plan together
- Non-blocking health indicators on teams and players when roster rules are violated

## Capabilities

### New Capabilities

- `team-type`: Seeded reference data defining USTA league formats (age group, NTRP level, allowed ratings, name)
- `season-rules`: Per-season configuration for each team type (min/max roster, on-level percentage)
- `team-management`: Creating and managing teams within a season and team type
- `team-membership`: Assigning players to teams and tracking "Not Participating" status per planning context
- `roster-planner`: The planning board UI — select context, view and manipulate all teams and unassigned players, with real-time sync and health indicators

### Modified Capabilities

<!-- None — no existing spec-level behavior changes -->

## Impact

- New Ash resources: `TeamType`, `SeasonRules`, `Team`, `TeamMembership` under `TennisTracker.Tennis` domain
- New Ash migrations via `mix ash_postgres.generate_migrations`
- New LiveView: `TennisTrackerWeb.Live.RosterPlanner`
- Phoenix PubSub wired to the roster planner for real-time collaboration
- New route: `GET /roster-planner`
- Existing `Player` resource referenced (no schema changes)
- Seed data script for `TeamType` records (8 types: 18+/40+ × 3.0/3.5/4.0/4.5)
