## ADDED Requirements

### Requirement: Full-bleed layout fills the viewport height
The system SHALL provide a `Layouts.full_bleed` component that constrains its content to the full viewport height (`100dvh`) using a flex column, with the navbar as a fixed-height header and `<main>` filling the remaining space without overflow or padding.

#### Scenario: Board page fits in viewport
- **WHEN** the roster planner is loaded on desktop
- **THEN** the page SHALL not extend beyond the viewport height (no page-level vertical scrollbar)

#### Scenario: Navbar remains visible
- **WHEN** the board columns are taller than the available space
- **THEN** the navbar SHALL remain fully visible at the top

### Requirement: Board columns scroll independently
Each board column's player list SHALL be independently vertically scrollable when its content exceeds the available column height.

#### Scenario: Unassigned column scrolls
- **WHEN** the Unassigned column contains more players than fit in the visible column height
- **THEN** the column SHALL show a scrollbar and allow scrolling within the column
- **THEN** other columns SHALL NOT scroll or shift in response

#### Scenario: Short columns do not show scroll
- **WHEN** a column's player list fits within the available height
- **THEN** no scrollbar SHALL appear for that column

### Requirement: Global layout padding is reduced
The `Layouts.app` `<main>` element SHALL use `py-6` (not `py-20`) to reduce excess space between the navbar and page content.

#### Scenario: Content pages have appropriate spacing
- **WHEN** any page using `Layouts.app` is rendered
- **THEN** the vertical gap between the navbar and page content SHALL be visually appropriate (not excessive)
