## Why

Team captains currently have no way to adjust their team roster mid-season without using the full roster planner tool, which is designed for season-wide planning by group owners rather than in-season adjustments by captains. A dedicated roster tab on the team settings page gives captains a focused, self-service way to add or remove players as circumstances change during a season.

## What Changes

- A new **Roster tab** is added to the team settings page at `/g/:slug/teams/:id/settings/roster`, visible and actionable by team captains and group owners.
- The tab lists all current team members with their name and NTRP rating.
- Captains can **add a player** from the group's existing player list. The UI shows eligibility and on-level health information before confirming the add.
- Captains can **remove a player** from the team, with a hard guard preventing removal of any player already assigned to a match lineup.
- Eligibility warnings (player NTRP not in team's `allowed_ntrp_levels`) and on-level percentage impact are surfaced as inline, non-blocking warnings at the time of add.

## Capabilities

### New Capabilities
- `team-roster-tab`: The Roster tab on the team settings page — lists team members, add-player flow with eligibility/health warnings, remove-player with match-assignment guard.

### Modified Capabilities
- `team-edit-page`: Adds a fifth tab (Roster) to the tab navigation layout.

## Impact

- **`TennisTracker.Tennis.TeamMembership`** — new Ash actions to add/remove a player to a team (distinct from the roster planner's drag-and-drop upsert).
- **Team settings LiveView** — new tab module at `/settings/roster`, new router entry.
- **Ash policies** — `add_to_roster` and `remove_from_roster` actions must be authorized for both team captains and group owners (broader than the current roster-planner owner-only restriction).
