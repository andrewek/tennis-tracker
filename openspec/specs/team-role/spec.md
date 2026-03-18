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
