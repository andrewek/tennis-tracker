## ADDED Requirements

### Requirement: Roster tab is accessible at /teams/:id/settings/roster
The system SHALL provide a Roster tab at `/g/:slug/teams/:id/settings/roster`. Pseudo-teams (`is_pseudo == true`) SHALL NOT be accessible via this route. Users who are neither a team captain nor a group owner SHALL be redirected to the team show page with a flash error.

#### Scenario: Team captain navigates to the Roster tab
- **WHEN** a team captain navigates to `/g/:slug/teams/:id/settings/roster`
- **THEN** the Roster tab loads with the current team roster

#### Scenario: Group owner navigates to the Roster tab
- **WHEN** a group owner navigates to `/g/:slug/teams/:id/settings/roster`
- **THEN** the Roster tab loads with the current team roster

#### Scenario: Group member who is not a captain is redirected
- **WHEN** a regular group member (not a captain, not an owner) navigates to `/g/:slug/teams/:id/settings/roster`
- **THEN** the user is redirected to the team show page
- **AND** a flash error message is displayed

---

### Requirement: Roster tab displays current team members grouped by membership type
The Roster tab SHALL list all TeamMembership records for the team. Playing members and non-playing members SHALL be displayed in separate, labeled sections. Each row SHALL show the player's name and NTRP rating.

#### Scenario: Playing and non-playing members appear in separate sections
- **WHEN** the Roster tab loads for a team with both playing and non-playing members
- **THEN** a "Playing" section lists the playing members
- **AND** a "Non-Playing" section lists the non-playing members

#### Scenario: Empty playing section shows an empty state
- **WHEN** the team has no playing members
- **THEN** the Playing section shows an empty state message

#### Scenario: Empty non-playing section is not shown
- **WHEN** the team has no non-playing members
- **THEN** the Non-Playing section is not rendered

---

### Requirement: Roster tab shows a health summary for playing members
The Roster tab SHALL display a health summary showing the team's current roster size (playing members only) and on-level percentage (playing members only). The on-level percentage is the proportion of playing members whose NTRP rating equals the team type's `ntrp_level`. If no SeasonRules exist for the team's (team_type, season_year), the roster size health targets are omitted.

#### Scenario: Health summary shows roster size and on-level percentage
- **WHEN** the Roster tab loads for a team with playing members and active SeasonRules
- **THEN** the health summary shows the current player count against the min/max roster targets
- **AND** the health summary shows the on-level percentage and whether it meets the `on_level_min_pct` threshold

#### Scenario: On-level percentage excludes non-playing members
- **WHEN** a team has a non-playing member whose NTRP rating is at team level
- **THEN** that member is NOT counted toward the on-level percentage

#### Scenario: No SeasonRules — roster size targets are omitted
- **WHEN** no SeasonRules record exists for the team's context
- **THEN** the health summary omits min/max roster size targets
- **AND** the on-level percentage is still shown

---

### Requirement: Captain can add a player from the group's player list
The Roster tab SHALL provide an "Add Player" affordance that opens a panel or modal listing all group players who do not already have a TeamMembership for **this specific team**. Players who have a membership on a different team for the same (team_type, season_year) ARE shown — the uniqueness constraint is enforced at the data layer, and if the add fails, an inline error is displayed. The captain SHALL be able to select a player and choose a membership type (playing or non-playing) before confirming the add.

#### Scenario: Add Player panel lists eligible players
- **WHEN** a captain opens the Add Player panel
- **THEN** all group players who do not already have a TeamMembership on this team are listed
- **AND** players already on this team are not shown

#### Scenario: Adding a player already on another team for this context fails with an inline error
- **WHEN** a captain selects a player who already has a TeamMembership for a different team in this (team_type, season_year)
- **AND** confirms the add
- **THEN** the add fails due to the uniqueness constraint
- **AND** an inline error message explains the player is already assigned to another team
- **AND** the add panel remains open

#### Scenario: Adding a playing member creates a TeamMembership with membership_type :playing
- **WHEN** a captain selects a player, chooses "Playing", and confirms
- **THEN** a TeamMembership record is created with `membership_type: :playing`
- **AND** the player appears in the Playing section of the roster

#### Scenario: Adding a non-playing member creates a TeamMembership with membership_type :non_playing
- **WHEN** a captain selects a player, chooses "Non-Playing", and confirms
- **THEN** a TeamMembership record is created with `membership_type: :non_playing`
- **AND** the player appears in the Non-Playing section of the roster

---

### Requirement: Add Player flow shows eligibility warnings for ineligible NTRP levels
Before confirming an add, the system SHALL display an inline, non-blocking warning if the candidate player's NTRP rating is not in the team type's `allowed_ntrp_levels`. The warning SHALL NOT prevent the add from proceeding.

#### Scenario: Player NTRP level is not in allowed levels — warning shown
- **WHEN** a captain selects a player whose NTRP rating is not in `allowed_ntrp_levels` for this team type
- **THEN** an inline warning is shown indicating the player does not meet the eligibility requirements
- **AND** the captain can still confirm the add

#### Scenario: Player NTRP level is in allowed levels — no eligibility warning
- **WHEN** a captain selects a player whose NTRP rating is in `allowed_ntrp_levels`
- **THEN** no eligibility warning is shown

#### Scenario: Player has no NTRP rating — eligibility unknown warning
- **WHEN** a captain selects a player with a nil NTRP rating
- **THEN** an inline note indicates the player's rating is unknown and eligibility cannot be verified

---

### Requirement: Add Player flow shows on-level percentage impact for playing membership
A player is **on-level** if their NTRP rating equals the team type's `ntrp_level`. This is distinct from eligibility, which checks whether the player's NTRP rating is in `allowed_ntrp_levels`. When adding a player as "Playing", the system SHALL display the projected on-level percentage after the add. If the projected percentage would fall below `on_level_min_pct` (from SeasonRules), a non-blocking warning SHALL be shown.

#### Scenario: Adding a playing on-level player improves or maintains on-level percentage
- **WHEN** a captain selects a player whose NTRP rating equals `team_type.ntrp_level` and chooses "Playing"
- **THEN** the projected on-level percentage is shown and is greater than or equal to the current percentage

#### Scenario: Adding an off-level player as playing would drop below threshold — warning shown
- **WHEN** a captain selects a player whose NTRP rating does not equal `team_type.ntrp_level`, chooses "Playing", and the resulting on-level percentage would fall below `on_level_min_pct`
- **THEN** a non-blocking warning is shown indicating the threshold would be violated
- **AND** the captain can still confirm the add

#### Scenario: No SeasonRules — on-level percentage impact omitted
- **WHEN** no SeasonRules record exists for the team's context
- **THEN** no on-level threshold warning is shown in the add flow

---

### Requirement: Captain can remove any member who is not assigned to any match
The Roster tab SHALL provide a remove affordance for each member, regardless of membership type. Clicking it SHALL open a confirmation. Confirming SHALL destroy the TeamMembership. If the player is assigned to any match lineup for this team, the remove SHALL be rejected with an inline error and no destruction occurs. Non-playing members cannot be in match lineups, so the guard always passes for them.

#### Scenario: Remove a player with no match assignments
- **WHEN** a captain removes a player who has no match lineup assignments for this team
- **THEN** a confirmation prompt is shown
- **AND** upon confirmation, the TeamMembership is destroyed
- **AND** the player no longer appears on the Roster tab

#### Scenario: Remove a player who is assigned to a match — rejected
- **WHEN** a captain attempts to remove a player who is already assigned to a match lineup for this team
- **THEN** an inline error is displayed indicating the player cannot be removed because they are assigned to a match
- **AND** the TeamMembership is not destroyed

#### Scenario: Remove a non-playing member
- **WHEN** a captain removes a non-playing member
- **THEN** a confirmation prompt is shown
- **AND** upon confirmation, the TeamMembership is destroyed
- **AND** the player no longer appears on the Roster tab

#### Scenario: Cancelling the remove leaves the membership intact
- **WHEN** a captain opens the remove confirmation and cancels
- **THEN** the TeamMembership is not destroyed and the player remains on the roster

---

### Requirement: Roster management is authorized for team captains and group owners
Both team captains (users with a TeamRole of `:captain` for this team) and group owners (users with `GroupMembership.role == :owner`) SHALL be permitted to add and remove players via the Roster tab. Group members who are not captains or owners SHALL be denied these actions.

#### Scenario: Group member (non-captain, non-owner) cannot add a player
- **WHEN** a group member who is neither a captain nor an owner attempts the add action
- **THEN** the action is denied at the data layer
- **AND** the Add Player affordance is not shown in the UI

#### Scenario: Team captain can add a player
- **WHEN** a team captain adds a player via the Roster tab
- **THEN** the TeamMembership is created successfully

#### Scenario: Group owner can add a player
- **WHEN** a group owner adds a player via the Roster tab
- **THEN** the TeamMembership is created successfully
