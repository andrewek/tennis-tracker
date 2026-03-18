## ADDED Requirements

### Requirement: All Tennis domain resources are scoped by group_id
Every resource in the `TennisTracker.Tennis` domain (Player, Team, TeamType, TeamMembership, TeamRole, Match, Location, SeasonRules) SHALL have a `group_id` attribute (UUID, non-nullable) configured as the AshMultitenancy attribute. Ash SHALL enforce that all queries against these resources include a tenant context.

#### Scenario: Reading a Tennis resource without a tenant raises an error
- **WHEN** an Ash read action is called on a tenanted Tennis resource without passing `tenant:` option
- **THEN** Ash raises an error (not a silent full-table scan)

#### Scenario: Records from group A are not visible when querying as group B
- **WHEN** a Player record is created under group A
- **AND** a read action is performed with tenant set to group B's id
- **THEN** the Player record from group A is NOT returned

#### Scenario: Records are visible when querying with the correct tenant
- **WHEN** a Player record is created under group A
- **AND** a read action is performed with tenant set to group A's id
- **THEN** the Player record is returned

### Requirement: Location unique constraint is scoped to group
The `Location` resource's unique constraint on `name` SHALL be `[:group_id, :name]` rather than `[:name]` alone. Two Groups MAY each have a Location with the same name.

#### Scenario: Same location name in different groups is allowed
- **WHEN** two Location records are created with the same name but different group_id values
- **THEN** both records are saved successfully

#### Scenario: Duplicate location name within a group is rejected
- **WHEN** a second Location is created with the same name and same group_id as an existing Location
- **THEN** a uniqueness error is returned

### Requirement: System admins bypass tenant scoping in the Admin panel
Ash resources accessed via the Admin panel by a system admin (User.role == :admin) SHALL NOT be restricted by tenant. The system admin SHALL see data across all Groups.

#### Scenario: System admin sees all groups' data in admin panel
- **WHEN** a system admin navigates to a tenanted resource in the Admin panel (e.g., Players)
- **THEN** records from all Groups are visible

#### Scenario: Non-admin user cannot access admin panel
- **WHEN** a user with role :member attempts to navigate to /admin
- **THEN** they are denied access (existing behavior, unchanged)
