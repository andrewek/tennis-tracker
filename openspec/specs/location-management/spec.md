## Requirements

### Requirement: Group Settings nav section is visible only to group owners and system admins
The sidebar SHALL render a "Group Settings" collapsible navigation section only when `current_group_role` is `:owner` or `:admin`. Users with `GroupMembership.role == :member` SHALL NOT see the section at all.

#### Scenario: Group owner sees Group Settings nav section
- **WHEN** a user with GroupMembership :owner views any group-scoped page
- **THEN** the sidebar shows a "Group Settings" collapsible section containing a "Locations" link

#### Scenario: System admin sees Group Settings nav section
- **WHEN** a system admin (user.role == :admin) views any group-scoped page
- **THEN** the sidebar shows a "Group Settings" collapsible section

#### Scenario: Group member does not see Group Settings nav section
- **WHEN** a user with GroupMembership :member views any group-scoped page
- **THEN** the sidebar does not contain a "Group Settings" section

### Requirement: Non-owners are redirected from settings routes
Any user with `current_group_role == :member` who navigates directly to a `/g/:group_slug/settings/*` URL SHALL be redirected to the group home page. Group owners and system admins SHALL not be redirected.

#### Scenario: Non-owner navigates directly to settings URL
- **WHEN** a user with GroupMembership :member navigates to `/g/:group_slug/settings/locations`
- **THEN** they are redirected to the group home page

#### Scenario: Group owner can access settings routes
- **WHEN** a user with GroupMembership :owner navigates to `/g/:group_slug/settings/locations`
- **THEN** the page renders successfully

#### Scenario: System admin can access settings routes
- **WHEN** a system admin navigates to `/g/:group_slug/settings/locations`
- **THEN** the page renders successfully

### Requirement: Location index page uses tabs to separate active and archived locations
The `/g/:group_slug/settings/locations` page SHALL display two tabs: "Active" and "Archived". The Active tab SHALL list all non-archived locations sorted alphabetically, each with Edit and Archive action buttons. The Archived tab SHALL list all archived locations sorted alphabetically, each with a Restore button. The page is accessible only to group owners and system admins.

#### Scenario: Active tab shows active locations with controls
- **WHEN** a group owner views the Active tab on the locations index
- **THEN** each active location is listed with its name and action buttons for Edit and Archive

#### Scenario: Archived tab shows archived locations with Restore control
- **WHEN** a group owner views the Archived tab and at least one location is archived
- **THEN** each archived location is listed with a Restore button

#### Scenario: Empty state on Active tab when no active locations exist
- **WHEN** a group owner views the Active tab and no active locations exist
- **THEN** a helpful empty state message is shown with a prompt to create the first location

#### Scenario: Empty state on Archived tab when no archived locations exist
- **WHEN** a group owner views the Archived tab and no locations have been archived
- **THEN** a message indicates there are no archived locations

### Requirement: Archive action requires confirmation
Clicking Archive on a location SHALL display a confirmation modal. The location SHALL only be archived if the user confirms. Canceling SHALL dismiss the modal and leave the location unchanged.

#### Scenario: Owner confirms archival
- **WHEN** a group owner clicks Archive on an active location and confirms the modal
- **THEN** the location is archived and no longer appears in the active section

#### Scenario: Owner cancels archival
- **WHEN** a group owner clicks Archive on an active location and cancels the modal
- **THEN** the location remains active and the modal closes

### Requirement: Restore action requires confirmation
Clicking Restore on an archived location SHALL display a confirmation modal. The location SHALL only be restored if the user confirms. Canceling SHALL dismiss the modal and leave the location archived.

#### Scenario: Owner confirms restore
- **WHEN** a group owner clicks Restore on an archived location and confirms the modal
- **THEN** the location is restored to active and appears in the active section

#### Scenario: Owner cancels restore
- **WHEN** a group owner clicks Restore on an archived location and cancels the modal
- **THEN** the location remains archived and the modal closes

### Requirement: Create location form allows group owners to add new venues
The `/g/:group_slug/settings/locations/new` page SHALL provide a form for creating a location with fields: name (required), street_address (optional), city (optional), state (optional), postal_code (optional), google_maps_url (optional). On success, redirect to the index page. On duplicate name, display a validation error.

#### Scenario: Successful location creation with name only
- **WHEN** a group owner submits the create form with only a unique name
- **THEN** the location is created and the user is redirected to the locations index

#### Scenario: Successful location creation with all fields
- **WHEN** a group owner submits the create form with a unique name and address fields
- **THEN** the location is created and the user is redirected to the locations index

#### Scenario: Duplicate name within the same group is rejected
- **WHEN** a group owner submits the create form with a name that already exists in the group
- **THEN** a validation error is shown and no location is created

#### Scenario: Missing name is rejected
- **WHEN** a group owner submits the create form without a name
- **THEN** a validation error is shown and no location is created

### Requirement: Edit location form allows group owners to update venue details
The `/g/:group_slug/settings/locations/:id/edit` page SHALL provide a pre-populated form for updating a location's name, street_address, city, state, postal_code, and google_maps_url. On success, redirect to the index page.

#### Scenario: Successful location update
- **WHEN** a group owner submits the edit form with valid changes
- **THEN** the location is updated and the user is redirected to the locations index

#### Scenario: Updating to a duplicate name is rejected
- **WHEN** a group owner submits the edit form with a name already used by another location in the group
- **THEN** a validation error is shown and the location is not updated
