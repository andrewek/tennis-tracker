## ADDED Requirements

### Requirement: Roster Planner player detail modal links to player show page
The player detail modal on the Roster Planner board SHALL include a navigation link to the full player show page (`/players/:id`) for the selected player.

#### Scenario: Show page link present in modal
- **WHEN** a player card is clicked on the Roster Planner board and the player detail modal opens
- **THEN** a link to `/players/:id` for that player SHALL be visible in the modal

#### Scenario: Show page link navigates correctly
- **WHEN** the user clicks the show page link in the player detail modal
- **THEN** the browser SHALL navigate to that player's show page
