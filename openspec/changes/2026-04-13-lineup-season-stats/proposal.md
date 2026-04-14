## Why

When planning a match lineup, captains need to balance playing time across the roster. Currently there is no way to see — while editing a lineup — how many matches each player has played or is scheduled for this season. Captains work around this by maintaining a separate spreadsheet. This change brings that information into the app, directly on the lineup editor where decisions are being made.

The core question a captain is asking: "Am I leaving someone out by accident?" That requires seeing all players' participation counts together, not one at a time.

## What Changes

### Slot participation types

Replace `is_exclusion_slot: bool` on `TeamLineupSlot` with `participation_type: enum(:playing, :out, :neutral)`.

- `:playing` — the default; counts toward a player's match total
- `:out` — marks a player as unavailable for this match (current exclusion slot behavior)
- `:neutral` — the player is present in some capacity but not playing (sub, beer duty, snack duty, etc.); counts as neither played nor out, but is tracked individually by slot name

The existing "only one `:out` slot per team" constraint is preserved. There is no limit on `:neutral` slots.

This replaces the boolean with a richer abstraction that handles formats beyond the standard single-sub case: tri-level with per-division subs, teams with rotating duties (beer, snacks), formats where the same player can sub at multiple levels.

### Season stats drawer on the lineup editor

A collapsible drawer on the lineup editor showing each roster player's participation counts for the current team's current season. Stats are scoped exclusively to this team — a player on both a 3.5 and a 4.0 team sees only that team's matches reflected here.

Columns:
- **Name**
- **Played** — past matches with a `:playing` assignment (locked, shown in muted style)
- **Planned** — future matches with a `:playing` assignment (mutable)
- **Total** — Played + Planned, shown as `N / M` where M is total matches on the team's schedule
- **Out** — all matches (past + future) with a `:out` assignment
- One column per `:neutral` slot defined on the team, named after the slot (always shown, even if all counts are zero)

The drawer is sortable: by Name (A–Z), Total ascending (fewest first — who needs to catch up), Total descending (most first — who's already set), Out descending (most restricted schedule first).

The drawer updates live as players are moved on the board, because it is driven by the same LiveView assigns.

### Prev/next match navigation

Forward and backward buttons in the lineup editor header let captains move between a team's matches in date order without returning to the match list. The stats drawer stays open and reflects the full season regardless of which match is being edited.

## Capabilities

### New Capabilities

- `lineup-season-stats-drawer`: View per-player season participation counts while editing a match lineup
- `lineup-match-navigation`: Navigate forward and backward between a team's matches from within the lineup editor

### Modified Capabilities

- `lineup-slot-management`: Slots now have a `participation_type` instead of `is_exclusion_slot`; slot creation and editing UI updated accordingly

## Impact

- **Migration**: `team_lineup_slots` — replace `is_exclusion_slot` with `participation_type`; existing exclusion slots migrate to `:out`, all others to `:playing`
- **`TennisTracker.Tennis.TeamLineupSlot`** — attribute change; constraint logic updated
- **`TennisTracker.Tennis.MatchLineupAssignment`** — all `is_exclusion_slot` references replaced with `participation_type == :out`
- **`TennisTracker.Tennis`** — new domain function for season stats aggregation (all assignments for all team matches, grouped by player and participation type)
- **`TennisTrackerWeb.Matches.LineupEditLive`** — drawer component, sort state, prev/next navigation, stats load on mount and refresh on assignment change
- No new dependencies
