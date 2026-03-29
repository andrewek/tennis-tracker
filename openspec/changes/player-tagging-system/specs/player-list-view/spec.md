## REMOVED Requirements

### Requirement: Players list displays age brackets as inline chips
**Reason**: Age bracket eligibility is no longer stored as boolean attributes on Player. It is now represented by tags (e.g., "40+" in the Age Group category). Tag chips replace bracket chips.
**Migration**: Display assigned tags as inline chips next to the player's name on the index table, grouped or labeled by category if space allows. See the `player-tagging` and `player-list-tag-filter` capabilities for the replacement behavior.

## ADDED Requirements

### Requirement: Players list displays assigned tags as inline chips
The players index table SHALL display a player's assigned tags as inline badge chips next to the player's name. Tags SHALL be visually compact. Not all tags need to be shown if space is limited; a truncation or overflow indicator is acceptable.

#### Scenario: Player with tags shows tag chips
- **WHEN** a player has one or more tags assigned
- **THEN** tag chips appear next to the player's name in the table row

#### Scenario: Player with no tags shows no chips
- **WHEN** a player has no tags assigned
- **THEN** no tag chips are displayed for that player

#### Scenario: No age bracket boolean columns in table
- **WHEN** the players index page is rendered
- **THEN** the table SHALL NOT have columns or chips for "18+ Eligible?", "40+ Eligible?", or "55+ Eligible?" derived from boolean fields (those fields no longer exist)
