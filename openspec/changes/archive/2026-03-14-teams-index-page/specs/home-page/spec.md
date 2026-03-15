## REMOVED Requirements

### Requirement: Teams card has no active destination
**Reason**: The Teams index page now exists at `/teams`.
**Migration**: The Teams card link is updated to navigate to `/teams`.

## MODIFIED Requirements

### Requirement: Home page displays a branded card grid
The home page at `/` SHALL display a responsive grid of card-style navigation links for Players, Teams, Winter Tennis, and Roster Planner.

#### Scenario: Four cards are visible
- **WHEN** the home page is loaded
- **THEN** four cards labeled "Players", "Teams", "Winter Tennis", and "Roster Planner" SHALL be visible

#### Scenario: Players card links to /players
- **WHEN** the user clicks the "Players" card
- **THEN** the user SHALL be navigated to `/players`

#### Scenario: Roster Planner card links to /roster-planner
- **WHEN** the user clicks the "Roster Planner" card
- **THEN** the user SHALL be navigated to `/roster-planner`

#### Scenario: Teams card links to /teams
- **WHEN** the user clicks the "Teams" card
- **THEN** the user SHALL be navigated to `/teams`

#### Scenario: Winter Tennis card has no active destination
- **WHEN** the Winter Tennis card is rendered
- **THEN** it SHALL be rendered as a non-functional link (e.g., `href="#"` or no navigation occurs)
