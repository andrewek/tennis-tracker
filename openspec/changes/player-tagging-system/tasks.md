## 1. Ash Resources — TagCategory and Tag

- [ ] 1.1 Create `TennisTracker.Tennis.TagCategory` Ash resource (name, group_id, timestamps; unique name per group; group member read, group owner write policies; multitenancy)
- [ ] 1.2 Create `TennisTracker.Tennis.Tag` Ash resource (name, tag_category_id, group_id, timestamps; unique name+category per group; group member read, group owner write policies; multitenancy)
- [ ] 1.3 Add `has_many :tags` relationship to TagCategory; add `belongs_to :tag_category` to Tag
- [ ] 1.4 Create `TennisTracker.Tennis.PlayerTag` join Ash resource (player_id, tag_id, group_id; no timestamps; group member read, group owner create/destroy; multitenancy)
- [ ] 1.5 Create `TennisTracker.Tennis.SeasonRulesDefaultTag` join Ash resource (season_rules_id, tag_id, group_id; no timestamps; group member read, group owner create/destroy; cascade destroy when tag deleted; multitenancy)
- [ ] 1.6 Add `many_to_many :tags` to Player through PlayerTag; add `many_to_many :default_tags` to SeasonRules through SeasonRulesDefaultTag
- [ ] 1.7 Add `many_to_many :players` inverse on Tag through PlayerTag (for cascade destroy support)
- [ ] 1.8 Register TagCategory, Tag, PlayerTag, SeasonRulesDefaultTag in the Tennis domain
- [ ] 1.9 Add domain functions to Tennis domain: `list_tag_categories!/1`, `create_tag_category/2`, `update_tag_category/2`, `destroy_tag_category/2`, `list_tags_for_category!/2`, `create_tag/2`, `update_tag/2`, `destroy_tag/2`, `add_player_tag/3`, `remove_player_tag/3`

## 2. Player Schema Changes

- [ ] 2.1 Remove `eligible_18_plus`, `eligible_40_plus`, `eligible_55_plus` attributes from `Player` resource
- [ ] 2.2 Remove these fields from Player's create and update action `accept` lists
- [ ] 2.3 Remove `@boolean_columns` and all `coerce_field` clauses for these three fields from `PlayerCsvImport`
- [ ] 2.4 Remove `eligible_18_plus`, `eligible_40_plus`, `eligible_55_plus` from `@known_columns` in `PlayerCsvImport`
- [ ] 2.5 Remove the CSV export columns for these three fields from the export controller/module

## 3. Cascade Delete Behaviour

- [ ] 3.1 Implement cascade destroy: destroying a TagCategory destroys all its Tags (via Ash destroy action or `on_delete: :delete_all` in postgres block)
- [ ] 3.2 Implement cascade destroy: destroying a Tag destroys all its PlayerTag records
- [ ] 3.3 Implement cascade destroy: destroying a Tag destroys all its SeasonRulesDefaultTag records

## 4. Preset Taxonomy Seeding

- [ ] 4.1 Create a `Tennis.seed_preset_tags!/1` domain function (or equivalent) that creates the preset TagCategories and Tags for a given group_id
- [ ] 4.2 ~~Trigger preset tag seeder on group creation~~ — **DEFERRED**: automatic seeding on group creation is out of scope; new groups are seeded via seeds file (local dev) or iex/AshAdmin (production)
- [ ] 4.3 Update `priv/repo/seeds.exs` to remove boolean field assignments; call the preset seeder for each seeded group
- [ ] 4.4 Update seeds to assign realistic tags to seeded players using the preset taxonomy

## 5. Database Reset and Migration

- [ ] 5.1 Generate Ash migrations: `mix ash_postgres.generate_migrations --name add_player_tagging_system`
- [ ] 5.2 Run `mix ecto.reset` and verify seeds run cleanly

## 6. PlayerFilters — Tag-Based Filtering

- [ ] 6.1 Replace `maybe_filter_bracket/2` in `PlayerFilters` with `maybe_filter_tags/2` implementing full faceted search: OR within category (include), AND between categories, exclude list (AND NOT), and per-facet show_untagged
- [ ] 6.2 Update `fetch_players/4` signature to accept `tag_filter` param (`%{include: %{category_id => [tag_id]}, exclude: [tag_id], show_untagged: [category_id]}`) in place of `bracket_filter`
- [ ] 6.3 Implement `maybe_filter_tags` at the DB level via Ash.Query (not Elixir-side); this same filter logic is also used by `list_unassigned_players` in the roster planner — consider extracting a shared query-builder function

## 7. Player List LiveView — Tag Filter UI

The player list tag filter UI shall match the roster planner tag filter UI as closely as possible (same faceted pills, per-facet show_untagged toggle, exclude list). Start with separate components with similar code — do not attempt a single shared top-level component upfront. Shared sub-components (e.g., a facet group, a tag pill) may be worth extracting; evaluate after both are built. The only fundamental difference is state persistence: URL params here, session-only in the planner.

- [ ] 7.1 Load all TagCategories and Tags for the group in `Players.IndexLive.mount/3`
- [ ] 7.2 Replace `@bracket_options` / `bracket_filter` assigns with `@tag_categories` / `tag_filter` assign: `%{include: %{category_id => [tag_id]}, exclude: [tag_id], show_untagged: [category_id]}`
- [ ] 7.3 Replace age bracket filter pills in the template with tag category groups, each with per-tag toggle pills, per-facet show_untagged toggle (always rendered, disabled when facet inactive), and an exclude list control
- [ ] 7.4 Update `handle_event("toggle_bracket", ...)` → `handle_event("toggle_tag", ...)` and add `handle_event("toggle_exclude", ...)` and `handle_event("toggle_show_untagged", ...)`
- [ ] 7.5 Update `filter_url/2` to encode full tag filter state: `tags[]=<uuid>` for include, `exclude[]=<uuid>` for excluded tags, `show_untagged[]=<category_uuid>` for active show_untagged facets
- [ ] 7.6 Update `handle_params/3` to parse all three param groups back into the tag_filter map; resolve IDs against loaded `@tag_categories`; silently ignore unrecognized IDs
- [ ] 7.7 ~~Update `export_url/4` to pass tag filter params through to the CSV export endpoint~~ — **DEFERRED**: tag filter passthrough to CSV export is a fast-follow; remove any bracket param from the export URL but do not add tag params
- [ ] 7.8 Update "Clear all filters" to reset all tag_filter state: include, exclude, and show_untagged

## 8. Player List — Tag Chips in Table

- [ ] 8.1 Load `:tags` relationship (with category preloaded) when fetching players in `PlayerFilters.fetch_players`
- [ ] 8.2 Replace `<.age_bracket_chips>` component with a `<.tag_chips>` component that renders tag names as compact badges
- [ ] 8.3 Update the players index table template to use the new tag chips component

## 9. Player Show and Edit Pages — Tags

- [ ] 9.1 Load `:tags` (with category) on player show page; display tags grouped by category name
- [ ] 9.2 Add tag section to player edit page: load all TagCategories+Tags for the group; render grouped checkboxes (one per tag, grouped by category); pre-check current player tags; submit as a list of selected tag IDs alongside the rest of the form
- [ ] 9.3 On form submit, diff submitted tag IDs against the player's current tag IDs; create PlayerTag records for newly checked tags; destroy PlayerTag records for unchecked tags; no real-time toggle — changes only take effect on save
- [ ] 9.4 Ensure tag picker is not shown or is read-only for group members (owners only can edit)

## 10. Roster Planner — Tag Filter

- [ ] 10.1 Replace `list_eligible_unassigned_players` with `list_unassigned_players` (there is exactly one caller: `RosterPlannerLive`); the new function returns all players with no membership in the current planning context and accepts a tag filter param; remove the old function entirely
- [ ] 10.2 Add `tag_filter` socket assign to `RosterPlannerLive` using the same struct shape as the player list: `%{include: %{category_id => [tag_id]}, exclude: [tag_id], show_untagged: [category_id]}`; initialize from `season_rules.default_tags`
- [ ] 10.3 Load `season_rules.default_tags` (with category preloaded) when building the board; use them to populate initial `tag_filter` include facets
- [ ] 10.4 Apply tag filter to the unassigned pool at the DB level via Ash query (OR within category, AND between categories, exclude list as AND NOT, show_untagged per facet). Attempt this with Ash.Query filter expressions before considering any Elixir-side fallback; assess feasibility after implementation and adjust if needed.
- [ ] 10.5 Load all TagCategories+Tags for the group in the planner mount; assign as `@tag_categories` for the filter UI
- [ ] 10.6 Add tag filter panel to the planner board toolbar using the same UI pattern as the player list: one facet group per TagCategory; per-tag toggle pills; per-facet "show untagged" toggle (always rendered, disabled when facet inactive); exclude list control
- [ ] 10.7 ~~Add exclude tag list UI to the planner filter panel~~ — covered by 10.6
- [ ] 10.8 Handle `toggle_planner_tag`, `toggle_planner_exclude`, and `toggle_planner_show_untagged` events; update `tag_filter` assign and re-query the DB with the updated filter (same Ash query path as 10.4; do not apply filter in-memory over a stale list)
- [ ] 10.9 Ensure filter state is per-session: no persistence; refresh resets to defaults

## 11. Season Rules — Default Tags

- [ ] 11.1 Add tag picker to season rules create/edit form (load all TagCategories+Tags; render grouped multi-select for default_tags)
- [ ] 11.2 Handle default tag changes on season rules form submit: sync SeasonRulesDefaultTag records to match selection
- [ ] 11.3 Load `default_tags` when fetching SeasonRules for a planning context

## 12. Tag Management UI

- [ ] 12.1 Add route `/g/:group_slug/settings/tags` → `TennisTrackerWeb.Settings.TagsLive`
- [ ] 12.2 Create `TagsLive` index: list all TagCategories with their Tags; show create category form inline
- [ ] 12.3 Implement create TagCategory (inline form; validates unique name; saves and refreshes list)
- [ ] 12.4 Implement rename TagCategory (inline edit; validates unique name; saves)
- [ ] 12.5 Implement delete TagCategory: always show confirmation modal (standard app pattern); include tag count in message when category has tags; cascade handled by Ash
- [ ] 12.6 Implement create Tag within a category (inline form per category; validates unique name within category)
- [ ] 12.7 Implement rename Tag (inline edit; validates unique name within category)
- [ ] 12.8 Implement delete Tag: show confirmation modal (standard app pattern); cascade handled by Ash
- [ ] 12.9 Hide create/edit/delete controls for group members; show read-only view
- [ ] 12.10 Add "Tags" link to group settings navigation

## 13. Tests

- [ ] 13.1 Unit tests for TagCategory and Tag Ash resources (CRUD, uniqueness constraints, policies)
- [ ] 13.2 Unit tests for PlayerTag (add/remove tag, cascade destroy when tag deleted)
- [ ] 13.3 Unit tests for SeasonRulesDefaultTag (cascade destroy when tag deleted)
- [ ] 13.4 Unit tests for preset taxonomy seeder (correct categories/tags created for new group)
- [ ] 13.5 Unit tests for `PlayerFilters.fetch_players` with tag filter (OR within category, AND between categories, inactive facet, empty filter)
- [ ] 13.6 LiveView tests for player list tag filter (toggle tag, clear filters, URL param encoding)
- [ ] 13.7 LiveView tests for player edit tag assignment (add tag, remove tag)
- [ ] 13.8 LiveView tests for roster planner tag filter (initial state from defaults, toggle tag, show_untagged, exclude list, session isolation)
- [ ] 13.9 LiveView tests for tag management UI (create/rename/delete category and tag, confirmation dialog)
- [ ] 13.10 Update existing player tests that reference eligible_18_plus/40_plus/55_plus to remove those field references
- [ ] 13.11 Update existing CSV import/export tests to reflect removed columns
- [ ] 13.12 Update test factory (ExMachina) to remove boolean eligibility fields from player factory; add tag-related factories
