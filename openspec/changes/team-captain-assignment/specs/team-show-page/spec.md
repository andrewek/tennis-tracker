## ADDED Requirements

### Requirement: Team show page includes a read-only Captains section
The team show page SHALL include a read-only "Captains" section visible to all group members. The section SHALL list all current captains (users with a `:captain` TeamRole for this team) by display name (name if present, email otherwise). No add or remove controls are rendered.

#### Scenario: Any group member sees the Captains section
- **WHEN** a user with any GroupMembership role visits the team show page
- **THEN** the Captains section is rendered with the current captain list
- **AND** no add or remove controls are present

#### Scenario: Empty captains list shows an empty state
- **WHEN** the team has no `:captain` TeamRole records
- **THEN** the Captains section shows a message indicating no captains are assigned
