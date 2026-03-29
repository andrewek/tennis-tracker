## MODIFIED Requirements

### Requirement: CSV column headers
The export endpoint SHALL return a valid CSV file with the following header row: `name`, `email`, `phone_number`, `ntrp_rating`. The columns `eligible_18_plus`, `eligible_40_plus`, and `eligible_55_plus` are removed as those fields no longer exist on the Player schema. Tag data is not included in the CSV export in this change.

#### Scenario: CSV column headers
- **WHEN** the CSV is downloaded
- **THEN** the first row SHALL be a header row with columns: `name`, `email`, `phone_number`, `ntrp_rating`
- **AND** the columns `eligible_18_plus`, `eligible_40_plus`, `eligible_55_plus` SHALL NOT be present

#### Scenario: CSV rows are sorted by name
- **WHEN** the CSV is downloaded
- **THEN** player rows SHALL be ordered alphabetically ascending by name

## REMOVED Requirements

### Requirement: Export with age bracket filter
**Reason**: The age bracket filter (eligible_18_plus/40_plus/55_plus) no longer exists.
**Migration**: Tag-based CSV export filtering is deferred to a fast-follow change after the core tagging system is complete.

### Requirement: Export link encodes current filters (age bracket portion)
**Reason**: The `bracket` query param no longer exists.
**Migration**: Passing tag filter params through the export URL and applying them in the export endpoint is deferred. In this change, the export link drops the bracket params; tag filter passthrough is out of scope and will be addressed in a follow-on change.
