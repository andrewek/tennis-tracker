## MODIFIED Requirements

### Requirement: Admin panel surfaces all Ash resources for inspection and management
The admin panel SHALL expose all resources across the `TennisTracker.Accounts` and `TennisTracker.Tennis` domains. Each resource SHALL support at minimum read access. The resource list SHALL include the new Group, GroupMembership, and TeamRole resources.

#### Scenario: All resources visible in admin panel
- **WHEN** an admin user navigates to `/admin`
- **THEN** links or sections for User, Group, GroupMembership, Player, TeamType, Team, TeamMembership, TeamRole, SeasonRules, Location, and Match SHALL be present

## ADDED Requirements

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
