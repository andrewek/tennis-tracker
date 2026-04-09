## ADDED Requirements

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
