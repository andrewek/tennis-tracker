## MODIFIED Requirements

### Requirement: CSV column headers
The export endpoint SHALL return a valid CSV file with a header row containing: `name`, `ntrp_rating`, `email`, `phone_number`, followed by one `tag:CategoryName:TagName` column per tag in the group, sorted by category name ascending then tag name ascending. If the group has no tags, only the four base columns appear.

#### Scenario: CSV column headers — no tags defined
- **WHEN** the CSV is downloaded and the group has no tag categories or tags
- **THEN** the first row SHALL be a header row with columns: `name`, `ntrp_rating`, `email`, `phone_number`

#### Scenario: CSV column headers — tags defined
- **WHEN** the CSV is downloaded and the group has tags
- **THEN** the first row SHALL start with `name`, `ntrp_rating`, `email`, `phone_number` and then include one `tag:CategoryName:TagName` column per tag, sorted by category name then tag name ascending

### Requirement: Export link encodes current filters including active tag filters
The "Export CSV" link href SHALL include active filter values as query parameters — name search, NTRP ratings, and selected tag IDs — matching the index page's URL param format.

#### Scenario: Export link encodes active tag filter
- **WHEN** the user has one or more tag filter pills active on the players index
- **THEN** the "Export CSV" link href SHALL include `tags[]` query parameters containing the IDs of the selected tags

#### Scenario: Export link encodes combined filters
- **WHEN** name search, NTRP filter, and tag filters are all active
- **THEN** the "Export CSV" link href SHALL encode all three filter types

### Requirement: Export respects active tag filters when generating player rows
The export endpoint SHALL return only players matching the active tag filter. This behavior is provided by `PlayerFilters.fetch_players/4` and applies to tag filters with the same semantics as the players index page.

#### Scenario: Export with tag filter returns only matching players
- **WHEN** the export endpoint receives an active tag filter
- **THEN** the CSV SHALL contain only players that match the tag filter
