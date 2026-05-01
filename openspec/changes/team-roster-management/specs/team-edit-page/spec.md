## MODIFIED Requirements

### Requirement: Team settings page has a tabbed navigation layout
The settings page SHALL render a tab bar with five tabs: General, Match Schedule, Lineup Settings, Roster, and Members. The active tab SHALL be visually distinguished. All five tabs SHALL be visible to both team captains and group owners. This requirement applies to non-pseudo teams only; pseudo-teams (`is_pseudo == true`) do not have a settings page.

#### Scenario: Tab bar renders all five tabs
- **WHEN** a captain or owner visits any team settings tab
- **THEN** the tab bar shows General, Match Schedule, Lineup Settings, Roster, and Members tabs

#### Scenario: Active tab is highlighted
- **WHEN** a user is on the Roster tab
- **THEN** the Roster tab is styled as active and the others are not

#### Scenario: Clicking a tab navigates to that tab's URL
- **WHEN** a user clicks the Roster tab
- **THEN** the user navigates to `/g/:slug/teams/:id/settings/roster`
