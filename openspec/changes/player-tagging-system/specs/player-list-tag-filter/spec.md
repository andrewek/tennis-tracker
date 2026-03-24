## ADDED Requirements

### Requirement: Player list tag filter uses faceted search semantics
The player list filter SHALL support tag-based filtering using faceted search semantics: selecting multiple tags within the same category produces an OR match; having tags selected in multiple categories produces an AND match between them. A player matches the tag filter if and only if, for every category that has at least one selected tag, the player has at least one of those selected tags.

#### Scenario: Single category filter — OR semantics
- **WHEN** the user selects "Women's Leagues" and "Mixed Leagues" in the League Gender category
- **THEN** only players with at least one of those tags are shown

#### Scenario: Multi-category filter — AND semantics
- **WHEN** the user selects "40+ Eligible" in Age Group AND "Women's Leagues" in League Gender
- **THEN** only players who have the 40+ tag AND at least one of the gender tags are shown

#### Scenario: Inactive facet does not filter
- **WHEN** a category has no selected tags
- **THEN** that category imposes no constraint and all players pass it regardless of their tags in that category

### Requirement: Player list supports an exclude list (AND NOT filtering)
The player list filter SHALL support an exclude list of tags. Players who have any excluded tag SHALL be removed from the results regardless of include filters.

#### Scenario: Exclude list removes players
- **WHEN** the user adds "Sitting Out" to the exclude list
- **THEN** players with the "Sitting Out" tag do not appear in the list regardless of include filters

#### Scenario: Exclude list takes priority over show untagged
- **WHEN** "show untagged" is enabled for a facet AND a player has no tags in that category BUT does have a tag on the exclude list
- **THEN** the player is excluded — the exclude list always wins regardless of show untagged

### Requirement: Per-facet "show untagged" toggle includes players with no tags in that category
The player list tag filter SHALL have a per-facet "show untagged" toggle with the same semantics as the roster planner. When enabled, players with no tags in that specific category are included even though they do not have a matching include tag. The toggle is always rendered; it is disabled when its facet has no selected tags.

#### Scenario: Show untagged includes tag-less players for that facet
- **WHEN** the user has "40+ Eligible" selected in Age Group AND enables "show untagged" for Age Group
- **THEN** players with the "40+ Eligible" tag AND players with no Age Group tags at all are shown
- **AND** players with a different Age Group tag (e.g., "18+ Eligible" only) are still excluded

#### Scenario: Show untagged for one facet does not affect another
- **WHEN** "show untagged" is enabled for Age Group but not League Gender
- **THEN** players with no Age Group tag may appear, but players with no League Gender tag do not get special treatment from the League Gender facet

#### Scenario: Show untagged toggle is rendered but disabled when facet has no selected tags
- **WHEN** a category has no selected tags (facet inactive)
- **THEN** the "show untagged" toggle for that category is rendered in a disabled state and has no effect

#### Scenario: Show untagged toggle is enabled when facet has at least one selected tag
- **WHEN** at least one tag in a category is selected
- **THEN** the "show untagged" toggle for that category is interactive

### Requirement: Tag filter pills are grouped by category on the player list
The player list filter area SHALL display tag pills grouped by their TagCategory, with per-facet show_untagged toggle and an exclude list control. Each category SHALL be visually labeled. The existing NTRP filter pills SHALL remain unchanged alongside the tag filter groups.

**Note:** The tag filter UI is intended to match the roster planner tag filter UI as closely as possible. Start with separate components with similar code — do not attempt a single shared top-level component upfront. Shared sub-components (e.g., a single facet group, a tag pill) may be worth extracting. Evaluate whether a higher-level shared abstraction is warranted after both are built. The key contextual difference is state persistence (URL params here, session-only in the roster planner).

#### Scenario: Tag pills rendered per category
- **WHEN** the players index page is rendered
- **THEN** tag filter pills appear grouped under their category name labels

#### Scenario: NTRP filter unchanged
- **WHEN** the players index page is rendered
- **THEN** NTRP rating filter pills (2.5–5.0 and "No rating") are still present and functional alongside tag filters

### Requirement: Tag filter state is reflected in the URL using tag IDs
The full tag filter state SHALL be encoded in the player list URL so that filtered views are shareable and browser-navigable. Refreshing the page SHALL restore the same filter state. Encoding uses tag and category UUIDs throughout:

- Include tags: `tags[]=<uuid>` (one per selected tag)
- Exclude tags: `exclude[]=<uuid>` (one per excluded tag)
- Show untagged facets: `show_untagged[]=<category_uuid>` (one per category with the toggle on)

#### Scenario: Active tags appear in URL as IDs
- **WHEN** the user selects one or more tags
- **THEN** the URL is updated with `tags[]=<uuid>` params for each selected tag

#### Scenario: Exclude list appears in URL
- **WHEN** the user adds tags to the exclude list
- **THEN** the URL is updated with `exclude[]=<uuid>` params for each excluded tag

#### Scenario: Show untagged facets appear in URL
- **WHEN** the user enables "show untagged" for one or more categories
- **THEN** the URL is updated with `show_untagged[]=<category_uuid>` for each enabled category

#### Scenario: Refreshing restores filter state
- **WHEN** a user loads the player list URL with tag filter params
- **THEN** the corresponding include pills, exclude list, and show_untagged toggles are restored and the player list is filtered accordingly

#### Scenario: Tag with special characters in its name round-trips correctly
- **WHEN** the user selects a tag whose name contains special characters (e.g., "40+ Eligible", "Women's Leagues")
- **THEN** the URL encodes the tag's UUID, not its name, so no percent-encoding of the name is required and the URL remains clean

#### Scenario: Unknown tag ID in URL is ignored
- **WHEN** the URL contains a `tags[]` or `exclude[]` value that does not match any tag in the group
- **THEN** that param is silently ignored and the filter proceeds with only the valid tag IDs

### Requirement: Clear all filters resets tag selection
The existing "Clear all filters" control SHALL reset all tag filter state: include selections, exclude list, and all show_untagged toggles.

#### Scenario: Clear all resets tag filters
- **WHEN** the user clicks "Clear all filters" while tag filters are active
- **THEN** all tag filter pills are deselected, the exclude list is cleared, all show_untagged toggles are off, and the full player list is shown
