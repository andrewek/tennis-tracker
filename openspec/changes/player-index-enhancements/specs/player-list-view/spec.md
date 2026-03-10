## MODIFIED Requirements

### Requirement: Players list is sorted by NTRP then name by default
The players index SHALL display players sorted by NTRP rating descending by default, then by name ascending. The user MAY toggle the NTRP sort direction between ascending and descending using a control on the page. Only the NTRP column supports sort direction toggling.

#### Scenario: Default sort order applied
- **WHEN** the players index page is loaded without any sort parameters
- **THEN** players SHALL be ordered with higher NTRP ratings first (descending), and players with the same rating ordered alphabetically by name ascending

#### Scenario: User toggles NTRP sort to ascending
- **WHEN** the user activates the NTRP sort direction toggle
- **THEN** players SHALL be ordered with lower NTRP ratings first (ascending), and players with the same rating ordered alphabetically by name ascending

#### Scenario: User toggles NTRP sort back to descending
- **WHEN** the NTRP sort direction is ascending and the user activates the toggle again
- **THEN** players SHALL revert to descending NTRP order

#### Scenario: Sort direction preserved with filters
- **WHEN** the players index page is loaded with name, NTRP, or bracket filter parameters and a sort direction parameter
- **THEN** the filtered results SHALL be sorted according to the selected NTRP sort direction, then name ascending

## ADDED Requirements

### Requirement: Players list NTRP filter includes "No rating" option
The NTRP filter on the players index page SHALL include a "No rating" checkbox that, when selected, includes players with no NTRP rating assigned in the results.

#### Scenario: "No rating" checkbox visible
- **WHEN** the players index page is rendered
- **THEN** a "No rating" checkbox SHALL appear alongside the standard NTRP rating checkboxes

#### Scenario: Filter by no rating only
- **WHEN** only the "No rating" checkbox is checked
- **THEN** only players with no NTRP rating SHALL be shown

#### Scenario: Filter by no rating combined with rated values
- **WHEN** "No rating" and one or more rated NTRP values are checked
- **THEN** players matching any of the selected NTRP values OR having no rating SHALL be shown

#### Scenario: Unrated players excluded without "No rating" filter
- **WHEN** one or more NTRP rating checkboxes are checked but "No rating" is not checked
- **THEN** players with no NTRP rating SHALL NOT appear in the results

#### Scenario: Clear filters resets "No rating" selection
- **WHEN** the user clicks "Clear filters"
- **THEN** the "No rating" checkbox SHALL be unchecked and unrated players SHALL appear only based on the default (no filter)
