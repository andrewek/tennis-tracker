## Requirements

### Requirement: Match show page renders a read-only lineup section
The match show page SHALL include a read-only lineup section below the match details. This section shows current slot assignments as a static list; the drag-and-drop editing board lives at `/matches/:id/lineup-edit`.

#### Scenario: Lineup section present on match show page
- **WHEN** any group member navigates to a match show page
- **THEN** a lineup section SHALL be rendered on the page showing current assignments in slot sort_order

#### Scenario: Captains see an "Edit Lineup" link
- **WHEN** a captain views the match show page and the team has lineup slots defined
- **THEN** the lineup section SHALL include a link to `/matches/:id/lineup-edit`

#### Scenario: Non-captains do not see the "Edit Lineup" link
- **WHEN** a regular group member views the match show page
- **THEN** no link to the lineup edit page SHALL be rendered

#### Scenario: Copy Lineup button visible to all members
- **WHEN** any group member views the match show page
- **THEN** the Copy Lineup button SHALL be visible regardless of role

#### Scenario: Lineup section shows empty state for teams with no slots — captain view
- **WHEN** the match's team has no lineup slots defined and the viewer is a captain
- **THEN** the lineup section SHALL show an empty state with a link to the team edit page to define slots

#### Scenario: Lineup section shows empty state for teams with no slots — non-captain view
- **WHEN** the match's team has no lineup slots defined and the viewer is a regular group member
- **THEN** the lineup section SHALL show an empty state message without a link to the team edit page
