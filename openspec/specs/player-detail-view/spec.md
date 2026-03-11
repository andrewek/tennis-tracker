## Requirements

### Requirement: Player show page has prominent name and NTRP hero section
The player show page SHALL display the player's name and NTRP rating prominently as an H1-level hero section at the top of the page content.

#### Scenario: Name displayed as H1
- **WHEN** a player show page is rendered
- **THEN** the player's name SHALL be displayed in an `<h1>` element (or equivalent large heading) that is visually dominant on the page

#### Scenario: NTRP rating displayed prominently
- **WHEN** a player show page is rendered
- **THEN** the player's NTRP rating SHALL be displayed in the hero section alongside the name, at a size and weight that makes it immediately noticeable

### Requirement: Player show page displays age brackets as chips in the sub-header
The player show page SHALL display the player's eligible age brackets as small badge chips below the name/NTRP hero heading, before the detail list.

#### Scenario: Eligible brackets shown as chips
- **WHEN** a player is eligible for one or more age brackets
- **THEN** each eligible bracket (18+, 40+, 55+) SHALL be rendered as a small badge chip in the sub-header area

#### Scenario: No chips for ineligible brackets
- **WHEN** a player is not eligible for a given age bracket
- **THEN** that bracket's chip SHALL NOT appear in the sub-header

#### Scenario: Player with no brackets shows no sub-header chips
- **WHEN** a player has no age bracket eligibility
- **THEN** no chips SHALL appear in the sub-header area

### Requirement: Player show page displays team membership history section
The player show page SHALL display a team membership history section below the existing player detail information.

#### Scenario: Team membership section renders
- **WHEN** a player show page is rendered
- **THEN** a team membership history section SHALL be present on the page

#### Scenario: Memberships listed in correct order
- **WHEN** the player has non-pseudo team memberships
- **THEN** each membership SHALL appear as a line formatted as "YYYY TT - TN" (year, team type name, team name), ordered newest season first
