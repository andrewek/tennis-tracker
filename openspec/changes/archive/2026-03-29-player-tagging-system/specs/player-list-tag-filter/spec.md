## ADDED Requirements

### Requirement: Player list tag filter uses faceted search semantics
The player list filter SHALL support tag-based filtering using faceted search semantics: selecting multiple tags within the same category produces an OR match; having tags selected in multiple categories produces an AND match between them. A player matches the tag filter if and only if, for every category that has at least one selected tag, the player has at least one of those selected tags.

#### Scenario: Single category filter — OR semantics
- **WHEN** the user selects "Women's Leagues" and "Mixed Leagues" in the League Gender category
- **THEN** only players with at least one of those tags are shown

#### Scenario: Multi-category filter — AND semantics
- **WHEN** the user selects "40+" in Age Group AND "Women's Leagues" in League Gender
- **THEN** only players who have the 40+ tag AND at least one of the gender tags are shown

#### Scenario: Inactive facet does not filter
- **WHEN** a category has no selected tags
- **THEN** that category imposes no constraint and all players pass it regardless of their tags in that category

### Requirement: Per-facet "show untagged" toggle includes players with no tags in that category
The player list tag filter SHALL have a per-facet "show untagged" toggle. When enabled, players with no tags in that specific category are included even though they do not have a matching include tag. The toggle is always rendered for every category; it is disabled (non-interactive) when its facet has no selected tags.

**State persistence:** The `show_untagged` value for a facet persists in socket state even when the facet becomes inactive (i.e., its last tag is deselected). If a captain re-activates a facet by selecting a tag, the previous `show_untagged` value is restored and the toggle becomes interactive again. `show_untagged` is NOT encoded in the URL — it is transient UI state that resets on page load.

#### Scenario: Show untagged includes tag-less players for that facet
- **WHEN** the user has "40+" selected in Age Group AND enables "show untagged" for Age Group
- **THEN** players with the "40+" tag AND players with no Age Group tags at all are shown
- **AND** players with a different Age Group tag (e.g., "18+" only) are still excluded

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
The player list filter area SHALL display tag pills grouped by their TagCategory, with a per-facet show_untagged toggle. Each category SHALL be visually labeled. The existing NTRP filter pills SHALL remain unchanged alongside the tag filter groups.

**Note:** The tag filter UI is intended to match the roster planner tag filter UI as closely as possible. Start with separate components with similar code — do not attempt a single shared top-level component upfront. Shared sub-components (e.g., a single facet group, a tag pill) may be worth extracting. Evaluate whether a higher-level shared abstraction is warranted after both are built. The key contextual difference is state persistence (URL params here, session-only in the roster planner).

#### Scenario: Tag pills rendered per category
- **WHEN** the players index page is rendered
- **THEN** tag filter pills appear grouped under their category name labels

#### Scenario: NTRP filter unchanged
- **WHEN** the players index page is rendered
- **THEN** NTRP rating filter pills (2.5–5.0 and "No rating") are still present and functional alongside tag filters

### Requirement: Tag filter state is reflected in the URL using tag IDs
The include tag selection SHALL be encoded in the player list URL so that filtered views are shareable and browser-navigable. Refreshing the page SHALL restore the same include selection. Only include tags are URL-encoded; `show_untagged` state is transient and resets on page load.

- Include tags: `tags[]=<uuid>` (one per selected tag)

#### Scenario: Active tags appear in URL as IDs
- **WHEN** the user selects one or more tags
- **THEN** the URL is updated with `tags[]=<uuid>` params for each selected tag

#### Scenario: Refreshing restores include tag selection
- **WHEN** a user loads the player list URL with `tags[]` params
- **THEN** the corresponding include pills are restored and the player list is filtered accordingly
- **AND** all `show_untagged` toggles start as off (they are not URL-encoded)

#### Scenario: Tag with special characters in its name round-trips correctly
- **WHEN** the user selects a tag whose name contains special characters (e.g., "40+", "Women's Leagues")
- **THEN** the URL encodes the tag's UUID, not its name, so no percent-encoding of the name is required and the URL remains clean

#### Scenario: Unknown tag ID in URL is ignored
- **WHEN** the URL contains a `tags[]` value that does not match any tag in the group
- **THEN** that param is silently ignored and the filter proceeds with only the valid tag IDs

### Requirement: Clear all filters resets tag selection
The existing "Clear all filters" control SHALL reset all tag filter state: include selections and all show_untagged toggles.

#### Scenario: Clear all resets tag filters
- **WHEN** the user clicks "Clear all filters" while tag filters are active
- **THEN** all tag filter pills are deselected, all show_untagged toggles are off, and the full player list is shown
