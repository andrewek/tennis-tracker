## ADDED Requirements

### Requirement: Group member management page is accessible only to group owners
The system SHALL provide a LiveView at `/g/:group_slug/settings/members` that is only accessible to users with a `GroupMembership` role of `:owner` for that group. Non-owners who navigate to this URL SHALL be redirected to the group home page.

#### Scenario: Group owner can access the members page
- **WHEN** a user with GroupMembership role `:owner` navigates to `/g/:group_slug/settings/members`
- **THEN** the page renders successfully showing the current list of members

#### Scenario: Group member (non-owner) is redirected from the members page
- **WHEN** a user with GroupMembership role `:member` navigates to `/g/:group_slug/settings/members`
- **THEN** the user is redirected to the group home page and the members page is not rendered

### Requirement: Group owner can add an existing user to the group by email
The system SHALL allow a group owner to add an existing user (one who already has an account) to the group by typing their email address and selecting a role. If a user with that email already exists and is not yet a member of the group, a `GroupMembership` SHALL be created for them.

#### Scenario: Adding an existing user who is not yet in the group
- **WHEN** a group owner submits the add-member form with the email of an existing user and a role
- **THEN** a GroupMembership is created and the user appears in the member list

#### Scenario: Adding a user who is already a member shows an error
- **WHEN** a group owner submits the add-member form with the email of a user who is already a member
- **THEN** an error is displayed and no duplicate membership is created

### Requirement: Group owner can add a new user to the group by email, creating an account
The system SHALL allow a group owner to add a person who has no account. When the submitted email does not match any existing user, the system SHALL create a new `User` account with a system-generated placeholder password, then create a `GroupMembership` for that user. The placeholder password SHALL be displayed prominently on the page (not as a flash message) until the owner explicitly dismisses it.

#### Scenario: Adding a new user creates an account and membership
- **WHEN** a group owner submits the add-member form with an email that has no existing account
- **THEN** a new User is created, a GroupMembership is created, and the new user appears in the member list

#### Scenario: Placeholder password is shown prominently after new user creation
- **WHEN** a new User is created via the add-member form
- **THEN** the placeholder password is displayed in a prominent on-page card (not a flash), visible until the owner dismisses it

#### Scenario: Placeholder password card can be dismissed
- **WHEN** the owner clicks "Dismiss" on the placeholder password card
- **THEN** the card is removed from the page

#### Scenario: Placeholder password is not shown for existing users
- **WHEN** a group owner adds an existing user (account already exists)
- **THEN** no placeholder password card is displayed

### Requirement: Group owner can change any member's role except their own
The system SHALL allow a group owner to change any other member's role between `:owner` and `:member`. The role control SHALL NOT be rendered for the current user's own membership row.

#### Scenario: Owner changes a member's role to :owner
- **WHEN** a group owner changes another member's role to `:owner`
- **THEN** the GroupMembership role is updated to `:owner` and the UI reflects the change

#### Scenario: Owner changes another owner's role to :member
- **WHEN** a group owner changes another owner's role to `:member`
- **THEN** the GroupMembership role is updated to `:member` and the UI reflects the change

#### Scenario: Role change control is not shown for the current user's own row
- **WHEN** a group owner views the members page
- **THEN** their own membership row shows a static role badge with no role change control

### Requirement: Group owner can remove any member except themselves
The system SHALL allow a group owner to remove any other member from the group. Removal destroys the `GroupMembership` record but does NOT delete the `User` account. A confirmation step SHALL be required before removal. The remove control SHALL NOT be rendered for the current user's own membership row.

#### Scenario: Owner removes a member after confirmation
- **WHEN** a group owner clicks "Remove" on a member row and confirms
- **THEN** the GroupMembership is destroyed and the member is no longer listed

#### Scenario: Removal requires confirmation
- **WHEN** a group owner clicks "Remove" on a member row
- **THEN** a confirmation prompt is shown before the membership is destroyed

#### Scenario: Cancelled removal keeps the member
- **WHEN** a group owner clicks "Remove" and then cancels the confirmation
- **THEN** no membership is destroyed and the member remains in the list

#### Scenario: Remove control is not shown for the current user's own row
- **WHEN** a group owner views the members page
- **THEN** their own membership row has no "Remove" button or control

#### Scenario: Removing a member does not delete the user account
- **WHEN** a group owner removes a member
- **THEN** the User record still exists and is not deleted
