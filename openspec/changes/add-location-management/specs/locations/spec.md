## MODIFIED Requirements

### Requirement: Locations resource stores known match venues
The system SHALL provide a `Location` Ash resource with `name`, `address`, and `google_maps_url` attributes. Locations SHALL be scoped to a Group via `group_id` (tenant attribute) and SHALL NOT be shared across groups. The `name` attribute SHALL be unique within a group (unique constraint: `[:group_id, :name]`) and non-nullable. The `address` attribute SHALL be non-nullable. The `google_maps_url` attribute SHALL be optional. Locations SHALL support soft-delete via the `AshArchival.Resource` extension; the `archived_at` field tracks when a location was archived. Locations SHALL NOT be hard-deleted.

#### Scenario: Location has required fields
- **WHEN** a location exists in the database
- **THEN** it has a non-null `name`, `address`, and `group_id`

#### Scenario: Location google_maps_url is optional
- **WHEN** a location is created without a `google_maps_url`
- **THEN** the location is saved successfully with a nil `google_maps_url`

#### Scenario: Same location name is allowed in different groups
- **WHEN** two Location records are created with the same name but different group_id values
- **THEN** both records are saved successfully

#### Scenario: Duplicate location name within the same group is rejected
- **WHEN** a second Location with the same name is created for the same group
- **THEN** a uniqueness error is returned

### Requirement: Locations resource supports archive and restore
The `Location` resource SHALL provide `:archive` and `:unarchive` actions via the `AshArchival.Resource` extension. All read actions SHALL automatically exclude archived locations unless explicitly queried otherwise. Archived locations SHALL retain their data and remain associated with any matches that reference them.

#### Scenario: Archived location is excluded from list_locations
- **WHEN** a location is archived and `Tennis.list_locations!(tenant: group_id)` is called
- **THEN** the archived location is not returned

#### Scenario: Match referencing an archived location still loads the location
- **WHEN** a match has a `location_id` pointing to an archived location
- **THEN** loading the match with its location relationship returns the location record

#### Scenario: Restored location appears in list_locations
- **WHEN** an archived location is restored and `Tennis.list_locations!(tenant: group_id)` is called
- **THEN** the restored location is returned in the results

### Requirement: Location create action does not upsert
The `:create` action SHALL create a new location and return a uniqueness error if a location with the same name already exists in the group. It SHALL NOT silently overwrite an existing location's fields.

#### Scenario: Creating a location with a unique name succeeds
- **WHEN** a location is created with a name not yet used in the group
- **THEN** the location is saved and returned

#### Scenario: Creating a location with a duplicate name returns an error
- **WHEN** a location is created with a name that already exists in the group
- **THEN** a uniqueness validation error is returned and no record is overwritten

## ADDED Requirements

### Requirement: Location update action allows editing venue details
The `Location` resource SHALL provide an `:update` action that accepts changes to `name`, `address`, and `google_maps_url`. The uniqueness constraint on `[:group_id, :name]` SHALL still apply.

#### Scenario: Updating a location's address succeeds
- **WHEN** an update action is called with a new address for an existing location
- **THEN** the location's address is updated

#### Scenario: Updating a location to a duplicate name returns an error
- **WHEN** an update action sets the name to one already used by another location in the group
- **THEN** a uniqueness validation error is returned
