## Requirements

### Requirement: TeamRole resource links users to teams with a role
The system SHALL provide a `TeamRole` Ash resource in the `TennisTracker.Tennis` domain with `user_id` (belongs_to User, non-nullable), `team_id` (belongs_to Team, non-nullable), `group_id` (tenant attribute, non-nullable), and `role` (atom, allowed values `:captain` and `:member`, non-nullable). The combination of `(user_id, team_id)` SHALL be unique.

#### Scenario: TeamRole can be created with role :captain
- **WHEN** a TeamRole record is created with a valid user_id, team_id, group_id, and role :captain
- **THEN** the record is saved successfully

#### Scenario: TeamRole can be created with role :member
- **WHEN** a TeamRole record is created with a valid user_id, team_id, group_id, and role :member
- **THEN** the record is saved successfully

#### Scenario: A user can have roles on multiple teams
- **WHEN** a User has TeamRole records for two different Teams
- **THEN** both records exist and are valid

#### Scenario: A user cannot have two TeamRole records for the same team
- **WHEN** a second TeamRole is created with the same user_id and team_id as an existing record
- **THEN** a uniqueness error is returned

#### Scenario: Invalid role value is rejected
- **WHEN** a TeamRole is created with a role value outside [:captain, :member]
- **THEN** a validation error is returned

### Requirement: Team captains can edit their own teams
A user with a TeamRole of `:captain` for a given Team SHALL be permitted to create, update, and delete Match records for that team. A captain SHALL NOT be permitted to create, update, or delete Match records for teams where they do not hold a :captain TeamRole (unless a broader role like group :owner also grants access).

#### Scenario: Captain can create a match for their team
- **WHEN** a user with a :captain TeamRole for Team A creates a match for Team A
- **THEN** the match is created successfully

#### Scenario: Captain cannot create a match for another team
- **WHEN** a user with a :captain TeamRole only for Team A attempts to create a match for Team B
- **THEN** the action is denied

### Requirement: TeamRole :member grants read-only access to team lineup and schedule
A user with a TeamRole of `:member` for a given Team SHALL be able to read Match records and (when implemented) lineup records for that specific team. This access is in addition to whatever group-level access the user holds.

#### Scenario: TeamRole member can read matches for their team
- **WHEN** a user with a :member TeamRole for Team A reads matches for Team A
- **THEN** the matches are returned

#### Scenario: TeamRole member cannot edit matches for their team
- **WHEN** a user with a :member TeamRole for Team A (but no :captain role and no group :owner role) attempts to update a match for Team A
- **THEN** the action is denied

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
