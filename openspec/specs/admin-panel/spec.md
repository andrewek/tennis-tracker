## Requirements

### Requirement: Admin panel is accessible only to users with role :admin
The admin panel at `/admin` SHALL require authentication. Authenticated users with role `:member` SHALL be denied access. Unauthenticated users SHALL be redirected to the login page.

#### Scenario: Admin user can access the panel
- **WHEN** a user with role `:admin` navigates to `/admin`
- **THEN** the admin panel SHALL be displayed

#### Scenario: Member user is denied access
- **WHEN** a user with role `:member` navigates to `/admin`
- **THEN** the user SHALL be denied access (redirected or shown an error)

#### Scenario: Unauthenticated user is redirected to login
- **WHEN** an unauthenticated user navigates to `/admin`
- **THEN** the user SHALL be redirected to the login page

### Requirement: Admin panel surfaces all Ash resources for inspection and management
The admin panel SHALL expose all resources across the `TennisTracker.Accounts` and `TennisTracker.Tennis` domains. Each resource SHALL support at minimum read access.

#### Scenario: All resources visible in admin panel
- **WHEN** an admin user navigates to `/admin`
- **THEN** links or sections for User, Player, TeamType, Team, TeamMembership, and SeasonRules SHALL be present

### Requirement: Admin panel supports full CRUD for Player, Team, and User
The admin panel SHALL allow creating, reading, updating, and destroying records for `Player`, `Team`, and `User`.

#### Scenario: Admin can create a Player from the panel
- **WHEN** an admin submits a valid new player form in the admin panel
- **THEN** a Player record SHALL be created

#### Scenario: Admin can update a Player from the panel
- **WHEN** an admin edits and saves a Player record in the admin panel
- **THEN** the Player record SHALL be updated

#### Scenario: Admin can destroy a Player from the panel
- **WHEN** an admin deletes a Player record in the admin panel
- **THEN** the Player record SHALL be removed

### Requirement: Admin panel supports full CRUD for TeamType and SeasonRules
The admin panel SHALL allow creating, reading, updating, and destroying `TeamType` and `SeasonRules` records.

#### Scenario: Admin can update a TeamType from the panel
- **WHEN** an admin edits and saves a TeamType record in the admin panel
- **THEN** the TeamType record SHALL be updated

#### Scenario: Admin can destroy a TeamType from the panel
- **WHEN** an admin deletes a TeamType record in the admin panel
- **THEN** the TeamType record SHALL be removed

#### Scenario: Admin can destroy a SeasonRules record from the panel
- **WHEN** an admin deletes a SeasonRules record in the admin panel
- **THEN** the SeasonRules record SHALL be removed

### Requirement: Admin panel restricts TeamMembership to read and destroy only
The admin panel SHALL allow reading and destroying `TeamMembership` records. Creating and updating TeamMembership records SHALL NOT be available through the admin panel.

#### Scenario: Admin can view TeamMembership records
- **WHEN** an admin navigates to the TeamMembership section in the admin panel
- **THEN** existing membership records SHALL be listed

#### Scenario: Admin can destroy a TeamMembership from the panel
- **WHEN** an admin deletes a TeamMembership record in the admin panel
- **THEN** the membership record SHALL be removed

#### Scenario: No create or update actions available for TeamMembership in admin
- **WHEN** an admin views the TeamMembership section in the admin panel
- **THEN** no form or button to create or update a membership SHALL be present
