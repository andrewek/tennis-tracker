### Requirement: User can select a planning context
The system SHALL provide a way for users to select a planning context (season year + team type) before viewing the planning board. The selection SHALL be surfaced at `/g/:group_slug/roster-planner`.

#### Scenario: Selecting a context loads the planning board
- **WHEN** a user selects a season year and team type from the context selector
- **THEN** the planning board for that context is displayed

#### Scenario: Context selector lists available team types
- **WHEN** the context selector is displayed
- **THEN** all TeamTypes for the current group are listed as options

### Requirement: Planning board takes full width of the page
The planning board SHALL use the full available page width (with standard horizontal padding) rather than a constrained content-width layout. This is necessary because the board may contain 5 or more columns simultaneously.

#### Scenario: Board uses full page width
- **WHEN** the planning board is displayed
- **THEN** the board columns span the full available viewport width (minus padding)
- **AND** other pages in the application are unaffected

### Requirement: Planning board displays all teams and unassigned players
The system SHALL display a board with one column per team (plus Unassigned and Not Participating) for the selected planning context. Player cards SHALL be shown in each column according to their membership status.

#### Scenario: Team columns show their assigned players
- **WHEN** the planning board loads
- **THEN** each team column shows the players assigned to that team

#### Scenario: Not Participating column shows opted-out players
- **WHEN** the planning board loads
- **THEN** the Not Participating column shows all players assigned to the pseudo-team for this context

### Requirement: Unassigned column filtering is performed at the database level
The Unassigned column SHALL show all players who have no membership in the current planning context. This pool is then narrowed by the session-state tag filter (see `roster-planner-tag-filter`). Hard eligibility filtering based on age bracket boolean fields is removed. NTRP-based health check violations continue to surface non-blocking warnings when players are placed on teams.

#### Scenario: Unassigned column shows all players with no membership in this context
- **WHEN** the planning board loads with no tag filter active
- **THEN** the Unassigned column contains all players who have no TeamMembership record for this planning context, regardless of age group, gender league, or other tag attributes

#### Scenario: Tag filter narrows the unassigned pool
- **WHEN** the captain has an active tag filter
- **THEN** the Unassigned column shows only players matching the tag filter (see roster-planner-tag-filter spec)

### Requirement: Players can be moved between columns on desktop via drag-and-drop
The system SHALL support dragging a player card from one column and dropping it onto another column to reassign the player.

#### Scenario: Drag player from Unassigned to a team
- **WHEN** a user drags a player card from Unassigned and drops it on a team column
- **THEN** the player is assigned to that team
- **AND** the board updates without a full page reload

#### Scenario: Drag player between two teams
- **WHEN** a user drags a player card from one team column and drops it on another
- **THEN** the player's membership is updated to the new team

### Requirement: Players can be moved on mobile via tap-to-assign
The system SHALL provide a mobile-friendly interaction where tapping a player card opens a destination picker (bottom sheet or modal) listing available teams, Not Participating, and Unassigned.

#### Scenario: Tap player card on mobile
- **WHEN** a user taps a player card on a mobile-sized screen
- **THEN** a bottom sheet appears listing all available destinations in this context

#### Scenario: Select destination from bottom sheet
- **WHEN** a user selects a destination from the bottom sheet
- **THEN** the player is moved to that destination and the bottom sheet closes

### Requirement: Planning board syncs in real time across sessions
The system SHALL broadcast membership and team changes to all clients subscribed to the same planning context topic via `Ash.Notifier.PubSub`. All connected sessions SHALL reflect the updated board state within a short time of a change being made. Notifications are emitted automatically by the Ash resource lifecycle; the LiveView SHALL NOT manually broadcast changes.

#### Scenario: Second session sees move made in first session
- **WHEN** two browser sessions are open on the same planning context
- **AND** a player is moved in session A
- **THEN** the board in session B updates to reflect the move without a page refresh

### Requirement: Health indicators surface rule violations non-blockingly
The system SHALL display visual health indicators on teams and player cards when roster rules are violated. Violations SHALL NOT prevent any action — they are informational only.

#### Scenario: Team is below minimum roster size
- **WHEN** a team has fewer players than the SeasonRules min_roster
- **THEN** the team column displays a warning indicator showing the shortfall

#### Scenario: Team is above maximum roster size
- **WHEN** a team has more players than the SeasonRules max_roster
- **THEN** the team column displays a warning indicator showing the excess

#### Scenario: Team on-level percentage is below minimum
- **WHEN** fewer than on_level_min_pct of a team's players are rated at the team's top NTRP level
- **THEN** the team column displays a warning indicator

#### Scenario: Player NTRP rating is not in allowed levels
- **WHEN** a player assigned to a team has an NTRP rating not in the team type's allowed_ntrp_levels
- **THEN** the player card displays a warning indicator

#### Scenario: Player has no NTRP rating (unrated)
- **WHEN** a player with a nil NTRP rating is assigned to a team
- **THEN** the player card displays a caution indicator (not an error) noting the rating is unknown
- **AND** the player is NOT counted as on-level for percentage calculations

#### Scenario: No SeasonRules exist for the context
- **WHEN** no SeasonRules record exists for the current (team_type, season_year)
- **THEN** no rule-based health warnings are shown on the board

### Requirement: New teams can be created from the planning board
The system SHALL allow users to add a new team to the current planning context via a modal form. The modal SHALL display validation errors if the team name is blank.

#### Scenario: Create new team from board
- **WHEN** a user clicks "New Team" on the planning board
- **THEN** a modal opens with a name input field
- **AND** upon valid submission, a new team column appears on the board and the modal closes

#### Scenario: Create team with blank name shows error
- **WHEN** a user submits the new team modal with a blank name
- **THEN** a validation error is shown on the name field
- **AND** no team is created
- **AND** the modal remains open

### Requirement: Roster planner write operations require group owner role
All write operations on the planning board (moving players, creating teams, deleting teams, renaming teams) SHALL require the acting user to hold a `GroupMembership.role == :owner` for the current group, or be a system admin. Group members with role `:member` SHALL have read-only access to the planning board.

#### Scenario: Group owner can move a player on the planning board
- **WHEN** a user with GroupMembership :owner drags a player to a different column
- **THEN** the player's TeamMembership is updated

#### Scenario: Group member sees the board but cannot drag players
- **WHEN** a user with GroupMembership :member views the planning board
- **THEN** the board is displayed with player cards and columns
- **AND** drag-and-drop and tap-to-assign interactions are disabled or produce no changes

#### Scenario: Group member cannot create a team from the board
- **WHEN** a user with GroupMembership :member attempts to create a team via the board
- **THEN** the action is denied (button hidden or action rejected)

### Requirement: Planning board state persists across sessions
The system SHALL persist all roster assignments so that returning to the same planning context shows the same board state as when the user left.

#### Scenario: Reload planning board
- **WHEN** a user navigates away from the planning board and returns
- **THEN** all team assignments are intact as previously saved
