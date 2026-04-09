## Requirements

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

### Requirement: Team edit page includes a lineup column management section
The team edit page SHALL include a section for managing lineup columns, visible to team captains and group owners, positioned above the lineup slots section.

#### Scenario: Column management section visible to captain
- **WHEN** a team captain visits the team edit page
- **THEN** a lineup columns section SHALL be visible listing current columns with options to add, rename, reorder, and delete

#### Scenario: Column management section hidden from non-captains
- **WHEN** a regular group member visits the team edit page
- **THEN** the column management section SHALL NOT be rendered

#### Scenario: Empty column list shows prompt to add first column
- **WHEN** the team has no lineup columns defined
- **THEN** the section SHALL show an empty state prompting the captain to add the first column

### Requirement: Captain can add a new column from the team edit page
The column management section SHALL include a form or inline control for creating a new TeamLineupColumn.

#### Scenario: Add column
- **WHEN** a captain submits a new column name
- **THEN** the column SHALL be created with sort_order `MAX(existing sort_orders) + 1` (or `1` if no columns exist), appended to the end of the column list, and appear in the list

### Requirement: Captain can reorder columns from the team edit page
The column management section SHALL provide move-up and move-down controls for reordering columns.

#### Scenario: Reorder columns
- **WHEN** a captain uses the move-up or move-down buttons to change the order of columns
- **THEN** the updated sort_order values SHALL be persisted and the list SHALL reflect the new sequence

#### Scenario: Move-up disabled for first column
- **WHEN** a column is first in the list
- **THEN** its move-up button SHALL be disabled

#### Scenario: Move-down disabled for last column
- **WHEN** a column is last in the list
- **THEN** its move-down button SHALL be disabled

### Requirement: Captain can rename a column from the team edit page
The column management section SHALL provide an inline edit control for renaming each column.

#### Scenario: Rename column
- **WHEN** a captain edits a column's name and submits
- **THEN** the updated name SHALL be persisted and reflected in the column list

#### Scenario: Rename to duplicate name is rejected
- **WHEN** a captain attempts to rename a column to a name already used by another column on the same team
- **THEN** the action SHALL be rejected with a validation error and the column SHALL retain its previous name

### Requirement: Captain can delete an empty column from the team edit page
Each column in the list SHALL have a delete control. A column can only be deleted when it has no slots assigned to it.

#### Scenario: Delete empty column
- **WHEN** a captain deletes a column that has no slots assigned
- **THEN** the column SHALL be destroyed

#### Scenario: Delete column with slots is blocked
- **WHEN** a captain attempts to delete a column that has slots assigned to it
- **THEN** an error SHALL be shown indicating the column cannot be deleted until all slots are reassigned or deleted
- **AND** the column SHALL NOT be destroyed

### Requirement: Captain can assign a slot to a column from the team edit page
Each slot row in the slot management section SHALL include a required column assignment dropdown. A column assignment is required; there is no uncolumned option.

#### Scenario: Assign slot to column
- **WHEN** a captain selects a column for a slot using the column assignment control
- **THEN** the slot's team_lineup_column_id SHALL be updated and the change SHALL be persisted

### Requirement: Team edit page includes a lineup assignment mode setting
The team edit page SHALL include a setting for `lineup_assignment_mode`, visible and editable by team captains and group owners.

#### Scenario: Captain can view and change lineup assignment mode
- **WHEN** a captain views the team edit page
- **THEN** the current lineup_assignment_mode SHALL be shown
- **AND** the captain SHALL be able to change it to any valid mode (:one_per_match, :one_per_column, :many_per_match)

#### Scenario: Change is persisted
- **WHEN** a captain saves a new lineup_assignment_mode
- **THEN** the team's lineup_assignment_mode SHALL reflect the new value

#### Scenario: Mode change blocked when existing assignments would violate the new mode
- **WHEN** a captain attempts to change lineup_assignment_mode to a more restrictive mode and existing match assignments across the team's matches would violate the new constraint
- **THEN** the change SHALL be rejected with a validation error
- **AND** the team's lineup_assignment_mode SHALL retain its current value
- **AND** the error SHALL indicate that conflicting assignments must be resolved first

#### Scenario: Mode change to many_per_match always succeeds
- **WHEN** a captain changes lineup_assignment_mode to :many_per_match
- **THEN** the change SHALL be accepted regardless of existing assignments

#### Scenario: Non-captain cannot change lineup assignment mode
- **WHEN** a regular group member views the team edit page
- **THEN** the lineup_assignment_mode setting SHALL NOT be rendered or editable

### Requirement: Team edit page includes a Captains management section
The team edit page SHALL include a "Captains" section accessible to group owners and team captains. The section SHALL list all current captains (users with a `:captain` TeamRole for this team) by display name (name if present, email otherwise). Regular group members who are not owners or captains are redirected away from the team edit page entirely; they can see the captain list on the team show page (see `team-show-page` spec).

#### Scenario: Group owner sees Captains section with edit controls
- **WHEN** a group owner visits the team edit page
- **THEN** the Captains section is rendered with the current captain list and add/remove controls

#### Scenario: Team captain sees Captains section with edit controls
- **WHEN** a user with a :captain TeamRole for the team visits the team edit page
- **THEN** the Captains section is rendered with the current captain list and add/remove controls

#### Scenario: Regular group member is redirected from the team edit page
- **WHEN** a user with GroupMembership :member and no :captain TeamRole for this team navigates to the team edit URL
- **THEN** they are redirected to the team show page
- **AND** no edit controls are rendered

#### Scenario: Empty captains list shows an empty state
- **WHEN** the team has no :captain TeamRole records
- **THEN** the Captains section shows a message indicating no captains are assigned

### Requirement: Group owner or team captain can add a captain from a group member picker
The Captains section SHALL include an inline select control populated with group members (users with a GroupMembership for this group) who are not already `:captain` for this team, and an "Add" button. Selecting a user and clicking "Add" SHALL assign them as captain. If the selected user already has a `:member` TeamRole for the team, their role SHALL be updated to `:captain`. If they have no TeamRole for the team, a new `:captain` TeamRole SHALL be created.

#### Scenario: Picker shows group members not already captain
- **WHEN** the Captains section renders
- **THEN** the select contains only group members without a :captain TeamRole for this team
- **AND** users already :captain are excluded from the select

#### Scenario: Adding a captain with no existing TeamRole creates one
- **WHEN** an owner or captain selects a group member with no TeamRole for this team and clicks "Add"
- **THEN** a new TeamRole with role :captain is created for that user and team
- **AND** the captain list refreshes to include the new captain
- **AND** the new captain is removed from the picker

#### Scenario: Adding a captain who has a :member TeamRole updates the role
- **WHEN** an owner or captain selects a group member who has a :member TeamRole for this team and clicks "Add"
- **THEN** the TeamRole role is updated to :captain
- **AND** the captain list refreshes to include them
- **AND** they are removed from the picker

#### Scenario: No selection is made — Add is a no-op
- **WHEN** the "Add" button is clicked with no user selected
- **THEN** no TeamRole is created or updated

### Requirement: Group owner or team captain can remove a captain via confirmation modal
Each captain row in the Captains section SHALL have a "Remove" button. Clicking it SHALL open a confirmation modal with three options: "Remove from team entirely", "Convert to Member", and "Cancel".

#### Scenario: Remove from team entirely destroys the TeamRole
- **WHEN** an owner or captain clicks "Remove" for a captain and selects "Remove from team entirely"
- **THEN** the TeamRole record is destroyed
- **AND** the captain list refreshes and no longer includes that user

#### Scenario: Convert to Member updates the TeamRole role
- **WHEN** an owner or captain clicks "Remove" for a captain and selects "Convert to Member"
- **THEN** the TeamRole role is updated to :member
- **AND** the captain list refreshes and no longer includes that user as a captain

#### Scenario: Cancel closes the modal without changes
- **WHEN** an owner or captain clicks "Remove" for a captain and then selects "Cancel"
- **THEN** the modal closes
- **AND** no changes are made to the TeamRole

#### Scenario: A captain can remove themselves
- **WHEN** a captain clicks "Remove" on their own row and confirms
- **THEN** their TeamRole is updated or destroyed per the selected option
- **AND** on the next page interaction they no longer have captain-level access
