## ADDED Requirements

### Requirement: Team edit page is accessible at /teams/:id/edit
The system SHALL provide a page at `/teams/:id/edit` for authenticated users. The page SHALL load the team's current name and default timezone into a form. Pseudo-teams (`is_pseudo == true`) SHALL NOT be accessible via this route. Non-existent team IDs SHALL redirect to `/` with a flash error.

#### Scenario: Authenticated user navigates to the edit page
- **WHEN** an authenticated user navigates to `/teams/:id/edit` for a real team
- **THEN** the page loads and displays a form pre-populated with the team's current name and default timezone

#### Scenario: Pseudo-team edit page is blocked
- **WHEN** a user navigates to `/teams/:id/edit` where the team has `is_pseudo == true`
- **THEN** the user is redirected to `/`
- **THEN** a flash error message is displayed

#### Scenario: Non-existent team ID redirects with flash error
- **WHEN** a user navigates to `/teams/:id/edit` where no team with that ID exists
- **THEN** the user is redirected to `/`
- **THEN** a flash error message is displayed

### Requirement: Team name and default timezone can be updated from the edit page
The page SHALL provide a form with a text input for team name and a select input for default timezone. Submitting valid values SHALL update the team and display a success flash. Submitting a blank name SHALL display a validation error without saving.

#### Scenario: Valid name and timezone are saved
- **WHEN** a user updates the team name and timezone and submits the form
- **THEN** the team record is updated
- **THEN** a success flash message is displayed
- **THEN** the form reflects the updated values

#### Scenario: Blank name is rejected
- **WHEN** a user submits the team settings form with a blank name
- **THEN** a validation error is displayed
- **THEN** the team name is not changed

#### Scenario: Timezone select shows the seven supported US zones
- **WHEN** the team edit page renders
- **THEN** the timezone select contains exactly these options: Eastern (America/New_York), Central (America/Chicago), Mountain (America/Denver), Mountain - no DST (America/Phoenix), Pacific (America/Los_Angeles), Alaska (America/Anchorage), Hawaii (Pacific/Honolulu)

### Requirement: Match schedule is displayed and manageable from the team edit page
The page SHALL display upcoming and past matches (same data as the team show page). Each match row SHALL have an "Edit" link to `/matches/:id/edit` and a "Delete" button. An "Add Match" button SHALL open a modal form to create a new match.

#### Scenario: Upcoming matches are listed
- **WHEN** the team edit page loads for a team with upcoming matches
- **THEN** each upcoming match is displayed with opponent, date, time, and location

#### Scenario: Add Match modal creates a new match
- **WHEN** a user clicks "Add Match" and submits a valid form
- **THEN** a new match is created for the team
- **THEN** the match list refreshes to include the new match
- **THEN** a success flash message is displayed

#### Scenario: Edit link navigates to match edit page
- **WHEN** a user clicks "Edit" on a match row
- **THEN** the user is navigated to `/matches/:id/edit`

#### Scenario: Delete button removes the match and refreshes the list
- **WHEN** a user clicks "Delete" on a match row and confirms
- **THEN** the match is deleted
- **THEN** the match list refreshes and no longer includes that match
- **THEN** a flash message confirms deletion

### Requirement: Team edit page has a back navigation link to the team show page
The page SHALL display a back link to `/teams/:id` so the user can return to the read-only view.

#### Scenario: Back link is present
- **WHEN** the team edit page renders
- **THEN** a link back to `/teams/:id` is visible
