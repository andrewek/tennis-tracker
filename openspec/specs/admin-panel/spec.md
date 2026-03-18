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
The admin panel SHALL expose all resources across the `TennisTracker.Accounts` and `TennisTracker.Tennis` domains. Each resource SHALL support at minimum read access. The resource list SHALL include the Group, GroupMembership, and TeamRole resources.

#### Scenario: All resources visible in admin panel
- **WHEN** an admin user navigates to `/admin`
- **THEN** links or sections for User, Group, GroupMembership, Player, TeamType, Team, TeamMembership, TeamRole, SeasonRules, Location, and Match SHALL be present

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

### Requirement: Admin panel supports full CRUD for Location
The admin panel SHALL allow creating, reading, updating, and destroying `Location` records.

#### Scenario: Admin can create a Location from the panel
- **WHEN** an admin submits a valid new location form in the admin panel
- **THEN** a Location record SHALL be created

#### Scenario: Admin can read Location records from the panel
- **WHEN** an admin navigates to the Location section in the admin panel
- **THEN** existing Location records SHALL be listed

#### Scenario: Admin can update a Location from the panel
- **WHEN** an admin edits and saves a Location record in the admin panel
- **THEN** the Location record SHALL be updated

#### Scenario: Admin can destroy a Location from the panel
- **WHEN** an admin deletes a Location record in the admin panel
- **THEN** the Location record SHALL be removed

### Requirement: Admin panel bypasses tenant scoping for all tenanted resources
When a system admin accesses tenanted Tennis domain resources via the Admin panel, all records across all Groups SHALL be visible. The admin panel SHALL NOT apply `group_id` filtering. This is implemented via Ash `bypass` policy on the system admin actor.

#### Scenario: System admin sees players from all groups in admin panel
- **WHEN** a system admin navigates to the Player section in the admin panel
- **THEN** Player records from all groups are listed

#### Scenario: System admin sees all groups in admin panel
- **WHEN** a system admin navigates to the Group section in the admin panel
- **THEN** all Group records are listed

### Requirement: Admin panel tenant bypass is manually verified after each resource configuration
After adding or changing admin configuration for any tenanted resource, a developer SHALL manually verify that: (1) system admin sees cross-tenant data, and (2) non-admin users cannot access the admin panel (existing gate unchanged). This verification requirement SHALL be documented in CLAUDE.md.

#### Scenario: Post-configuration verification — system admin cross-tenant read
- **WHEN** a developer has configured admin panel access for a tenanted resource
- **THEN** they SHALL verify by logging in as a system admin and confirming records from multiple groups appear

#### Scenario: Post-configuration verification — non-admin is still denied
- **WHEN** a developer has configured admin panel access for a tenanted resource
- **THEN** they SHALL verify by confirming a :member user cannot reach /admin

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
