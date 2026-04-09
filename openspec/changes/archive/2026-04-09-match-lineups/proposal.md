## Why

Team captains need a way to set a match lineup — assigning players to named positions (S1, D1, D2, etc.) — and share it with their team quickly via copied text. Currently there is no way to record or communicate who is playing where for a given match.

## What Changes

- Captains can define named lineup slots on a team (e.g. "#1 Singles", "#1 Doubles", "Out", "Sub")
- Each slot has an optional expected_count, sort order, and a flag controlling whether it appears in clipboard output
- For any match, a captain can drag players from the available pool into slots using a board UI (reusing existing BoardComponents) on a dedicated lineup edit page (`/matches/:id/lineup-edit`)
- A "Copy Lineup" button on the match show page generates formatted text to the clipboard, showing the match date/time/venue and each clipboard-included slot with its assigned players
- The match show page gains a read-only lineup section and a link to the lineup edit page for captains; empty state guides captains to define slots on the team edit page

## Capabilities

### New Capabilities

- `team-lineup-slots`: Define and manage named lineup slots on a team (name, expected_count, sort order, include-in-clipboard flag)
- `match-lineup`: Assign players to slots for a specific match via a drag-and-drop board, with expected_count warnings and clipboard copy

### Modified Capabilities

- `team-edit-page`: Team edit page gains a slot management section (new UI, no requirement-level behavior change to existing fields)
- `match-show`: Match show page gains a read-only lineup section and a "Copy Lineup" button; captains see a link to the lineup edit page

## Impact

- Two new Ash resources: `TeamLineupSlot`, `MatchLineupAssignment`
- Two new migrations
- New `MatchLineupEditLive` LiveView at `/matches/:id/lineup-edit` (drag-and-drop board, captain-only)
- Read-only lineup section added to match show page (static assignment list + Copy Lineup button)
- New slot management section on team edit page
- Reuses `BoardComponents` (board_column, player_card, drag-and-drop hooks) — no changes to that component library
- No changes to existing Match, Team, Player, or TeamMembership resources
