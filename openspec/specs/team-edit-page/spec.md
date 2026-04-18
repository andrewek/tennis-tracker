## Requirements

### Requirement: Team settings page is accessible at /teams/:id/settings
The system SHALL provide a settings page at `/g/:slug/teams/:id/settings`, which serves as the General tab. Pseudo-teams (`is_pseudo == true`) SHALL NOT be accessible via this route. Non-existent team IDs SHALL redirect to the teams index with a flash error. Users who are neither a team captain nor a group owner SHALL be redirected to the team show page with a flash error.

The legacy `/g/:slug/teams/:id/edit` route is removed.

#### Scenario: Authenticated captain navigates to the settings page
- **WHEN** a team captain navigates to `/g/:slug/teams/:id/settings`
- **THEN** the General tab loads with the team settings form

#### Scenario: Pseudo-team settings page is blocked
- **WHEN** a user navigates to `/g/:slug/teams/:id/settings` where the team has `is_pseudo == true`
- **THEN** the user is redirected to the teams index
- **THEN** a flash error message is displayed

#### Scenario: Non-captain, non-owner is redirected
- **WHEN** a regular group member navigates to `/g/:slug/teams/:id/settings`
- **THEN** the user is redirected to the team show page
- **THEN** a flash error message is displayed

---

### Requirement: Team settings page has a tabbed navigation layout
The settings page SHALL render a tab bar with four tabs: General, Match Schedule, Lineup Settings, and Members. The active tab SHALL be visually distinguished. All four tabs SHALL be visible to both team captains and group owners.

#### Scenario: Tab bar renders all four tabs
- **WHEN** a captain or owner visits any team settings tab
- **THEN** the tab bar shows General, Match Schedule, Lineup Settings, and Members tabs

#### Scenario: Active tab is highlighted
- **WHEN** a user is on the Match Schedule tab
- **THEN** the Match Schedule tab is styled as active and the others are not

#### Scenario: Clicking a tab navigates to that tab's URL
- **WHEN** a user clicks the Lineup Settings tab
- **THEN** the user navigates to `/g/:slug/teams/:id/settings/lineup`

---

### Requirement: General tab consolidates team name, timezone, and assignment mode
The General tab (`/g/:slug/teams/:id/settings`) SHALL provide a single form containing: team name (text input), default timezone (select, same seven US zones as before), and lineup assignment mode (select). Authorization is at the action level: if the current user can perform the team update action, all three fields are editable. If the user cannot perform the update action, the entire form is rendered read-only (disabled). Use `Ash.can?` to determine editability.

#### Scenario: Captain or owner with update permission sees all fields editable
- **WHEN** a team captain or group owner visits the General tab
- **THEN** team name, timezone, and assignment mode inputs are all rendered and editable

#### Scenario: User without update permission sees the form as read-only
- **WHEN** a user who cannot perform the team update action visits the General tab
- **THEN** all form fields are rendered as disabled/read-only and no submit button is shown

#### Scenario: Valid form submission updates the team
- **WHEN** a user with update permission submits a valid name, timezone, and assignment mode
- **THEN** the team is updated and a success flash is shown

#### Scenario: Blank name is rejected
- **WHEN** a user submits the form with a blank team name
- **THEN** a validation error is displayed and the team name is not changed

---

### Requirement: Team settings page includes a lineup slot management section in the Lineup Settings tab
The Lineup Settings tab (`/g/:slug/teams/:id/settings/lineup`) SHALL display lineup categories (TeamLineupColumns) as expanded cards. Each category card SHALL list the slots assigned to that category. The section is accessible to team captains and group owners.

#### Scenario: Lineup Settings tab shows category cards
- **WHEN** a captain visits the Lineup Settings tab for a team with categories and slots
- **THEN** each category is displayed as a card with its slots listed inside

#### Scenario: Empty slot list within a category shows an empty state
- **WHEN** a category has no slots assigned to it
- **THEN** the category card shows an empty state within the card

#### Scenario: Empty category list shows a prompt
- **WHEN** the team has no categories defined
- **THEN** the Lineup Settings tab shows an empty state prompting the captain to add a category

---

### Requirement: Captain can add a category via modal
An "+ Add category" button SHALL be present on the Lineup Settings tab. Clicking it SHALL open a modal with a name field. Submitting a valid name SHALL create the category and close the modal. Submitting a blank name SHALL show a validation error without closing the modal.

#### Scenario: Add category modal opens
- **WHEN** a captain clicks the "+ Add category" button
- **THEN** a modal opens with an empty name field

#### Scenario: Valid category submission creates the category
- **WHEN** a captain submits a valid name
- **THEN** the category is created
- **AND** the modal closes
- **AND** the new category card appears in the list

#### Scenario: Blank name is rejected
- **WHEN** a captain submits the add category form with a blank name
- **THEN** a validation error is shown and the modal remains open

---

### Requirement: Captain can edit a category via modal
Each category card header SHALL include an edit button. Clicking it SHALL open a modal pre-populated with the category's current name. Submitting valid changes SHALL update the category and close the modal.

#### Scenario: Edit category modal opens with current name
- **WHEN** a captain clicks the edit button on a category card
- **THEN** a modal opens pre-populated with the category's current name

#### Scenario: Valid edit submission updates the category
- **WHEN** a captain submits a valid updated name
- **THEN** the category is updated
- **AND** the modal closes
- **AND** the card header reflects the new name

---

### Requirement: Captain can delete a category
Each category card header SHALL include a delete button. The delete button SHALL be disabled when the category has any slots assigned to it. When enabled, clicking the delete button SHALL open a confirmation modal. Confirming SHALL delete the category. Cancelling SHALL close the modal without making changes.

#### Scenario: Delete button is disabled when category has slots
- **WHEN** a category card has one or more slots
- **THEN** the delete button in the card header is disabled

#### Scenario: Delete button is enabled when category has no slots
- **WHEN** a category card has no slots
- **THEN** the delete button in the card header is enabled

#### Scenario: Confirming deletion removes the category
- **WHEN** a captain confirms the deletion of an empty category
- **THEN** the category is deleted
- **AND** the modal closes
- **AND** the category card no longer appears

#### Scenario: Cancelling deletion leaves the category unchanged
- **WHEN** a captain cancels the deletion
- **THEN** the modal closes and the category remains

---

### Requirement: Categories can be reordered
Each category card header SHALL include up and down reorder buttons. The up button SHALL be disabled for the first category. The down button SHALL be disabled for the last category.

#### Scenario: Up button is disabled for the first category
- **WHEN** a category is first in the list
- **THEN** the up button in its card header is disabled

#### Scenario: Down button is disabled for the last category
- **WHEN** a category is last in the list
- **THEN** the down button in its card header is disabled

#### Scenario: Moving a category up swaps it with the one above
- **WHEN** a captain clicks the up button on a category that is not first
- **THEN** the category moves up one position

#### Scenario: Moving a category down swaps it with the one below
- **WHEN** a captain clicks the down button on a category that is not last
- **THEN** the category moves down one position

---

### Requirement: Captain can add a slot via modal from a category card
Each category card in the Lineup Settings tab SHALL include an "+ Add slot" button. Clicking it SHALL open a modal pre-populated with that category selected. The modal SHALL include fields for name, expected_count, include_in_clipboard, participation_type, and a category dropdown (editable). Submitting valid values SHALL create the slot and close the modal. Only one slot modal SHALL be open at a time.

#### Scenario: Add slot modal opens with category pre-selected
- **WHEN** a captain clicks "+ Add slot" on a category card
- **THEN** a modal opens with that category already selected in the category dropdown

#### Scenario: Category dropdown in the add modal is editable
- **WHEN** the add slot modal is open
- **THEN** the captain can change the category dropdown to assign the slot to a different category

#### Scenario: Valid slot submission creates the slot and closes the modal
- **WHEN** a captain submits a valid slot name and participation type
- **THEN** the slot is created
- **AND** the modal closes
- **AND** the new slot appears under the correct category card

#### Scenario: Opening a second slot modal closes the first
- **WHEN** a slot add or edit modal is already open and the captain clicks "+ Add slot" on another card
- **THEN** the first modal closes and the new modal opens

---

### Requirement: Captain can edit a slot via modal from the Lineup Settings tab
Each slot row in a category card SHALL include an edit button. Clicking it SHALL open the same slot modal loaded with the slot's current values. Submitting updates SHALL persist the changes and close the modal. If the captain changes the category dropdown, the slot SHALL move to the selected category on save.

#### Scenario: Edit slot modal opens with current values
- **WHEN** a captain clicks the edit button on a slot
- **THEN** the slot modal opens pre-populated with the slot's name, expected_count, include_in_clipboard, participation_type, and current category

#### Scenario: Changing category in edit modal moves the slot on save
- **WHEN** a captain changes the category dropdown in the edit modal and saves
- **THEN** the slot's team_lineup_column_id is updated
- **AND** the slot appears under the new category card after the modal closes

#### Scenario: Edit slot saves updates and closes modal
- **WHEN** a captain edits slot fields and submits
- **THEN** the updated values are persisted and the modal closes

---

### Requirement: Captain can delete a slot from the Lineup Settings tab
Each slot row in a category card SHALL include a delete affordance. Clicking it SHALL open a confirmation modal. Confirming SHALL delete the slot and close the modal. Cancelling SHALL close the modal without making changes. Only one confirmation modal SHALL be open at a time.

#### Scenario: Delete confirmation modal opens
- **WHEN** a captain clicks the delete affordance on a slot
- **THEN** a confirmation modal opens identifying the slot to be deleted

#### Scenario: Confirming deletion removes the slot
- **WHEN** a captain confirms the deletion
- **THEN** the slot is deleted
- **AND** the modal closes
- **AND** the slot no longer appears in the category card

#### Scenario: Cancelling deletion leaves the slot unchanged
- **WHEN** a captain cancels the deletion
- **THEN** the modal closes and the slot remains

---

### Requirement: Slots can be reordered within their category
Each slot row SHALL include up and down reorder buttons. These buttons SHALL move the slot within its category only. The up button SHALL be disabled for the first slot in a category. The down button SHALL be disabled for the last slot in a category. Reordering SHALL NOT move a slot into a different category.

#### Scenario: Up button is disabled for the first slot in a category
- **WHEN** a slot is the first in its category card
- **THEN** the up button is disabled

#### Scenario: Down button is disabled for the last slot in a category
- **WHEN** a slot is the last in its category card
- **THEN** the down button is disabled

#### Scenario: Moving a slot up swaps it with the slot above within the same category
- **WHEN** a captain clicks the up button on a slot that is not first in its category
- **THEN** the slot moves up one position within that category card

#### Scenario: Moving a slot down swaps it with the slot below within the same category
- **WHEN** a captain clicks the down button on a slot that is not last in its category
- **THEN** the slot moves down one position within that category card

---

### Requirement: Match schedule is displayed and manageable from the Match Schedule tab
**URL change only.** All behavior is unchanged from the existing `team-edit-page` spec. The match schedule section moves from `/g/:slug/teams/:id/edit` to `/g/:slug/teams/:id/settings/schedule`.

#### Scenario: Match Schedule tab loads at the correct URL
- **WHEN** a captain or owner navigates to `/g/:slug/teams/:id/settings/schedule`
- **THEN** the match schedule section renders with the team's upcoming and past matches

---

### Requirement: Captain management is accessible from the Members tab
**URL change only.** All behavior is unchanged from the existing `team-edit-page` spec. The captain management section moves from `/g/:slug/teams/:id/edit` to `/g/:slug/teams/:id/settings/members`.

#### Scenario: Members tab loads at the correct URL
- **WHEN** a captain or owner navigates to `/g/:slug/teams/:id/settings/members`
- **THEN** the captain management section renders with the current captain list and add/remove controls

---

### Requirement: Team settings page has a back navigation link to the team show page
Each settings tab SHALL display a back link to the team show page (`/g/:slug/teams/:id`).

#### Scenario: Back link is present on all tabs
- **WHEN** any settings tab renders
- **THEN** a link back to `/g/:slug/teams/:id` is visible
