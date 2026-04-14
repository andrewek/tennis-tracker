## ADDED Requirements

### Requirement: Prev/next navigation in the lineup editor header
The lineup editor SHALL display forward and backward navigation controls that move between a team's matches in date order.

#### Scenario: Both buttons shown for a middle match
- **GIVEN** a team has three or more matches and the captain is editing a match that is neither first nor last
- **WHEN** the lineup editor is open
- **THEN** both a "← Prev" and a "→ Next" control SHALL be visible in the header

#### Scenario: Prev control absent on the first match
- **GIVEN** the captain is editing the team's first match (earliest by date)
- **WHEN** the lineup editor is open
- **THEN** no "← Prev" control SHALL be rendered

#### Scenario: Next control absent on the last match
- **GIVEN** the captain is editing the team's last match (latest by date)
- **WHEN** the lineup editor is open
- **THEN** no "→ Next" control SHALL be rendered

#### Scenario: Neither control shown when team has only one match
- **GIVEN** the team has exactly one match
- **WHEN** the lineup editor is open
- **THEN** neither a Prev nor a Next control SHALL be rendered

---

### Requirement: Navigation moves to the correct adjacent match
Clicking Prev or Next SHALL navigate to the adjacent match's lineup editor.

#### Scenario: Prev navigates to the immediately preceding match by date
- **GIVEN** a captain is editing match B and match A immediately precedes it by date
- **WHEN** the captain clicks "← Prev"
- **THEN** the lineup editor SHALL load for match A

#### Scenario: Next navigates to the immediately following match by date
- **GIVEN** a captain is editing match B and match C immediately follows it by date
- **WHEN** the captain clicks "→ Next"
- **THEN** the lineup editor SHALL load for match C

---

### Requirement: Navigation resets transient editor state
Navigation to an adjacent match is a full LiveView remount; state that is not persisted in the URL resets.

#### Scenario: Stats drawer closes on navigation
- **GIVEN** the stats drawer is open while editing match B
- **WHEN** the captain navigates to match C via the Next control
- **THEN** the stats drawer SHALL be closed on the new match
