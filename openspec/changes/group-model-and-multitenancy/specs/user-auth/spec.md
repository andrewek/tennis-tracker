## ADDED Requirements

### Requirement: System admins bypass all Ash authorization policies
A `User` with `role == :admin` SHALL bypass all Ash authorization policies on all resources via an Ash `bypass` policy block. This applies to both Accounts, Groups, and Tennis domain resources.

#### Scenario: System admin can read any resource without other role checks
- **WHEN** a user with role :admin calls any Ash read action as the actor
- **THEN** the action succeeds regardless of GroupMembership or TeamRole

#### Scenario: System admin can write any resource without other role checks
- **WHEN** a user with role :admin calls any Ash create/update/destroy action as the actor
- **THEN** the action succeeds regardless of GroupMembership or TeamRole

### Requirement: Permission is granted if any applicable role permits the action
Authorization SHALL use OR logic across all three axes (system admin, group role, team role). If a user holds multiple roles and ANY of them grants the requested action, the action is permitted.

#### Scenario: Group owner who also captains a team gets both permission sets
- **WHEN** a user with GroupMembership :owner also has a TeamRole :captain for a specific team
- **THEN** the user can perform both group owner actions and team captain actions

#### Scenario: System admin who is also a group member gets admin permissions
- **WHEN** a user with role :admin is also a GroupMembership :member for a group
- **THEN** the system admin permissions apply (broader), not just member permissions

### Requirement: Unauthorized action buttons are not rendered
If the current user does not have permission to perform an action, the UI element that triggers that action (button, link, form) SHALL NOT be rendered. Users SHALL NOT see controls for actions they cannot perform.

#### Scenario: Group member does not see team creation button
- **WHEN** a user with GroupMembership :member views the teams index page
- **THEN** no "New Team" button or link is visible

#### Scenario: Non-captain does not see match edit button for another team
- **WHEN** a user without a :captain TeamRole for Team A views Team A's schedule
- **THEN** no "Edit" or "Delete" button is visible for matches on that team

#### Scenario: Group owner sees all management controls
- **WHEN** a user with GroupMembership :owner views the teams index
- **THEN** team creation, edit, and delete controls are visible

### Requirement: Direct navigation to unauthorized forms redirects the user
If a user navigates directly to a URL for an action they are not permitted to perform (e.g., a team edit form), the LiveView SHALL redirect them rather than render the form.

#### Scenario: Non-captain navigates directly to team edit URL
- **WHEN** a user without :captain or :owner role navigates directly to `/g/:group_slug/teams/:id/edit`
- **THEN** the user is redirected (e.g., to the team show page or group home)

#### Scenario: Unauthorized Ash action is rejected even without UI
- **WHEN** an unauthorized user attempts an Ash write action directly (e.g., via API or form manipulation)
- **THEN** the Ash policy rejects the action regardless of UI state
