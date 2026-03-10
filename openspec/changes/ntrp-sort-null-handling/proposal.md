## Why

Unrated players (NULL NTRP) currently sort to the very top of the list when sorting descending — above 5.0-rated players — because PostgreSQL places NULLs first by default for DESC order. This makes the list misleading: unrated players have no rating, so they should appear below all rated players in descending order (and above all rated players in ascending order).

## What Changes

- When sorting NTRP descending (default), unrated players appear at the bottom of the list, after the lowest-rated players
- When sorting NTRP ascending, unrated players appear at the top of the list, before the lowest-rated players

## Capabilities

### New Capabilities

_(none)_

### Modified Capabilities

- `player-list-view`: The sort order requirement for unrated players is changing — NULL NTRP position relative to rated players is now defined explicitly

## Impact

- `lib/tennis_tracker/tennis/player_filters.ex` — sort expression in `fetch_players/4`
- `test/tennis_tracker/tennis/player_filters_test.exs` — update/add sort tests covering unrated players
- `test/tennis_tracker_web/live/players/index_live_test.exs` — update sort tests if they cover unrated players
