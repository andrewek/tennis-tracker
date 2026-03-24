## MODIFIED Requirements

### Requirement: Unassigned column filtering is performed at the database level
The Unassigned column SHALL show all players who have no membership in the current planning context. This pool is then narrowed by the session-state tag filter (see `roster-planner-tag-filter`). Hard eligibility filtering based on age bracket boolean fields is removed. NTRP-based health check violations continue to surface non-blocking warnings when players are placed on teams.

#### Scenario: Unassigned column shows all players with no membership in this context
- **WHEN** the planning board loads with no tag filter active
- **THEN** the Unassigned column contains all players who have no TeamMembership record for this planning context, regardless of age group, gender league, or other tag attributes

#### Scenario: Tag filter narrows the unassigned pool
- **WHEN** the captain has an active tag filter
- **THEN** the Unassigned column shows only players matching the tag filter (see roster-planner-tag-filter spec)

#### Scenario: Ineligible player already assigned to a team
- **WHEN** a player is assigned to a team
- **THEN** the player still appears in their team column
- **AND** existing RosterHealth violation indicators surface any NTRP issues
- **AND** the player does NOT appear in the Unassigned column

#### Scenario: Unrated player appears in Unassigned
- **WHEN** a player with a nil NTRP rating has no membership in this context
- **THEN** the player appears in the Unassigned column (subject to tag filter)

#### Scenario: Player with no tags appears in Unassigned when no filter active
- **WHEN** a player has no tags and no tag filter is active
- **THEN** the player appears in the Unassigned column
