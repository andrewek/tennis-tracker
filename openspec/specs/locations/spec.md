## Requirements

### Requirement: Locations resource stores known match venues
The system SHALL provide a `Location` Ash resource with `name`, `street_address`, `city`, `state`, `postal_code`, and `google_maps_url` attributes. Locations SHALL be scoped to a Group via `group_id` (tenant attribute) and SHALL NOT be shared across groups. The `name` attribute SHALL be unique within a group (unique constraint: `[:group_id, :name]`) and non-nullable. The `street_address`, `city`, `state`, and `postal_code` attributes SHALL each be nullable — a location may be created with only a name and address fields filled in later. The `google_maps_url` attribute SHALL be optional. Locations SHALL support soft-delete via the `AshArchival.Resource` extension; the `archived_at` field tracks when a location was archived. Locations SHALL NOT be hard-deleted.

#### Scenario: Location can be created with name only
- **WHEN** a location is created with only a name and no address fields
- **THEN** the location is saved successfully with nil street_address, city, state, and postal_code

#### Scenario: Location google_maps_url is optional
- **WHEN** a location is created without a `google_maps_url`
- **THEN** the location is saved successfully with a nil `google_maps_url`

#### Scenario: Same location name is allowed in different groups
- **WHEN** two Location records are created with the same name but different group_id values
- **THEN** both records are saved successfully

#### Scenario: Duplicate location name within the same group is rejected
- **WHEN** a second Location with the same name is created for the same group
- **THEN** a uniqueness error is returned

### Requirement: Location exposes a formatted_address calculation
The `Location` resource SHALL provide a `:formatted_address` expression calculation that composes `street_address`, `city`, `state`, and `postal_code` into a single display string in the form `"street_address, city, state postal_code"` (e.g. `"123 Main St, Springfield, IL 62701"`). When all four fields are nil, `formatted_address` SHALL return nil. Display contexts that render `formatted_address` SHALL handle a nil value gracefully (e.g. omit the address line rather than rendering "nil").

#### Scenario: formatted_address composes structured fields correctly
- **WHEN** a location has street_address "123 Main St", city "Springfield", state "IL", postal_code "62701"
- **THEN** `formatted_address` returns `"123 Main St, Springfield, IL 62701"`

#### Scenario: formatted_address returns nil when no address fields are set
- **WHEN** a location has nil street_address, city, state, and postal_code
- **THEN** `formatted_address` returns nil

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

### Requirement: Location create action accepts structured address fields
The `:create` action SHALL accept `name`, `street_address`, `city`, `state`, `postal_code`, and `google_maps_url`. It SHALL NOT accept an `address` field. It SHALL create a new location and return a uniqueness error if a location with the same name already exists in the group. Address fields are optional and may be omitted or nil.

#### Scenario: Creating a location with name only succeeds
- **WHEN** a location is created with only a name provided
- **THEN** the location is saved with nil address fields

#### Scenario: Creating a location with all fields succeeds
- **WHEN** a location is created with name, street_address, city, state, and postal_code provided
- **THEN** the location is saved and returned

#### Scenario: Creating a location with a duplicate name returns an error
- **WHEN** a location is created with a name that already exists in the group
- **THEN** a uniqueness validation error is returned and no record is overwritten

### Requirement: Location update action allows editing structured address fields
The `Location` resource SHALL provide an `:update` action that accepts changes to `name`, `street_address`, `city`, `state`, `postal_code`, and `google_maps_url`. The uniqueness constraint on `[:group_id, :name]` SHALL still apply.

#### Scenario: Updating a location's address fields succeeds
- **WHEN** an update action is called with new values for street_address, city, state, or postal_code
- **THEN** the location's address fields are updated

#### Scenario: Updating a location to a duplicate name returns an error
- **WHEN** an update action sets the name to one already used by another location in the group
- **THEN** a uniqueness validation error is returned

### Requirement: Known locations are pre-seeded under the default group
The system SHALL seed a set of known local tennis venues when `mix run priv/repo/seeds.exs` is run. Seeded locations SHALL use the structured address fields (`street_address`, `city`, `state`, `postal_code`). Seeding SHALL be idempotent.

#### Scenario: Seeds run on a fresh database
- **WHEN** `mix run priv/repo/seeds.exs` is run on a fresh database
- **THEN** at least one Location record exists with non-null name, street_address, city, state, and postal_code

#### Scenario: Seeds run a second time
- **WHEN** `mix run priv/repo/seeds.exs` is run twice
- **THEN** no duplicate Location records are created

### Requirement: Locations are listable for selection within a group
The system SHALL expose a `list_locations/1` domain function that returns all locations for the current tenant sorted alphabetically by name.

#### Scenario: Listing locations returns sorted results for the current group
- **WHEN** `Tennis.list_locations!(tenant: group_id)` is called
- **THEN** it returns all Location records for that group sorted A→Z by name

#### Scenario: Locations from other groups are not returned
- **WHEN** `Tennis.list_locations!(tenant: group_a_id)` is called
- **THEN** no Location records belonging to group B are returned

### Requirement: Location creation and management requires group owner role
Only users with a `GroupMembership.role == :owner` for the current group (or system admins) SHALL be permitted to create, update, or delete Location records.

#### Scenario: Group owner can create a location
- **WHEN** a user with GroupMembership :owner creates a location for their group
- **THEN** the location is saved successfully

#### Scenario: Group member cannot create a location
- **WHEN** a user with GroupMembership :member attempts to create a location
- **THEN** the action is denied
