## Why

Players have diverse and overlapping eligibility profiles — age groups they prefer, gender leagues they compete in, NTRP stretch eligibility, availability constraints, captaining interest, and recruitment pipeline status — that cannot be expressed cleanly with a fixed set of boolean fields. The current `eligible_18_plus/40_plus/55_plus` fields are too rigid: they don't cover 65+ or 70+ leagues, can't express "mixed leagues only," and have no way to flag a player as a prospect or on medical hold. A flexible, group-owner-managed tagging system replaces these booleans and provides a general-purpose grouping mechanism for the full range of real-world player situations.

## What Changes

- **BREAKING**: Remove `eligible_18_plus`, `eligible_40_plus`, `eligible_55_plus` from the `Player` schema
- Add `TagCategory` and `Tag` Ash resources (group-scoped, owner-managed)
- Add `PlayerTag` join resource linking players to tags
- Add `SeasonRulesDefaultTag` join resource for per-season default filter presets
- Seed each group with a preset tag taxonomy (Age Group, League Gender, NTRP, Availability, Role, Pipeline)
- Replace age bracket filter pills on the player list with tag-based faceted filtering
- Add tag management UI under group settings
- Add tag assignment to player edit page; tag display to player show page
- Update roster planner to list all unassigned players with a session-state faceted tag filter (replacing hard eligibility filtering)
- Remove boolean columns from CSV import; defer tag CSV support to a future change
- Reset the database (no migration; only seed data exists)

## Capabilities

### New Capabilities

- `tag-management`: Group owners can create, rename, and delete tag categories and tags; categories cascade-delete their tags; deletions cascade through player and season-rules join records; a preset taxonomy is seeded for each new group
- `player-tagging`: Players can have zero or more tags assigned; tags are grouped by category; tag assignment happens on the player edit page; tags are displayed on the player show page
- `player-list-tag-filter`: The player list replaces age bracket filter pills with a tag-based faceted filter; OR within a category, AND between categories; filter state is reflected in the URL
- `roster-planner-tag-filter`: The roster planner moves to listing all unassigned players with a session-state faceted tag filter; facets use OR-within / AND-between semantics; a per-facet "show untagged" toggle (always rendered, disabled when facet is inactive); exclude list for AND NOT filtering; defaults come from `SeasonRules.default_tags`; state is per-browser-session and resets on page refresh

### Modified Capabilities

- `player-list-view`: Age bracket filter pills replaced by tag facet filter; URL param shape changes
- `player-csv-export`: Remove `eligible_18_plus`, `eligible_40_plus`, `eligible_55_plus` columns
- `roster-planner`: Unassigned pool changes from eligibility-filtered to all-players with session tag filter; `SeasonRules` default tags drive initial filter state
- `season-rules`: Adds `default_tags` many-to-many relationship via `SeasonRulesDefaultTag`; season rules edit form gains a tag picker for defaults

## Impact

- **Ash resources**: New `TagCategory`, `Tag`, `PlayerTag`, `SeasonRulesDefaultTag`; modified `Player`, `SeasonRules`
- **Domain functions**: New functions for tag/category CRUD, player tag management, fetching tags for a group
- **LiveViews**: `Players.IndexLive` (filter change), `Players.FormLive` (tag assignment), `Players.ShowLive` (tag display), `RosterPlannerLive` (new filter model), new settings LiveViews for tag management, `SeasonRules` form (tag picker)
- **PlayerFilters**: `maybe_filter_bracket/2` replaced with tag-based filter logic
- **PlayerCsvImport**: Remove three boolean columns from `@known_columns`
- **Seeds**: Updated to use tag assignments instead of boolean fields; preset taxonomy seeded per group
- **Database**: Full reset (no migration); `mix ecto.reset` after implementation
