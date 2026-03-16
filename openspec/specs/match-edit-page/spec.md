## Requirements

### Requirement: Match edit page is accessible at /matches/:id/edit
The system SHALL provide a page at `/matches/:id/edit` for authenticated users. The page SHALL load the match's current field values into a form. Non-existent match IDs SHALL redirect to `/` with a flash error.

#### Scenario: Authenticated user navigates to the match edit page
- **WHEN** an authenticated user navigates to `/matches/:id/edit` for an existing match
- **THEN** the page loads and displays a form pre-populated with the match's current opponent, home/away designation, date, time, and location

#### Scenario: Non-existent match ID redirects with flash error
- **WHEN** a user navigates to `/matches/:id/edit` where no match with that ID exists
- **THEN** the user is redirected to `/`
- **THEN** a flash error message is displayed

### Requirement: Match fields can be updated from the match edit page
The page SHALL provide form inputs for opponent (text), home/away (select), date (date picker), time (time picker), and location (select). Submitting valid values SHALL update the match, redirect to `/teams/:id/edit`, and display a success flash.

#### Scenario: Valid match update is saved
- **WHEN** a user edits match fields and submits the form
- **THEN** the match record is updated
- **THEN** the user is redirected to `/teams/:id/edit`
- **THEN** a success flash message is displayed

#### Scenario: Invalid match update shows errors
- **WHEN** a user submits the match edit form with a missing required field (e.g. blank opponent)
- **THEN** a validation error is displayed
- **THEN** the match is not updated

### Requirement: A match can be deleted from the match edit page
The page SHALL provide a delete button. Confirming deletion SHALL destroy the match, redirect to `/teams/:id/edit`, and display a success flash.

#### Scenario: Match is deleted
- **WHEN** a user clicks the delete button and confirms
- **THEN** the match is destroyed
- **THEN** the user is redirected to `/teams/:id/edit`
- **THEN** a flash message confirms deletion

### Requirement: Match edit page has a back navigation link to the team edit page
The page SHALL display a back link to `/teams/:id/edit` so the user can return to team management without saving.

#### Scenario: Back link is present
- **WHEN** the match edit page renders
- **THEN** a link back to `/teams/:id/edit` is visible

### Requirement: Match show page has an Edit Match link
The match show page at `/matches/:id` SHALL display a link to `/matches/:id/edit`.

#### Scenario: Edit link is present on match show page
- **WHEN** an authenticated user views `/matches/:id`
- **THEN** a link to `/matches/:id/edit` is visible on the page
