## Requirements

### Requirement: Users can authenticate with email and password
The system SHALL support email/password authentication via AshAuthentication. Unauthenticated users SHALL be redirected to the login page when accessing protected routes.

#### Scenario: Valid login redirects to home
- **WHEN** a user submits valid credentials on the login page
- **THEN** the user SHALL be authenticated and redirected to the home page

#### Scenario: Invalid credentials show an error
- **WHEN** a user submits an incorrect email or password
- **THEN** an error message SHALL be shown and the user SHALL remain on the login page

#### Scenario: Unauthenticated access to protected route redirects to login
- **WHEN** an unauthenticated user navigates to a protected route (e.g., `/admin`)
- **THEN** the user SHALL be redirected to the login page

### Requirement: User records have a role attribute
Every `User` record SHALL have a `role` attribute with allowed values `:admin` and `:member`. New users SHALL default to `:member`.

#### Scenario: New user defaults to :member role
- **WHEN** a new User record is created without specifying a role
- **THEN** the user's role SHALL be `:member`

#### Scenario: Role can be set to :admin
- **WHEN** a User record is created or updated with role `:admin`
- **THEN** the record SHALL be saved successfully with role `:admin`

#### Scenario: Invalid role value is rejected
- **WHEN** an attempt is made to set a role value outside `[:admin, :member]`
- **THEN** a validation error SHALL be returned

### Requirement: Dev seeds create an admin user and a member user
The seed script SHALL create two users for local development: one with role `:admin` and one with role `:member`.

#### Scenario: Seed creates admin@example.com
- **WHEN** the seed script is run
- **THEN** a User record with email `admin@example.com` and role `:admin` SHALL exist

#### Scenario: Seed creates user@example.com
- **WHEN** the seed script is run
- **THEN** a User record with email `user@example.com` and role `:member` SHALL exist

#### Scenario: Seeds are idempotent
- **WHEN** the seed script is run more than once
- **THEN** no duplicate user records SHALL be created

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

### Requirement: User records have an optional name attribute
The `User` resource SHALL have an optional `:name` attribute (string, nullable). No uniqueness constraint applies. When displaying a user's identity anywhere in the UI, the system SHALL use `name` if present and fall back to `email` when `name` is nil or empty.

#### Scenario: User can be created without a name
- **WHEN** a User record is created without providing a name
- **THEN** the record is saved successfully with name nil

#### Scenario: User can be created with a name
- **WHEN** a User record is created with a name value
- **THEN** the record is saved successfully and name is stored

#### Scenario: User name can be updated
- **WHEN** an existing User's name is updated to a new value
- **THEN** the change is persisted

#### Scenario: Display label falls back to email when name is nil
- **WHEN** a User has name nil and is displayed in the UI
- **THEN** the user's email is shown as the display label

#### Scenario: Display label uses name when present
- **WHEN** a User has a non-nil name and is displayed in the UI
- **THEN** the user's name is shown as the display label

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

### Requirement: User can update their email address via a dedicated action
The `User` resource SHALL expose an action that allows an authenticated user to update their own email address. The action SHALL enforce the unique email identity constraint. A policy SHALL restrict this action so that a user can only update their own email.

#### Scenario: User updates email to an unused address
- **WHEN** an authenticated user calls the update email action with a new, unused email address
- **THEN** the user's email SHALL be updated successfully

#### Scenario: Email update fails if address is already taken
- **WHEN** an authenticated user calls the update email action with an email belonging to another user
- **THEN** the action SHALL return a validation error and the email SHALL NOT be updated

### Requirement: Direct navigation to unauthorized forms redirects the user
If a user navigates directly to a URL for an action they are not permitted to perform (e.g., a team edit form), the LiveView SHALL redirect them rather than render the form.

#### Scenario: Non-captain navigates directly to team edit URL
- **WHEN** a user without :captain or :owner role navigates directly to `/g/:group_slug/teams/:id/edit`
- **THEN** the user is redirected (e.g., to the team show page or group home)

#### Scenario: Unauthorized Ash action is rejected even without UI
- **WHEN** an unauthorized user attempts an Ash write action directly (e.g., via API or form manipulation)
- **THEN** the Ash policy rejects the action regardless of UI state

### Requirement: User resource has an :invite action for owner-initiated account creation
The `User` resource SHALL expose an `:invite` action that accepts an `email` and a plaintext `password` argument. The action SHALL hash the password using AshAuthentication's `HashPasswordChange` and create a new User with role `:member`. This action is intended for internal use only and SHALL NOT be accessible to arbitrary actors.

The action SHALL declare no permissive policy (no `authorize_if`). Its inaccessibility to arbitrary actors is enforced by the absence of a passing policy — any call with a real actor and the default `authorize?: true` will be denied. Authorization for who may trigger the invite flow (group owners and system admins) is enforced one layer up, at the `add_member_by_email` domain function, which calls `:invite` with `authorize?: false`.

#### Scenario: :invite creates a user with a hashed password
- **WHEN** the :invite action is called with a valid email and plaintext password
- **THEN** a new User record is created, the password is stored hashed, and the plaintext is not persisted

#### Scenario: :invite fails if email is already taken
- **WHEN** the :invite action is called with an email that matches an existing User
- **THEN** an error is returned and no duplicate user is created

#### Scenario: :invite sets user role to :member
- **WHEN** the :invite action is called
- **THEN** the created user's role is :member
