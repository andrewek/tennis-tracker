## ADDED Requirements

### Requirement: Player records are scoped to a group
`Player` records SHALL be tenant-scoped by `group_id`. Players from one group SHALL NOT be visible to users in another group. A player who appears in two groups is represented by two separate records with no link between them.

#### Scenario: Players list shows only players for the current group
- **WHEN** a user views the players index at `/g/:group_slug/players`
- **THEN** only Player records belonging to that group are displayed

#### Scenario: Players from other groups are not returned
- **WHEN** the players index is loaded for group A
- **THEN** no players belonging to group B appear

### Requirement: Group members can add and edit players
Any user with a `GroupMembership` for the current group (role `:owner` or `:member`, or system admin) SHALL be permitted to create and update `Player` records within that group. This covers the main player roster only — assigning players to team rosters (TeamMembership) is a separate action governed by its own access rules.

#### Scenario: Group member can add a player
- **WHEN** a user with GroupMembership :member creates a new Player record
- **THEN** the Player is created successfully within the group

#### Scenario: Group member can edit a player
- **WHEN** a user with GroupMembership :member updates a Player record's name or NTRP rating
- **THEN** the Player record is updated

#### Scenario: Group member cannot assign a player to a team roster
- **WHEN** a user with GroupMembership :member (no :owner or :captain role) attempts to create a TeamMembership
- **THEN** the action is denied

### Requirement: Players index page is accessible at a group-scoped URL
The players index page SHALL be accessible at `/g/:group_slug/players`.

#### Scenario: Players index loads at group-scoped URL
- **WHEN** a group member navigates to `/g/:group_slug/players`
- **THEN** the player list for that group is displayed
