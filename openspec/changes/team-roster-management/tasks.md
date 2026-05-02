## 1. TeamMembership — new actions and policy changes

- [x] 1.1 Add `:add_to_roster` create action accepting `player_id`, `team_id`, `team_type_id`, `season_year`, `group_id`
- [x] 1.2 Add `:remove_from_roster` destroy action with a before-action validation that the player has no match lineup assignments for this team
- [x] 1.3 Add a new Ash policy authorizing both `:add_to_roster` and `:remove_from_roster` for team captains (use or create an `IsTeamCaptain` check) or group owners
- [x] 1.4 Add `define` entries in `TennisTracker.Tennis` domain for `:add_to_roster` and `:remove_from_roster` with appropriate bang variants
- [x] 1.5 Write unit tests for `:add_to_roster` (captain can add, owner can add, member denied) and `:remove_from_roster` (succeeds when no assignments, rejected when assigned to match, member denied)

## 2. Router — Roster tab route

- [x] 2.1 Add route entry for `/g/:slug/teams/:id/settings/roster` pointing to the new `RosterLive` module
- [x] 2.2 Verify the route appears correctly via `mix phx.routes`

## 3. Roster tab LiveView

- [x] 3.1 Create `lib/tennis_tracker_web/live/teams/settings/roster_live.ex` with mount, handle_params, authorization check (redirect non-captains/non-owners), and render
- [x] 3.2 In `handle_params`, load the team's memberships via `Tennis.list_memberships_for_team!/2` with player NTRP ratings, and stream them
- [x] 3.3 Load `SeasonRules` for the team's `(team_type_id, season_year)` (if present) and compute health summary (roster size, on-level percentage); expose as assigns
- [x] 3.4 Render member list (stream) with player name, NTRP rating, and remove button per row; show empty state when no members
- [x] 3.5 Render health summary bar: always show on-level percentage; show roster size vs. min/max targets only when SeasonRules is present
- [x] 3.6 Add "Add Player" button that opens the add-player panel/modal
- [x] 3.7 Implement add-player panel: list group players without an existing TeamMembership on this team
- [x] 3.8 Compute and show eligibility warning (NTRP not in `allowed_ntrp_levels`) when a player is selected in the add panel
- [x] 3.8a Show a distinct "rating unknown — eligibility cannot be verified" note when the selected player has a nil NTRP rating (treat as off-level for on-level percentage projection, consistent with `RosterHealth`)
- [x] 3.9 Compute and show on-level percentage impact warning when the add would drop below `on_level_min_pct`; omit if no SeasonRules
- [x] 3.10 Wire up the confirm-add event to call `Tennis.add_to_roster!` and handle uniqueness errors inline
- [x] 3.11 Wire up the remove button to show a confirmation, then call `Tennis.remove_from_roster!`; handle match-assignment validation error inline
- [x] 3.12 Add `TeamComponents.settings_layout` tab entry for `:roster` pointing to the new URL

## 4. Tab navigation update

- [x] 4.1 Verify all five tabs render correctly on each settings page

## 5. Tests

- [x] 5.1 Write LiveView tests for the Roster tab: renders member list, health summary, redirects non-authorized users
- [x] 5.2 Test add-player flow: eligibility warning shown for ineligible NTRP, "rating unknown" note shown when player has nil NTRP, on-level warning shown when threshold would be broken, successful add updates the roster list
- [x] 5.3 Test remove-player flow: successful remove, error shown when player is in a match lineup
- [x] 5.4 Run `mix precommit` and fix any failures
