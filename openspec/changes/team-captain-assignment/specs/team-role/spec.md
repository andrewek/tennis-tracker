## MODIFIED Requirements

### Requirement: TeamRole read access is granted to any group member
Any authenticated user with a `GroupMembership` for the team's group SHALL be permitted to read `TeamRole` records for that group (scoped by multitenancy). This replaces the previous behavior where read access was limited to group owners and the user whose own record it was.

#### Scenario: Group member can list captains for a team in their group
- **WHEN** a user with any GroupMembership role (`:owner` or `:member`) reads TeamRole records for a team in that group
- **THEN** the records are returned successfully

#### Scenario: User outside the group cannot read TeamRole records
- **WHEN** a user with no GroupMembership for the group attempts to read TeamRole records
- **THEN** the read is denied

### Requirement: TeamRole create is permitted to group owners and team captains
A `GroupMembership :owner` OR a user holding a `:captain` TeamRole for the relevant team SHALL be permitted to create `TeamRole` records. The captain check inspects the `team_id` in the create changeset and verifies the actor has a `:captain` role for that team.

#### Scenario: Group owner can create a TeamRole
- **WHEN** a user with GroupMembership :owner creates a TeamRole for any team in the group
- **THEN** the record is created successfully

#### Scenario: Team captain can create a TeamRole for their team
- **WHEN** a user with a :captain TeamRole for Team A creates a new TeamRole for Team A
- **THEN** the record is created successfully

#### Scenario: Team captain cannot create a TeamRole for a different team
- **WHEN** a user with a :captain TeamRole only for Team A attempts to create a TeamRole for Team B
- **THEN** the action is denied

#### Scenario: Regular group member cannot create a TeamRole
- **WHEN** a user with GroupMembership :member and no captain role attempts to create a TeamRole
- **THEN** the action is denied

### Requirement: TeamRole update and destroy are permitted to group owners and team captains
A `GroupMembership :owner` OR a user holding a `:captain` TeamRole for the same team as the record being modified SHALL be permitted to update or destroy `TeamRole` records.

#### Scenario: Group owner can update any TeamRole
- **WHEN** a user with GroupMembership :owner updates a TeamRole for any team in the group
- **THEN** the update succeeds

#### Scenario: Team captain can update a TeamRole for their team
- **WHEN** a user with a :captain TeamRole for Team A updates any TeamRole record for Team A
- **THEN** the update succeeds

#### Scenario: Team captain can destroy a TeamRole for their team
- **WHEN** a user with a :captain TeamRole for Team A destroys a TeamRole record for Team A
- **THEN** the record is destroyed

#### Scenario: Team captain cannot update a TeamRole for a different team
- **WHEN** a user with a :captain TeamRole only for Team A attempts to update a TeamRole for Team B
- **THEN** the action is denied

#### Scenario: Regular group member cannot update or destroy any TeamRole
- **WHEN** a user with GroupMembership :member and no captain role attempts to update or destroy a TeamRole
- **THEN** the action is denied
