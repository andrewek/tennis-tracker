## Why

Team captains currently have no way to adjust their team roster mid-season without using the full roster planner tool, which is designed for season-wide planning by group owners rather than in-season adjustments by captains. A dedicated roster tab on the team settings page gives captains a focused, self-service way to add or remove players as circumstances change during a season.

## What Changes

- A new **Roster tab** is added to the team settings page at `/g/:slug/teams/:id/settings/roster`, visible and actionable by team captains and group owners.
- The tab lists all current team members (playing and non-playing), grouped by membership type.
- Captains can **add a player** from the group's existing player list. The UI shows eligibility and on-level health information before confirming the add.
- Captains can **remove a player** from the team, with a hard guard preventing removal of any player already assigned to a match lineup.
- `TeamMembership` gains a `membership_type` field (`:playing` | `:non_playing`, default `:playing`). Non-playing members (e.g., an over-rated captain) are visible on the roster tab but are excluded from the lineup's available-player pool and are not counted toward on-level percentage.
- Eligibility warnings (player NTRP not in team's `allowed_ntrp_levels`) and on-level percentage impact are surfaced as inline, non-blocking warnings at the time of add.

## Capabilities

### New Capabilities
- `team-roster-tab`: The Roster tab on the team settings page — lists team members, add-player flow with eligibility/health warnings, remove-player with match-assignment guard, membership type selection (playing vs. non-playing).

### Modified Capabilities
- `team-membership`: Adds `membership_type` enum field (`:playing` | `:non_playing`) to the `TeamMembership` resource. Non-playing members are excluded from lineup available pools and on-level percentage calculations.
- `team-edit-page`: Adds a fifth tab (Roster) to the tab navigation layout.

## Impact

- **`TennisTracker.Tennis.TeamMembership`** — new `membership_type` attribute, new Ash actions to add/remove a player to a team (distinct from the roster planner's drag-and-drop upsert).
- **Team settings LiveView** — new tab module at `/settings/roster`, new router entry.
- **Lineup available-player queries** — must filter to `membership_type == :playing`.
- **On-level percentage health check logic** — must exclude non-playing members from the denominator and from the on-level count.
- **Ash policies** — `add_player` and `remove_player` actions must be authorized for both team captains and group owners (broader than the current roster-planner owner-only restriction).
- **Database** — one new migration to add `membership_type` to `team_memberships`.
