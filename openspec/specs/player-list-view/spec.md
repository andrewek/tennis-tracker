## Requirements

### Requirement: Players list displays age brackets as inline chips
The players index table SHALL display each player's age bracket eligibility as inline badge chips next to the player's name, rather than as separate columns.

#### Scenario: Eligible player shows bracket chips
- **WHEN** a player is eligible for one or more age brackets (18+, 40+, 55+)
- **THEN** the corresponding bracket labels SHALL be displayed as small badge chips in the same cell as the player's name

#### Scenario: No bracket columns in table
- **WHEN** the players index page is rendered
- **THEN** the table SHALL NOT have columns labeled "18+ Eligible?", "40+ Eligible?", or "55+ Eligible?"

#### Scenario: Player with no brackets shows no chips
- **WHEN** a player is not eligible for any age bracket
- **THEN** no age bracket chips SHALL be displayed for that player

### Requirement: Players list is sorted by NTRP then name by default
The players index SHALL display players sorted by NTRP rating descending by default, then by name ascending. The user MAY toggle the NTRP sort direction between ascending and descending using a control on the page. Only the NTRP column supports sort direction toggling. Unrated players (no NTRP rating) SHALL always appear after all rated players when sorted descending, and before all rated players when sorted ascending.

#### Scenario: Default sort order applied
- **WHEN** the players index page is loaded without any sort parameters
- **THEN** players SHALL be ordered with higher NTRP ratings first (descending), and players with the same rating ordered alphabetically by name ascending, and unrated players SHALL appear below all rated players

#### Scenario: User toggles NTRP sort to ascending
- **WHEN** the user activates the NTRP sort direction toggle
- **THEN** players SHALL be ordered with lower NTRP ratings first (ascending), and players with the same rating ordered alphabetically by name ascending, and unrated players SHALL appear above all rated players

#### Scenario: User toggles NTRP sort back to descending
- **WHEN** the NTRP sort direction is ascending and the user activates the toggle again
- **THEN** players SHALL revert to descending NTRP order with unrated players at the bottom

#### Scenario: Sort direction preserved with filters
- **WHEN** the players index page is loaded with name, NTRP, or bracket filter parameters and a sort direction parameter
- **THEN** the filtered results SHALL be sorted according to the selected NTRP sort direction, then name ascending, with unrated players positioned according to the selected direction

### Requirement: Players list NTRP filter includes "No rating" option
The NTRP filter on the players index page SHALL include a "No rating" checkbox that, when selected, includes players with no NTRP rating assigned in the results.

#### Scenario: "No rating" checkbox visible
- **WHEN** the players index page is rendered
- **THEN** a "No rating" checkbox SHALL appear alongside the standard NTRP rating checkboxes

#### Scenario: Filter by no rating only
- **WHEN** only the "No rating" checkbox is checked
- **THEN** only players with no NTRP rating SHALL be shown

#### Scenario: Filter by no rating combined with rated values
- **WHEN** "No rating" and one or more rated NTRP values are checked
- **THEN** players matching any of the selected NTRP values OR having no rating SHALL be shown

#### Scenario: Unrated players excluded without "No rating" filter
- **WHEN** one or more NTRP rating checkboxes are checked but "No rating" is not checked
- **THEN** players with no NTRP rating SHALL NOT appear in the results

#### Scenario: Clear filters resets "No rating" selection
- **WHEN** the user clicks "Clear filters"
- **THEN** the "No rating" checkbox SHALL be unchecked and unrated players SHALL appear only based on the default (no filter)

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
