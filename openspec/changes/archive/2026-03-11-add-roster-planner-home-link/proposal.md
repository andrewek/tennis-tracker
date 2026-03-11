## Why

The Roster Planner feature (`/roster-planner`) has been built but is not discoverable from the home page. Adding a card for it gives captains a direct entry point from the app's main navigation hub.

## What Changes

- Add a "Roster Planner" card to the home page card grid, linking to `/roster-planner`

## Capabilities

### New Capabilities

<!-- None -->

### Modified Capabilities

- `home-page`: Add a fourth card — "Roster Planner" — that links to `/roster-planner` as an active destination

## Impact

- `lib/tennis_tracker_web/live/home_live.ex` (or equivalent home page template) — add one card
- `openspec/specs/home-page/spec.md` — update requirements to include the Roster Planner card
