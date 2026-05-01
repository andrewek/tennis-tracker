## 1. Data Model — membership_type attribute

- [ ] 1.1 Add `membership_type` atom enum attribute (`:playing` | `:non_playing`, default `:playing`, non-null) to `TennisTracker.Tennis.TeamMembership`
- [ ] 1.2 Generate migration with `mix ash_postgres.generate_migrations --name add_membership_type_to_team_memberships`
- [ ] 1.3 Run `mix ecto.migrate` and verify the column exists with the correct default

## 2. TeamMembership — new actions and policy changes

- [ ] 2.1 Add `:add_to_roster` create action accepting `player_id`, `team_id`, `team_type_id`, `season_year`, `group_id`, `membership_type`
- [ ] 2.2 Add `:remove_from_roster` destroy action with a before-action validation that the player has no match lineup assignments for this team
- [ ] 2.3 Add a new Ash policy authorizing both `:add_to_roster` and `:remove_from_roster` for team captains (use or create an `IsTeamCaptain` check) or group owners
- [ ] 2.4 Add `:for_roster` read action returning all memberships for a team regardless of `membership_type`
- [ ] 2.5 Update the `:for_team` read action to filter `membership_type == :playing`
- [ ] 2.6 Add `define` entries in `TennisTracker.Tennis` domain for `:add_to_roster`, `:remove_from_roster`, and `:for_roster` with appropriate bang variants
- [ ] 2.7 Write unit tests for `:add_to_roster` (captain can add, owner can add, member denied), `:remove_from_roster` (succeeds when no assignments, rejected when assigned to match, member denied), `:for_team` (excludes non-playing members), and `:for_roster` (returns all members)

## 3. Router — Roster tab route

- [ ] 3.1 Add route entry for `/g/:slug/teams/:id/settings/roster` pointing to the new `RosterLive` module
- [ ] 3.2 Verify the route appears correctly via `mix phx.routes`

## 4. Roster tab LiveView

- [ ] 4.1 Create `lib/tennis_tracker_web/live/teams/settings/roster_live.ex` with mount, handle_params, authorization check (redirect non-captains/non-owners), and render
- [ ] 4.2 In `handle_params`, load the team's memberships via `Tennis.for_roster!` (both playing and non-playing) with player NTRP ratings, and stream them into separate playing/non-playing streams
- [ ] 4.3 Load `SeasonRules` for the team's context (if present) and compute health summary (roster size, on-level percentage) for the playing members; expose as assigns
- [ ] 4.4 Render "Playing" section (stream) and "Non-Playing" section (stream, hidden when empty) with player name, NTRP rating, and remove button per row
- [ ] 4.5 Render health summary bar (roster size vs. min/max, on-level % vs. threshold)
- [ ] 4.6 Add "Add Player" button that opens the add-player panel/modal
- [ ] 4.7 Implement add-player panel: list group players without an existing (team_type, season_year) membership, membership type selector (playing / non-playing)
- [ ] 4.8 Compute and show eligibility warning (NTRP not in `allowed_ntrp_levels`) when a player is selected in the add panel
- [ ] 4.9 Compute and show on-level percentage impact warning when a playing membership would drop below `on_level_min_pct`; omit if no SeasonRules
- [ ] 4.10 Wire up the confirm-add event to call `Tennis.add_to_roster!` and handle uniqueness errors inline
- [ ] 4.11 Wire up the remove button to show a confirmation, then call `Tennis.remove_from_roster!`; handle match-assignment validation error inline
- [ ] 4.12 Add `TeamComponents.settings_layout` tab entry for `:roster` pointing to the new URL

## 5. Tab navigation update

- [ ] 5.1 Add "Roster" tab to `TeamComponents.settings_layout` (or wherever the tab bar is rendered), linking to `/g/:slug/teams/:id/settings/roster`
- [ ] 5.2 Verify all five tabs render correctly on each settings page

## 6. Tests

- [ ] 6.1 Write LiveView tests for the Roster tab: renders playing/non-playing sections, health summary, redirects non-authorized users
- [ ] 6.2 Test add-player flow: eligibility warning shown for ineligible NTRP, on-level warning shown when threshold would be broken, successful add updates the roster list
- [ ] 6.3 Test remove-player flow: successful remove, error shown when player is in a match lineup
- [ ] 6.4 Regression test: verify lineup editor's available-player pool still works correctly (excludes non-playing members)
- [ ] 6.5 Run `mix precommit` and fix any failures
