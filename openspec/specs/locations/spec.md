## Requirements

### Requirement: Locations resource stores known match venues

The system SHALL provide a `Location` Ash resource with `name`, `address`, and `google_maps_url` attributes. Locations SHALL be shared across all teams and seasons. The `name` attribute SHALL be unique and non-nullable. The `address` attribute SHALL be non-nullable. The `google_maps_url` attribute SHALL be optional. Locations SHALL NOT be hard-deleted; archiving support is future scope (see todo.md).

#### Scenario: Location has required fields
- **WHEN** a location exists in the database
- **THEN** it has a non-null `name` and `address`

#### Scenario: Location google_maps_url is optional
- **WHEN** a location is created without a `google_maps_url`
- **THEN** the location is saved successfully with a nil `google_maps_url`

### Requirement: Known locations are pre-seeded

The system SHALL seed a set of known local tennis venues when `mix run priv/repo/seeds.exs` is run. Seeding SHALL be idempotent — running seeds multiple times SHALL NOT create duplicate locations.

#### Scenario: Seeds run on a fresh database
- **WHEN** `mix run priv/repo/seeds.exs` is run on a fresh database
- **THEN** at least one Location record exists in the database with a valid name and address

#### Scenario: Seeds run a second time
- **WHEN** `mix run priv/repo/seeds.exs` is run twice
- **THEN** no duplicate Location records are created

### Requirement: Locations are listable for selection

The system SHALL expose a `list_locations/1` domain function that returns all locations sorted alphabetically by name for use in match creation forms.

#### Scenario: Listing locations returns sorted results
- **WHEN** `Tennis.list_locations!/0` is called
- **THEN** it returns all Location records sorted A→Z by name
