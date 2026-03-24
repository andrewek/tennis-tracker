## ADDED Requirements

### Requirement: Roster planner unassigned pool shows all unassigned players
The roster planner Unassigned column SHALL show all players who have no membership in the current planning context (regardless of age group, gender league, or other eligibility tags). Tag filtering narrows this pool but does not define eligibility. The NTRP-based health check system continues to flag players whose NTRP rating is outside allowed levels.

#### Scenario: All unassigned players are shown with no tag filter active
- **WHEN** the planning board loads and no tag filter is active
- **THEN** all players with no membership in this context appear in the Unassigned column

#### Scenario: Player with no tags appears when no filter active
- **WHEN** a player has no tags assigned and no tag filter is active
- **THEN** the player appears in the Unassigned column

### Requirement: Roster planner tag filter uses faceted search semantics applied at the DB level
The planning board tag filter (applied to the Unassigned column) SHALL use the same faceted search semantics as the player list: OR within a category, AND between categories. The filter SHALL be applied at the database level via Ash query — not by loading all players and filtering in Elixir. When the filter state changes, the system re-queries the DB with the updated filter.

**Note:** The tag filter UI is intended to match the player list tag filter UI as closely as possible. Start with separate components with similar code — do not attempt a single shared top-level component upfront. Shared sub-components (e.g., a single facet group, a tag pill) may be worth extracting. Evaluate whether a higher-level shared abstraction is warranted after both are built. The key contextual difference is state persistence (session-only here, URL params in the player list).

#### Scenario: Single category OR filter
- **WHEN** the captain selects "Women's Leagues" and "Mixed Leagues" in the League Gender facet
- **THEN** only players with at least one of those tags appear in Unassigned

#### Scenario: Multi-category AND filter
- **WHEN** the captain selects "40+ Eligible" in Age Group AND "Women's Leagues" in League Gender
- **THEN** only players matching both facets appear in Unassigned

#### Scenario: Inactive facet does not filter
- **WHEN** a category has no selected tags
- **THEN** that category imposes no constraint on the Unassigned column

### Requirement: Per-facet "show untagged" toggle includes players with no tags in that category
The planner tag filter SHALL have a per-facet "show untagged" toggle for every category. When enabled, players with no tags in that specific category are included in the results even though they do not have a matching include tag. The toggle is always rendered for every category; it is disabled (non-interactive) when its facet has no selected tags.

**State persistence:** The `show_untagged` value for a facet persists in session state even when the facet becomes inactive (i.e., its last tag is deselected). If a captain re-activates a facet by selecting a tag, the previous `show_untagged` value is restored and the toggle becomes interactive again. On page refresh, all `show_untagged` toggles reset to false (they are not persisted in the database).

#### Scenario: Show untagged includes tag-less players for that facet
- **WHEN** the captain has "40+ Eligible" selected in Age Group AND enables "show untagged" for Age Group
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

### Requirement: Roster planner tag filter state is session-only and resets on refresh
The tag filter state in the roster planner SHALL be stored only in the LiveView socket assigns (not in the database). Each browser session maintains its own independent filter state. Refreshing the page resets the filter to the defaults from the current season rules.

#### Scenario: Filter state is per-session
- **WHEN** captain A changes the tag filter on the planning board
- **THEN** captain B viewing the same board is unaffected

#### Scenario: Page refresh resets filter to defaults
- **WHEN** a captain modifies the tag filter and then refreshes the page
- **THEN** the filter is reset to the defaults from season_rules.default_tags

#### Scenario: No season rules means no default filter
- **WHEN** no SeasonRules record exists for the current context
- **THEN** the planning board opens with no tag filter active (all unassigned players shown)

### Requirement: Season rules default tags drive the initial tag filter
When a planning board session opens, the tag filter SHALL be pre-populated from the `default_tags` associated with the current SeasonRules record. Tags are grouped into include facets by their category. The `show_untagged` toggle defaults to false for all facets.

#### Scenario: Default tags pre-populate include facets
- **WHEN** the planning board loads for a context with SeasonRules that have default_tags
- **THEN** the tag filter include facets are pre-populated with those tags, grouped by category

#### Scenario: show_untagged is always false by default
- **WHEN** the planning board loads
- **THEN** all per-facet show_untagged toggles are off regardless of default_tags configuration
