## Requirements

### Requirement: Home page displays a branded card grid
The home page at `/` SHALL display a responsive grid of card-style navigation links for Players, Teams, Winter Tennis, and Roster Planner.

#### Scenario: Four cards are visible
- **WHEN** the home page is loaded
- **THEN** four cards labeled "Players", "Teams", "Winter Tennis", and "Roster Planner" SHALL be visible

#### Scenario: Players card links to /players
- **WHEN** the user clicks the "Players" card
- **THEN** the user SHALL be navigated to `/players`

#### Scenario: Roster Planner card links to /roster-planner
- **WHEN** the user clicks the "Roster Planner" card
- **THEN** the user SHALL be navigated to `/roster-planner`

#### Scenario: Teams card has no active destination
- **WHEN** the Teams card is rendered
- **THEN** it SHALL be rendered as a non-functional link (e.g., `href="#"` or no navigation occurs)

#### Scenario: Winter Tennis card has no active destination
- **WHEN** the Winter Tennis card is rendered
- **THEN** it SHALL be rendered as a non-functional link (e.g., `href="#"` or no navigation occurs)

### Requirement: Home page card grid is responsive
The card grid SHALL adapt to different screen sizes.

#### Scenario: Single column on small screens
- **WHEN** the home page is rendered at mobile viewport widths
- **THEN** the cards SHALL stack in a single column

#### Scenario: Multi-column on larger screens
- **WHEN** the home page is rendered at tablet or desktop viewport widths
- **THEN** the cards SHALL display in a multi-column grid layout

### Requirement: Home page cards have a hover effect
Each card SHALL have a visible hover effect that provides feedback to the user.

#### Scenario: Card responds to hover
- **WHEN** the user hovers over a card
- **THEN** the card SHALL visually change (e.g., scale, background shift, or shadow) to indicate interactivity

### Requirement: Home page has a subtle abstract background
The home page SHALL include a decorative abstract background (e.g., SVG shapes or CSS gradients) that is low-key and does not obscure content.

#### Scenario: Background visible in light mode
- **WHEN** the home page is rendered with light theme active
- **THEN** the abstract background SHALL be visible and complement the light color scheme

#### Scenario: Background visible in dark mode
- **WHEN** the home page is rendered with dark theme active
- **THEN** the abstract background SHALL be visible and complement the dark color scheme without harsh contrast

### Requirement: Home page includes a link to the admin panel
The home page SHALL display a link or card navigating to `/admin`. The link SHALL be visible to all users; access control is enforced by the admin panel itself.

#### Scenario: Admin panel link is present on home page
- **WHEN** the home page is loaded
- **THEN** a link or card navigating to `/admin` SHALL be visible
