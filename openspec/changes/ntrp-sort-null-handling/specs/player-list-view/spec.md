## MODIFIED Requirements

### Requirement: Players list is sorted by NTRP then name by default
The players index SHALL display players sorted by NTRP rating descending by default, then by name ascending. The user MAY toggle the NTRP sort direction between ascending and descending using a control on the page. Only the NTRP column supports sort direction toggling. Unrated players (no NTRP rating) SHALL always appear after all rated players when sorted descending, and before all rated players when sorted ascending.

#### Scenario: Default sort order applied
- **WHEN** the players index page is loaded without any sort parameters
- **THEN** players SHALL be ordered with higher NTRP ratings first (descending), and players with the same rating ordered alphabetically by name ascending, and unrated players SHALL appear below all rated players

#### Scenario: User toggles NTRP sort to ascending
- **WHEN** the user activates the NTRP sort direction toggle
- **THEN** players SHALL be ordered with lower NTRP ratings first (ascending), and players with the same rating ordered alphabetically by name ascending, and unrated players SHALL appear above all rated players

#### Scenario: User toggles NTRP sort back to descending
- **WHEN** the NTRP sort direction is ascending and the user activates the toggle again
- **THEN** players SHALL revert to descending NTRP order with unrated players at the bottom

#### Scenario: Sort direction preserved with filters
- **WHEN** the players index page is loaded with name, NTRP, or bracket filter parameters and a sort direction parameter
- **THEN** the filtered results SHALL be sorted according to the selected NTRP sort direction, then name ascending, with unrated players positioned according to the selected direction
