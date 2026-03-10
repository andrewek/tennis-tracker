## ADDED Requirements

### Requirement: Navbar shows Tennis Tracker home link
The navbar SHALL display a "Tennis Tracker" text link that navigates to `/`.

#### Scenario: Home link is visible
- **WHEN** any page is loaded that uses the app layout
- **THEN** the navbar SHALL contain a link labeled "Tennis Tracker" that points to `/`

### Requirement: Navbar shows Players link
The navbar SHALL display a "Players" navigation link that navigates to `/players`.

#### Scenario: Players link is visible
- **WHEN** any page is loaded that uses the app layout
- **THEN** the navbar SHALL contain a link labeled "Players" that points to `/players`

### Requirement: Navbar contains only app links and theme toggle
The navbar SHALL NOT contain external links (e.g., Phoenix website, GitHub, "Get Started" button).

#### Scenario: No external links
- **WHEN** any page is loaded that uses the app layout
- **THEN** the navbar SHALL contain only the home link, the Players link, and the theme toggle control

### Requirement: Navbar includes theme toggle
The navbar SHALL include the existing light/dark/system theme toggle.

#### Scenario: Theme toggle is present
- **WHEN** any page is loaded that uses the app layout
- **THEN** the three-button theme toggle (system/light/dark) SHALL be visible in the navbar
