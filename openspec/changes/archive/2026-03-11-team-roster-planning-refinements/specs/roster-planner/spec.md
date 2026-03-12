## MODIFIED Requirements

### Requirement: Planning board syncs in real time across sessions
The system SHALL broadcast membership and team changes to all clients subscribed to the same planning context topic via `Ash.Notifier.PubSub`. All connected sessions SHALL reflect the updated board state within a short time of a change being made. Notifications are emitted automatically by the Ash resource lifecycle; the LiveView SHALL NOT manually broadcast changes.

#### Scenario: Second session sees move made in first session
- **WHEN** two browser sessions are open on the same planning context
- **AND** a player is moved in session A
- **THEN** the board in session B updates to reflect the move without a page refresh

### Requirement: New teams can be created from the planning board
The system SHALL allow users to add a new team to the current planning context via a modal form. The modal SHALL display validation errors if the team name is blank.

#### Scenario: Create new team from board
- **WHEN** a user clicks "New Team" on the planning board
- **THEN** a modal opens with a name input field
- **AND** upon valid submission, a new team column appears on the board and the modal closes

#### Scenario: Create team with blank name shows error
- **WHEN** a user submits the new team modal with a blank name
- **THEN** a validation error is shown on the name field
- **AND** no team is created
- **AND** the modal remains open

### Requirement: Unassigned column filtering is performed at the database level
The Unassigned column SHALL show only players who are eligible for the current planning context's team type and who have no membership in this context. This filtering SHALL be performed via database query, not in-memory enumeration.

#### Scenario: Unassigned column shows eligible players
- **WHEN** the planning board loads
- **THEN** the Unassigned column contains only players with no membership in this planning context who are eligible for the team type

#### Scenario: Ineligible player already assigned to a team
- **WHEN** a player's eligibility changes after they were assigned to a team
- **THEN** the player still appears in their team column
- **AND** existing RosterHealth violation indicators surface the issue
- **AND** the player does NOT appear in the Unassigned column

#### Scenario: Unrated player appears in Unassigned
- **WHEN** a player with a nil NTRP rating is age-group eligible for the planning context
- **THEN** the player appears in the Unassigned column

#### Scenario: Over-rated player is excluded from Unassigned
- **WHEN** a player has an NTRP rating above the team type's allowed levels (e.g. a 4.0-rated player for a 3.5 team)
- **THEN** the player does NOT appear in the Unassigned column
