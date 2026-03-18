## MODIFIED Requirements

### Requirement: Matches can be created for a team
The system SHALL expose a `create_match/1` domain function (via `AshPhoenix.Form`) that creates a match associated with a team. Only users with a `TeamRole.role == :captain` for the team, a `GroupMembership.role == :owner` for the group, or system admin role SHALL be permitted to create matches.

#### Scenario: Team captain creates a match for their team
- **WHEN** a user with TeamRole :captain for Team A submits a valid match creation form for Team A
- **THEN** a new Match record is created associated with Team A

#### Scenario: Group member without captain role cannot create a match
- **WHEN** a user with GroupMembership :member and no TeamRole :captain attempts to create a match
- **THEN** the action is denied

#### Scenario: Group owner can create a match for any team
- **WHEN** a user with GroupMembership :owner creates a match for any team in the group
- **THEN** the match is created successfully

#### Scenario: Invalid match creation is rejected
- **WHEN** an authorized user submits a match creation form with missing required fields
- **THEN** form errors are displayed and no match is created

### Requirement: Matches can be updated and deleted only by authorized users
Updating or deleting a `Match` record SHALL require the acting user to hold a `TeamRole.role == :captain` for the match's team, or a `GroupMembership.role == :owner`, or system admin role.

#### Scenario: Captain can update a match for their team
- **WHEN** a user with TeamRole :captain for Team A updates a match belonging to Team A
- **THEN** the match is updated successfully

#### Scenario: Captain cannot update a match for another team
- **WHEN** a user with TeamRole :captain only for Team A attempts to update a match belonging to Team B
- **THEN** the action is denied

### Requirement: Match show page is accessible at a group-scoped URL
The match show page SHALL be accessible at `/g/:group_slug/matches/:id`. The back-link to the team SHALL navigate to `/g/:group_slug/teams/:team_id`.

#### Scenario: User views match detail at group-scoped URL
- **WHEN** an authenticated group member navigates to `/g/:group_slug/matches/:id`
- **THEN** the match detail page is displayed

#### Scenario: Back-link navigates to group-scoped team page
- **WHEN** a user is on the match show page
- **THEN** the team back-link points to `/g/:group_slug/teams/:team_id`
