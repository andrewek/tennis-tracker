## ADDED Requirements

### Requirement: /groups page lists all groups the current user belongs to
The system SHALL provide a `/groups` page accessible to all authenticated users. It SHALL display all Groups the current user has a GroupMembership for, rendered as a card layout sorted alphabetically by group name. This page serves as the primary entry point after login.

#### Scenario: User with multiple groups sees all their groups
- **WHEN** an authenticated user navigates to `/groups`
- **THEN** all Groups they have a GroupMembership for are displayed as cards

#### Scenario: Cards are sorted alphabetically by name
- **WHEN** a user with memberships in groups named "Zebra Tennis" and "Alpha Tennis" views /groups
- **THEN** "Alpha Tennis" appears before "Zebra Tennis"

#### Scenario: User with no groups sees a helpful empty state
- **WHEN** an authenticated user has no GroupMemberships
- **THEN** an empty state message is displayed explaining that they are not yet a member of any group and that a system administrator can add them

#### Scenario: System admin sees all groups
- **WHEN** a system admin navigates to /groups
- **THEN** all Group records in the system are displayed (not just groups they have a membership in)

### Requirement: / and post-login redirect to the appropriate group destination
The root route `/` SHALL redirect authenticated users based on how many groups they belong to:
- If the user belongs to exactly one group, redirect to `/g/:group_slug/`
- If the user belongs to zero or more than one group, redirect to `/groups`

The same logic SHALL apply immediately after a successful sign-in (the post-login destination). Unauthenticated users navigating to `/` SHALL be redirected to the login page.

#### Scenario: Authenticated single-group user visiting / is sent directly to their group
- **WHEN** an authenticated user with exactly one GroupMembership navigates to `/`
- **THEN** they are redirected to `/g/:group_slug/` for their group

#### Scenario: Authenticated multi-group user visiting / is sent to /groups
- **WHEN** an authenticated user with two or more GroupMemberships navigates to `/`
- **THEN** they are redirected to `/groups`

#### Scenario: Authenticated user with no groups visiting / is sent to /groups
- **WHEN** an authenticated user with no GroupMemberships navigates to `/`
- **THEN** they are redirected to `/groups`

#### Scenario: Post-login single-group redirect
- **WHEN** a user signs in and they belong to exactly one group
- **THEN** they are deposited at `/g/:group_slug/`

#### Scenario: Post-login multi-group redirect
- **WHEN** a user signs in and they belong to zero or more than one group
- **THEN** they are deposited at `/groups`

### Requirement: All Tennis routes are scoped under /g/:group_slug
Every LiveView route for Tennis domain data SHALL be nested under `/g/:group_slug/`. The group slug is a human-readable string (e.g., `my-tennis-group`). The previous flat routes (e.g., `/teams`, `/players`) SHALL no longer exist. Navigating to `/g/:group_slug/` SHALL display that group's home page (equivalent to the current home page).

#### Scenario: Teams index is accessible at group-slug URL
- **WHEN** a user navigates to `/g/:group_slug/teams`
- **THEN** the teams index page is displayed scoped to that group

#### Scenario: Group home page renders at /g/:group_slug/
- **WHEN** a user navigates to `/g/:group_slug/`
- **THEN** the group's home page is displayed

#### Scenario: Old flat routes are not accessible
- **WHEN** a user navigates to `/teams` (without group slug prefix)
- **THEN** a 404 or redirect is returned

#### Scenario: /groups route takes precedence over /g/:group_slug dynamic segment
- **WHEN** a user navigates to `/groups`
- **THEN** the groups listing page is shown (not a group with slug "groups")

### Requirement: LiveView mounts resolve group by slug and verify membership
Every group-scoped LiveView SHALL look up the Group by `slug` from URL params on mount, then verify the current user has a GroupMembership for that group. If the group does not exist or the user is not a member, they SHALL be redirected.

#### Scenario: Valid member accesses a group-scoped page
- **WHEN** an authenticated user with a GroupMembership for group with slug "my-group" navigates to `/g/my-group/teams`
- **THEN** the page renders successfully

#### Scenario: Non-member is redirected
- **WHEN** an authenticated user without a GroupMembership for "other-group" navigates to `/other-group/teams`
- **THEN** the user is redirected

#### Scenario: Non-existent slug is handled gracefully
- **WHEN** a user navigates to `/no-such-slug/teams`
- **THEN** the user is redirected or shown a 404

#### Scenario: System admin can access any group's pages
- **WHEN** a user with role :admin navigates to `/:any_slug/teams`
- **THEN** the page renders regardless of GroupMembership

### Requirement: Current group context is passed as tenant to all Ash calls
Within every group-scoped LiveView, the Group is resolved once at mount by slug and stored in socket assigns (`current_group` and `current_group_id`). All calls to the Tennis domain SHALL pass `tenant: current_group_id`.

#### Scenario: Ash calls use the group's id as tenant
- **WHEN** a LiveView mounts for a group with a given slug
- **THEN** all subsequent Ash queries are scoped to that group's id
