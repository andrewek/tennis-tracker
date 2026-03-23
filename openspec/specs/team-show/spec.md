## Requirements

### Requirement: Team show page is accessible at /teams/:id

The system SHALL provide a read-only page at `/teams/:id` that displays the team's details. The page SHALL be accessible only to authenticated users with a `:user` role. Pseudo-teams (`is_pseudo == true`) SHALL NOT be accessible via this route.

#### Scenario: Authenticated user views a real team
- **WHEN** an authenticated user navigates to `/teams/:id` for a real team
- **THEN** the page loads and displays the team's details

#### Scenario: Unauthenticated user is redirected
- **WHEN** an unauthenticated user navigates to `/teams/:id`
- **THEN** the user is redirected to the login page

#### Scenario: Pseudo-team ID is requested
- **WHEN** a user navigates to `/teams/:id` where the team has `is_pseudo == true`
- **THEN** the user is redirected to `/`
- **THEN** a flash error message is displayed

#### Scenario: Non-existent team ID is requested
- **WHEN** a user navigates to `/teams/:id` where no team with that ID exists
- **THEN** the user is redirected to `/`
- **THEN** a flash error message is displayed

### Requirement: Team header displays identity information

The page SHALL display the team's name prominently, along with the team type name, age group, NTRP level, and season year as a subtitle.

#### Scenario: Full team identity displayed
- **WHEN** the team show page loads
- **THEN** the team name is displayed as the primary heading
- **THEN** the team type name, age group, NTRP level, and season year are displayed as a subtitle

### Requirement: Roster is displayed read-only and sorted alphabetically

The page SHALL display all players on the team sorted alphabetically by name. The roster SHALL use the same card visual style as the roster planner: player name on the left, NTRP rating on the right (or "?" if unrated), without drag-and-drop or violation indicators.

#### Scenario: Roster renders player names in order
- **WHEN** the team show page loads for a team with players
- **THEN** each player's name is listed
- **THEN** names are sorted A→Z

#### Scenario: Empty roster
- **WHEN** the team has no players
- **THEN** the roster section SHALL display an empty state message indicating no players are on the team

### Requirement: Player quick-look modal opens on name click

Clicking a player name SHALL open a modal showing the player's name and a link to their full profile page. The modal SHALL close when dismissed.

#### Scenario: User clicks a player name
- **WHEN** a user clicks a player name in the roster list
- **THEN** a modal opens showing the player's name and a "View full profile" link to `/players/:id`

#### Scenario: User dismisses the modal
- **WHEN** the user closes the player modal
- **THEN** the modal closes and the page returns to its normal state

### Requirement: Match schedule section is displayed read-only with real match data
The page SHALL display upcoming and past matches for the team. Match rows SHALL be read-only — no add, edit, or delete controls SHALL appear on the show page. Each match row SHALL link to `/matches/:id`. The page SHALL include an "Edit Team" link to `/teams/:id/edit`.

#### Scenario: Upcoming matches are listed read-only
- **WHEN** the team show page loads for a team with upcoming matches
- **THEN** each upcoming match is displayed with opponent, date, time, and location
- **THEN** no "Add Match", "Edit", or "Delete" controls are present on the page

#### Scenario: Past matches are listed read-only
- **WHEN** the team show page loads for a team with past matches
- **THEN** each past match is displayed with opponent, date, time, and location
- **THEN** no mutation controls are present

#### Scenario: Edit Team link is present
- **WHEN** the team show page renders
- **THEN** a link to `/teams/:id/edit` is visible

#### Scenario: Empty upcoming matches
- **WHEN** the team has no upcoming matches
- **THEN** an empty state message is displayed in the upcoming matches section

#### Scenario: Empty past matches
- **WHEN** the team has no past matches
- **THEN** an empty state message is displayed in the past matches section

### Requirement: Page is responsive on mobile and desktop

The page layout SHALL be usable on both mobile-sized and desktop-sized viewports. On mobile the sections stack vertically; on desktop they display side by side.

#### Scenario: Mobile layout
- **WHEN** the page is viewed on a narrow viewport
- **THEN** the roster and match schedule sections stack vertically

#### Scenario: Desktop layout
- **WHEN** the page is viewed on a wide viewport
- **THEN** the roster and match schedule sections display side by side

### Requirement: Team show page provides an Export Calendar link
The team show page SHALL include an "Export Calendar" link visible to all authenticated group members. The link SHALL point to `GET /g/:group_slug/teams/:team_id/calendar.ics` and trigger a file download when clicked.

#### Scenario: Export Calendar link is present for group members
- **WHEN** an authenticated group member views the team show page
- **THEN** an "Export Calendar" link is visible on the page

#### Scenario: Export Calendar link points to the correct route
- **WHEN** the team show page renders for team with id `abc` in group `my-group`
- **THEN** the Export Calendar link href is `/g/my-group/teams/abc/calendar.ics`

### Requirement: LiveView smoke tests cover the team show page

The system SHALL have LiveView integration tests that verify the page renders correctly with real data and handles invalid team IDs gracefully.

#### Scenario: Team with players renders correct information
- **WHEN** a team has players assigned to it
- **AND** an authenticated user visits `/teams/:id`
- **THEN** the team name is visible on the page
- **THEN** each player's name is visible on the page

#### Scenario: Navigating to a pseudo-team redirects with a flash error
- **WHEN** an authenticated user navigates to `/teams/:id` for a pseudo-team
- **THEN** the user is redirected to `/`
- **THEN** a flash error message is present on the page

#### Scenario: Navigating to a non-existent team redirects with a flash error
- **WHEN** an authenticated user navigates to `/teams/:id` with an ID that does not exist
- **THEN** the user is redirected to `/`
- **THEN** a flash error message is present on the page
