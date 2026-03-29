### Requirement: Export button appears on players index
The players index page SHALL display an "Export CSV" link/button that initiates a CSV download of the currently visible (filtered) player list.

#### Scenario: Export button is always visible
- **WHEN** a user visits the players index page
- **THEN** an "Export CSV" button SHALL be visible in the page header actions

#### Scenario: Export link encodes current filters
- **WHEN** the user has active filters (name search, NTRP ratings)
- **THEN** the "Export CSV" link href SHALL include those filter values as query parameters matching the index page's URL param format

### Requirement: CSV download respects active filters
The export endpoint SHALL return only the players that match the currently active filters — the same set the user sees on the index page.

#### Scenario: Export with no filters returns all players
- **WHEN** the user exports with no filters active
- **THEN** the CSV SHALL contain all players in the system

#### Scenario: Export with name filter
- **WHEN** the user has a name search active (e.g., "Smith")
- **THEN** the CSV SHALL contain only players whose names match that search (case-insensitive, partial match)

#### Scenario: Export with NTRP filter
- **WHEN** the user has one or more NTRP ratings selected (e.g., 3.5 and 4.0)
- **THEN** the CSV SHALL contain only players with those NTRP ratings

#### Scenario: Export with combined filters
- **WHEN** multiple filters are active simultaneously (e.g., NTRP 3.5 + 4.0)
- **THEN** the CSV SHALL contain only players matching ALL active filters

#### Scenario: Export with no matching players
- **WHEN** the active filters match zero players
- **THEN** the CSV SHALL be returned with only the header row and no data rows

### Requirement: CSV response format
The export endpoint SHALL return a valid CSV file as an HTTP attachment download.

#### Scenario: Response triggers browser download
- **WHEN** the export link is followed
- **THEN** the response SHALL have `content-type: text/csv` and `content-disposition: attachment` headers so the browser downloads the file

#### Scenario: CSV filename
- **WHEN** the file is downloaded
- **THEN** the filename SHALL be `players.csv`

#### Scenario: CSV column headers
- **WHEN** the CSV is downloaded
- **THEN** the first row SHALL be a header row with columns: `name`, `email`, `phone_number`, `ntrp_rating`
- **AND** the columns `eligible_18_plus`, `eligible_40_plus`, `eligible_55_plus` SHALL NOT be present

#### Scenario: CSV rows are sorted by name
- **WHEN** the CSV is downloaded
- **THEN** player rows SHALL be ordered alphabetically ascending by name

### Requirement: Filter logic is shared between index and export
The query logic used to filter players for display SHALL be the same logic used to filter players for CSV export.

#### Scenario: Consistent filtering
- **WHEN** the same filter params are passed to the index page and the export endpoint
- **THEN** both SHALL return the same set of players
