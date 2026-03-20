## ADDED Requirements

### Requirement: Page header component with title, back link, subtitle, and actions
The system SHALL provide a `<.page_header>` function component in `core_components.ex` that renders a consistent page header across all LiveViews.

The component SHALL accept:
- `title` (required attribute): the page title string
- `back_href` (optional attribute): a route path for the back link
- `back_label` (optional attribute): link text, defaults to `"Back"`
- `subtitle` (optional slot): rendered below the title
- `actions` (optional slot): rendered to the right of the title

#### Scenario: Minimal usage renders title only
- **WHEN** `<.page_header title="Players" />` is rendered
- **THEN** the page header SHALL display "Players" as the title
- **THEN** no back link SHALL be rendered
- **THEN** no subtitle or actions area SHALL be rendered

#### Scenario: Back link renders when back_href is provided
- **WHEN** `<.page_header title="Player Name" back_href={~p"/g/#{@group}/players"} />` is rendered
- **THEN** a "← Back" link SHALL appear above the title pointing to the given href

#### Scenario: Custom back label overrides default
- **WHEN** `back_label="Players"` is provided
- **THEN** the back link SHALL read "← Players"

#### Scenario: Subtitle slot renders below title
- **WHEN** a `<:subtitle>` slot is provided
- **THEN** its content SHALL render below the title in a visually subordinate style

#### Scenario: Actions slot renders alongside title
- **WHEN** an `<:actions>` slot is provided
- **THEN** its content (e.g., buttons) SHALL render to the right of the title area

### Requirement: All LiveViews use page_header consistently
Every LiveView in the application that renders a page title SHALL use `<.page_header>` rather than ad-hoc heading markup or the former `<.header>` component. The `header/1` component SHALL be deleted from `core_components.ex` once all usages are removed.

#### Scenario: No legacy header usages remain
- **WHEN** the codebase is searched for `<.header`
- **THEN** no results SHALL appear anywhere in the codebase

#### Scenario: header component is deleted
- **WHEN** the codebase is searched for `def header(`
- **THEN** no results SHALL appear in `core_components.ex`
