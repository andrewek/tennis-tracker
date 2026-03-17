## MODIFIED Requirements

### Requirement: User can select a planning context
The system SHALL provide a way for users to select a planning context (season year + team type) before viewing the planning board. The selection SHALL be surfaced at `/g/:group_slug/roster-planner`.

#### Scenario: Selecting a context loads the planning board
- **WHEN** a user selects a season year and team type from the context selector
- **THEN** the planning board for that context is displayed

#### Scenario: Context selector lists available team types
- **WHEN** the context selector is displayed
- **THEN** all TeamTypes for the current group are listed as options

## ADDED Requirements

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
