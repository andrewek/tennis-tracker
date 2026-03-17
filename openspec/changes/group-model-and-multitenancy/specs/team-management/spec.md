## ADDED Requirements

### Requirement: Team creation requires group owner role
Only users with a `GroupMembership.role == :owner` for the current group (or system admins) SHALL be permitted to create `Team` records. Group members and team captains SHALL NOT be able to create teams.

#### Scenario: Group owner can create a team
- **WHEN** a user with GroupMembership :owner creates a team within their group
- **THEN** the team is created successfully

#### Scenario: Group member cannot create a team
- **WHEN** a user with GroupMembership :member (and no :owner role) attempts to create a team
- **THEN** the action is denied

### Requirement: Team deletion requires group owner role
Only users with a `GroupMembership.role == :owner` for the current group (or system admins) SHALL be permitted to delete `Team` records.

#### Scenario: Group owner can delete a team
- **WHEN** a user with GroupMembership :owner deletes a team
- **THEN** the team and its memberships are removed

#### Scenario: Team captain cannot delete a team they captain
- **WHEN** a user with only a TeamRole :captain for a team attempts to delete it
- **THEN** the action is denied

### Requirement: Team rename requires group owner or team captain role
Users with GroupMembership :owner OR a TeamRole :captain for the specific team (or system admins) SHALL be permitted to rename a `Team`.

#### Scenario: Group owner can rename any team
- **WHEN** a user with GroupMembership :owner renames a team
- **THEN** the team name is updated

#### Scenario: Captain can rename their own team
- **WHEN** a user with TeamRole :captain for Team A renames Team A
- **THEN** the team name is updated

#### Scenario: Captain cannot rename another captain's team
- **WHEN** a user with TeamRole :captain only for Team A attempts to rename Team B
- **THEN** the action is denied
