## Why

The players index page lacks filtering support for unrated players and offers no control over sort direction for NTRP, making it harder to find players at the extremes of the rating scale. These small gaps in usability are addressable with minimal effort.

## What Changes

- Add a "No rating" option to the NTRP filter on the players index page so users can find players without an assigned NTRP
- Add seed data entries for players without NTRP ratings to make the feature testable and demo-ready
- Allow users to toggle the NTRP sort direction (ascending/descending) on the players index page; default remains descending

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `player-list-view`: Adding "no rating" filter option, sortable NTRP direction toggle, and default NTRP sort direction change to descending

## Impact

- `lib/tennis_tracker_web/live/player_live/index.ex` — filter and sort logic
- `lib/tennis_tracker_web/live/player_live/index.html.heex` — UI controls
- `priv/repo/seeds.exs` — add unrated players
