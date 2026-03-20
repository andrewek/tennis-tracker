## Requirements

### Requirement: Single unified layout using daisyUI drawer
The system SHALL provide a single `Layouts.app` component that uses the daisyUI `drawer` pattern as its structural foundation, replacing both the former `Layouts.app` and `Layouts.full_bleed` components.

#### Scenario: Layout renders on a group-scoped page
- **WHEN** any group-scoped LiveView renders using `<Layouts.app>`
- **THEN** the page SHALL display a sidebar and a scrollable content area side by side

#### Scenario: Layout renders on a non-group page
- **WHEN** a LiveView without `current_group` (e.g., `/groups` index) renders using `<Layouts.app>`
- **THEN** the layout SHALL render without crashing, omitting group-specific nav links

### Requirement: Sidebar is always visible on large screens
The sidebar SHALL be permanently expanded on screens at the `lg` breakpoint and above via `lg:drawer-open`.

#### Scenario: Desktop sidebar is visible without interaction
- **WHEN** the page is viewed on a screen wider than `lg` (1024px)
- **THEN** the sidebar SHALL be visible without the user needing to open it

### Requirement: Sidebar becomes a drawer overlay on mobile
On screens below `lg`, the sidebar SHALL be hidden by default and openable as an overlay drawer via a hamburger toggle button in the mobile top bar.

#### Scenario: Mobile sidebar is hidden by default
- **WHEN** the page is viewed on a screen narrower than `lg`
- **THEN** the sidebar SHALL NOT be visible
- **THEN** a sticky top bar with a hamburger button SHALL be visible

#### Scenario: Mobile drawer opens on tap
- **WHEN** the user taps the hamburger button in the mobile top bar
- **THEN** the sidebar SHALL slide in as an overlay drawer

#### Scenario: Mobile drawer closes on overlay tap
- **WHEN** the drawer is open and the user taps the dimmed overlay area
- **THEN** the drawer SHALL close

### Requirement: Sidebar displays current group name
The sidebar SHALL prominently display the name of the currently active group.

#### Scenario: Group name is shown
- **WHEN** a group-scoped page is loaded
- **THEN** the sidebar SHALL display the current group's name

### Requirement: Sidebar contains primary navigation links
The sidebar SHALL contain navigation links for Players, Teams, and Roster Planning, all scoped to the current group slug.

#### Scenario: Nav links are present
- **WHEN** a group-scoped page is loaded
- **THEN** the sidebar SHALL contain links to `/g/:group_slug/players`, `/g/:group_slug/teams`, and `/g/:group_slug/roster-planner`

### Requirement: Sidebar contains utility links
The sidebar SHALL contain a "Switch Organization" link, a theme toggle, and a "Sign out" link. An "Admin" link SHALL be shown only to system admin users.

#### Scenario: Standard user sees utility links
- **WHEN** a non-admin authenticated user views the sidebar
- **THEN** the sidebar SHALL contain "Switch Organization" (→ `/groups`), the theme toggle, and "Sign out"
- **THEN** the sidebar SHALL NOT contain an "Admin" link

#### Scenario: Admin user sees admin link
- **WHEN** a system admin user views the sidebar
- **THEN** the sidebar SHALL additionally contain an "Admin" link (→ `/admin`)

### Requirement: Content area fills remaining viewport height and is scrollable
The main content area SHALL fill the remaining viewport height after the sidebar and be independently scrollable (`overflow-y-auto`).

#### Scenario: Long page content scrolls within content area
- **WHEN** a page with content taller than the viewport is rendered
- **THEN** the content area SHALL scroll independently
- **THEN** the sidebar SHALL remain fixed and visible

### Requirement: Layout respects light and dark mode
The sidebar and layout SHALL respect the active daisyUI theme (light/dark/system).

#### Scenario: Dark mode applies to sidebar
- **WHEN** the user selects dark mode
- **THEN** the sidebar SHALL render with appropriate dark theme colors

### Requirement: Mobile top bar shows context name
The sticky mobile top bar SHALL display the current group name alongside the hamburger button when a group is active. When no group is active (e.g., the `/groups` index or home page), the top bar SHALL display the app name ("Tennis Tracker") instead.

#### Scenario: Group name visible on mobile when group is active
- **WHEN** the page is viewed on a mobile screen with a current group assigned
- **THEN** the top bar SHALL display the current group's name

#### Scenario: App name shown on mobile when no group is active
- **WHEN** the page is viewed on a mobile screen with no current group (e.g., `/groups` index)
- **THEN** the top bar SHALL display "Tennis Tracker" instead of a group name
