## ADDED Requirements

### Requirement: SeasonRules can have default tags for the roster planner
A `SeasonRules` record SHALL support a many-to-many relationship with `Tag` via `SeasonRulesDefaultTag`. These tags represent the pre-selected tag filter state when a captain opens a roster planner session for this (team_type, season_year) context. Default tags are optional; a SeasonRules record with no default tags opens the planner with no tag filter active.

#### Scenario: Default tags are loaded with season rules
- **WHEN** a SeasonRules record is loaded for a planning context
- **THEN** its default_tags relationship returns the associated Tag records with their categories loaded

#### Scenario: SeasonRules with no default tags loads planner with no filter
- **WHEN** a SeasonRules record has no SeasonRulesDefaultTag records
- **THEN** the planner opens with no tag filter active and all unassigned players are shown

#### Scenario: SeasonRules with default tags pre-populates planner filter
- **WHEN** a SeasonRules record has default_tags set
- **THEN** the planner opens with those tags pre-selected in the include facets, grouped by category

### Requirement: SeasonRules default tags can be managed on the season rules form
The season rules create/edit form SHALL include a tag picker for selecting default tags, grouped by TagCategory. Group owners SHALL be able to add and remove default tags from a SeasonRules record.

#### Scenario: Owner sets default tags on season rules
- **WHEN** a group owner selects tags in the tag picker on the season rules form and saves
- **THEN** SeasonRulesDefaultTag records are created for those tags

#### Scenario: Owner clears default tags
- **WHEN** a group owner removes all tags from the tag picker and saves
- **THEN** all SeasonRulesDefaultTag records for that SeasonRules are destroyed and the planner opens with no filter

### Requirement: Destroying a tag removes it from SeasonRules default tags
When a Tag is destroyed, all SeasonRulesDefaultTag records referencing it SHALL be destroyed via cascade, as specified in the tag-management capability.

#### Scenario: Deleted tag is removed from season rules defaults
- **WHEN** a tag referenced by one or more SeasonRulesDefaultTag records is destroyed
- **THEN** those SeasonRulesDefaultTag records are destroyed
- **AND** the next time the planner opens for affected contexts, the deleted tag is not pre-selected
