## ADDED Requirements

### Requirement: Teams index page is accessible at /teams
The system SHALL provide a page at `/teams` listing all real (non-pseudo) teams. The page SHALL be accessible only to authenticated users.

#### Scenario: Authenticated user visits /teams
- **WHEN** an authenticated user navigates to `/teams`
- **THEN** the page loads and displays a list of team cards

#### Scenario: Unauthenticated user is redirected
- **WHEN** an unauthenticated user navigates to `/teams`
- **THEN** the user is redirected to the login page

### Requirement: Teams index page has a heading and browser title
The page SHALL display "Teams" as its H1 heading. The browser tab title SHALL include "- Teams".

#### Scenario: Page heading is visible
- **WHEN** an authenticated user navigates to `/teams`
- **THEN** the text "Teams" is visible as the primary heading on the page

### Requirement: Teams index displays real teams only, sorted by default order
The `:list_real` read action on the Team resource SHALL return only non-pseudo teams (`is_pseudo == false`), sorted by season year descending, then age group ascending, then NTRP level descending, then name ascending.

#### Scenario: Pseudo-teams are excluded
- **WHEN** the `:list_real` action is called
- **THEN** teams with `is_pseudo == true` are not returned

#### Scenario: Teams are returned in correct order
- **WHEN** the `:list_real` action is called with teams spanning multiple season years, age groups, and NTRP levels
- **THEN** teams are sorted by season year desc, then age group asc (nils last), then NTRP level desc (nils last), then name asc

### Requirement: Each team card shows name, subtitle, and placeholder next match
Each card SHALL display the team name as a heading, a subtitle in the format `{team_type_name} · {age_group} · {ntrp_level} · {season_year}` (omitting nil fields), and the placeholder text "Next match: TBD". Each card SHALL be a navigable link to `/teams/:id`.

#### Scenario: Card displays team information
- **WHEN** the page loads
- **THEN** each card shows the team name
- **THEN** each card shows a subtitle with team type name, age group, NTRP level, and season year
- **THEN** each card shows "Next match: TBD"

#### Scenario: Card links to team show page
- **WHEN** a user clicks a team card
- **THEN** the user is navigated to `/teams/:id` for that team

### Requirement: Teams index shows an empty state when no teams exist
When no real teams exist, the page SHALL display a heading "No teams yet" and subtext "Teams will appear here once they've been added." in place of the card grid.

#### Scenario: No teams exist
- **WHEN** no real teams exist
- **THEN** the text "No teams yet" is visible on the page
- **THEN** no team cards are rendered

### Requirement: Teams index page is responsive
The card grid SHALL adapt to different screen sizes, matching the layout pattern used on the home page.

#### Scenario: Single column on small screens
- **WHEN** the page is rendered at mobile viewport widths
- **THEN** the cards stack in a single column

#### Scenario: Multi-column on larger screens
- **WHEN** the page is rendered at tablet or desktop viewport widths
- **THEN** the cards display in a multi-column grid layout

### Requirement: LiveView smoke tests cover the teams index page
The system SHALL have LiveView integration tests verifying the page renders and respects authentication.

#### Scenario: Authenticated user sees team cards
- **WHEN** real teams exist and an authenticated user visits `/teams`
- **THEN** each team's name is visible on the page

#### Scenario: Empty state is shown when no teams exist
- **WHEN** no real teams exist and an authenticated user visits `/teams`
- **THEN** the text "No teams yet" is visible on the page
- **THEN** no team cards are rendered

#### Scenario: Unauthenticated user is redirected
- **WHEN** an unauthenticated user visits `/teams`
- **THEN** the user is redirected away from the page
