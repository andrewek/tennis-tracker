## MODIFIED Requirements

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
