## 1. Ash Resources — TagCategory and Tag

- [x] 1.1 Create `TennisTracker.Tennis.TagCategory` Ash resource (name, group_id, timestamps; unique name per group; group member read, group owner write policies; multitenancy; default sort order: alphabetical ascending by name)
- [x] 1.2 Create `TennisTracker.Tennis.Tag` Ash resource (name, tag_category_id, group_id, timestamps; unique name+category per group (case-insensitive — use `citext` column type or a `lower(name)` expression index); group member read, group owner write policies; multitenancy; default sort order: alphabetical ascending by name within category)
- [x] 1.3 Add `has_many :tags` relationship to TagCategory; add `belongs_to :tag_category` to Tag
- [x] 1.4 Create `TennisTracker.Tennis.PlayerTag` join Ash resource (player_id, tag_id, group_id; no timestamps; group member read/create/destroy; multitenancy)
- [x] 1.5 Create `TennisTracker.Tennis.SeasonRulesDefaultTag` join Ash resource (season_rules_id, tag_id, group_id; no timestamps; group member read, group owner create/destroy; cascade destroy when tag deleted; multitenancy)
- [x] 1.6 Add `many_to_many :tags` to Player through PlayerTag; add `many_to_many :default_tags` to SeasonRules through SeasonRulesDefaultTag
- [x] 1.7 Add `many_to_many :players` inverse on Tag through PlayerTag (for cascade destroy support)
- [x] 1.8 Register TagCategory, Tag, PlayerTag, SeasonRulesDefaultTag in the Tennis domain
- [x] 1.9 Add domain functions to Tennis domain: `list_tag_categories!/1`, `create_tag_category/2`, `update_tag_category/2`, `destroy_tag_category/2`, `list_tags_for_category!/2`, `create_tag/2`, `update_tag/2`, `destroy_tag/2`, `add_player_tag/3`, `remove_player_tag/3`, `sync_season_rules_default_tags/3` (replaces the full set of SeasonRulesDefaultTag records for a given season_rules_id with the provided tag_id list, creating/destroying records to match)
- [x] 1.10 Add admin bypass policy to TagCategory, Tag, PlayerTag, and SeasonRulesDefaultTag so system admins can read, create, update, and destroy all records across all groups
- [x] 1.11 Expose `seed_preset_tags!/1` as an AshAdmin action on the Group resource (or via a custom admin page) so system admins can trigger preset seeding for any group without needing `iex` shell access

## 2. Player Schema Changes

- [x] 2.1 Remove `eligible_18_plus`, `eligible_40_plus`, `eligible_55_plus` attributes from `Player` resource
- [x] 2.2 Remove these fields from Player's create and update action `accept` lists
- [x] 2.3 Remove `@boolean_columns` and all `coerce_field` clauses for these three fields from `PlayerCsvImport`
- [x] 2.4 Remove `eligible_18_plus`, `eligible_40_plus`, `eligible_55_plus` from `@known_columns` in `PlayerCsvImport`
- [x] 2.5 Remove the CSV export columns for these three fields from the export controller/module

## 3. Cascade Delete Behaviour

- [x] 3.1 Implement cascade destroy: destroying a TagCategory destroys all its Tags (via Ash destroy action or `on_delete: :delete_all` in postgres block)
- [x] 3.2 Implement cascade destroy: destroying a Tag destroys all its PlayerTag records
- [x] 3.3 Implement cascade destroy: destroying a Tag destroys all its SeasonRulesDefaultTag records

## 4. Preset Taxonomy Seeding

- [x] 4.1 Create a `Tennis.seed_preset_tags!/1` domain function (or equivalent) that creates the preset TagCategories and Tags for a given group_id
- [x] 4.2 ~~Trigger preset tag seeder on group creation~~ — **DEFERRED**: automatic seeding on group creation is out of scope; new groups are seeded via seeds file (local dev) or iex/AshAdmin (production)
- [x] 4.3 Rebuild `priv/repo/seeds.exs` with two new groups replacing the old "Small Group" / "Large Group". Remove all `eligible_18_plus`, `eligible_40_plus`, `eligible_55_plus` field references. Call `seed_preset_tags!/1` for each group after creating it. Update team membership assignment to use player names or NTRP rating rather than the removed boolean fields.

- [x] 4.4 Seed groups and players per the following spec. For each player the tag columns below list tags to assign; all other players in that group get no special-category tags beyond Age Group and (for Mixed group) League Gender. Use `upsert_player` as before, then create `PlayerTag` records after players and tags both exist.

  **Group 1: "Main"** (`slug: "main"`) — male players, no League Gender tags on any player

  *12 NTRP 4.5 players — all 18+; 6 also 40+; 3 of those 6 also 55+*
  | # | Age Group tags | Role tags |
  |---|---------------|-----------|
  | 1 | 18+, 40+, 55+ | Willing to Captain |
  | 2 | 18+, 40+, 55+ | — |
  | 3 | 18+, 40+, 55+ | — |
  | 4 | 18+, 40+ | Sub Only |
  | 5 | 18+, 40+ | — |
  | 6 | 18+, 40+ | — |
  | 7–12 | 18+ only | — |

  *25 NTRP 4.0 players — all 18+; 14 also 40+; 8 of those 14 also 55+*
  | # | Age Group tags | NTRP / Role / Availability / Pipeline tags |
  |---|---------------|---------------------------------------------|
  | 1 | 18+, 40+, 55+ | Willing to Captain |
  | 2 | 18+, 40+, 55+ | Willing to Captain |
  | 3 | 18+, 40+ | Willing to Captain |
  | 4 | 18+, 40+, 55+ | Can Play Up |
  | 5 | 18+, 40+ | Can Play Up |
  | 6 | 18+ | Can Play Up |
  | 7 | 18+ | Can Play Up |
  | 8 | 18+, 40+, 55+ | Medical Hold, Roster Fill Only |
  | 9 | 18+, 40+ | Medical Hold, Roster Fill Only |
  | 10 | 18+, 40+, 55+ | — |
  | 11 | 18+ | Limited Availability |
  | 12 | 18+ | Prospective |
  | 13–25 | mix (remaining 40+/55+ slots filled by players 13–18 as 40+, 16–18 as 55+) | — |

  *25 NTRP 3.5 players — same demarcation as 4.0:*
  | # | Age Group tags | NTRP / Role / Availability / Pipeline tags |
  |---|---------------|---------------------------------------------|
  | 1 | 18+, 40+, 55+ | Willing to Captain |
  | 2 | 18+, 40+, 55+ | Willing to Captain |
  | 3 | 18+, 40+ | Willing to Captain |
  | 4 | 18+, 40+, 55+ | Can Play Up |
  | 5 | 18+, 40+ | Can Play Up |
  | 6 | 18+ | Can Play Up |
  | 7 | 18+ | Can Play Up |
  | 8 | 18+, 40+, 55+ | Medical Hold, Roster Fill Only |
  | 9 | 18+, 40+ | Medical Hold, Roster Fill Only |
  | 10 | 18+, 40+, 55+ | — |
  | 11 | 18+ | Limited Availability |
  | 12 | 18+ | Prospective |
  | 13–25 | mix (remaining 40+/55+ slots) | — |

  *Main group team types and teams (all current year):*
  - TeamType "18+ 4.5": age_group 18_plus, ntrp_level 4.5, allowed [4.0, 4.5] → 1 team "Main 18+ 4.5", ~10 players from the 4.5 pool (skip Medical Hold players)
  - TeamType "18+ 4.0": age_group 18_plus, ntrp_level 4.0, allowed [3.5, 4.0] → 2 teams "Main 18+ 4.0 A" (~12 players) and "Main 18+ 4.0 B" (~11 players), drawn from 4.0 pool (skip Medical Hold players, distribute Can Play Up across both)
  - TeamType "18+ 3.5": age_group 18_plus, ntrp_level 3.5, allowed [3.0, 3.5] → 2 teams "Main 18+ 3.5 A" (~12 players) and "Main 18+ 3.5 B" (~11 players), drawn from 3.5 pool (same rule)
  - TeamType "40+ 3.5": age_group 40_plus, ntrp_level 3.5, allowed [3.0, 3.5] → 1 team "Main 40+ 3.5", ~10 players who have the 40+ tag and NTRP 3.5 (skip Medical Hold)

  *SeasonRules default_tags:* after syncing season rules defaults, set:
  - 18+ 4.5 season rules → default_tags: ["18+"]
  - 18+ 4.0 season rules → default_tags: ["18+"]
  - 18+ 3.5 season rules → default_tags: ["18+"]
  - 40+ 3.5 season rules → default_tags: ["40+"]

  ---

  **Group 2: "Mixed"** (`slug: "mixed"`) — 12 men + 12 women, no teams seeded

  *Men — 6 NTRP 3.5, 6 NTRP 4.0; all 18+; no 40+/55+ tags*
  | # | NTRP | League Gender tags | Role tags |
  |---|------|-------------------|-----------|
  | 1 | 3.5 | Men's Leagues, Mixed Leagues | Willing to Captain |
  | 2 | 3.5 | Men's Leagues, Mixed Leagues | Willing to Captain |
  | 3 | 3.5 | Men's Leagues, Mixed Leagues | — |
  | 4 | 3.5 | Men's Leagues only | — |
  | 5 | 3.5 | Men's Leagues only | — |
  | 6 | 3.5 | Mixed Leagues only | Sub Only |
  | 7 | 4.0 | Men's Leagues, Mixed Leagues | — |
  | 8 | 4.0 | Men's Leagues, Mixed Leagues | — |
  | 9 | 4.0 | Men's Leagues, Mixed Leagues | — |
  | 10 | 4.0 | Men's Leagues only | — |
  | 11 | 4.0 | Men's Leagues only | — |
  | 12 | 4.0 | Mixed Leagues only | — |

  (Note: 2 Mixed-only, 6 Men's+Mixed, 4 Men's-only — one of the 2 Mixed-only is Sub Only, two Willing to Captain are in the Men's+Mixed group)

  *Women — 6 NTRP 3.5, 6 NTRP 4.0; all 18+; no 40+/55+ tags*
  | # | NTRP | League Gender tags | Role tags |
  |---|------|-------------------|-----------|
  | 1 | 3.5 | Women's Leagues, Mixed Leagues | Willing to Captain |
  | 2 | 3.5 | Women's Leagues, Mixed Leagues | Willing to Captain |
  | 3 | 3.5 | Women's Leagues, Mixed Leagues | — |
  | 4 | 3.5 | Women's Leagues only | — |
  | 5 | 3.5 | Women's Leagues only | — |
  | 6 | 3.5 | Mixed Leagues only | Sub Only |
  | 7 | 4.0 | Women's Leagues, Mixed Leagues | — |
  | 8 | 4.0 | Women's Leagues, Mixed Leagues | — |
  | 9 | 4.0 | Women's Leagues, Mixed Leagues | — |
  | 10 | 4.0 | Women's Leagues only | — |
  | 11 | 4.0 | Women's Leagues only | — |
  | 12 | 4.0 | Mixed Leagues only | — |

- [x] 4.5 Update team membership assignment in seeds to select players by NTRP rating and, for 40+ teams, by presence of the "40+" tag (look up the tag record after calling `seed_preset_tags!/1`, then filter the already-created player list by checking their `PlayerTag` records). The old `eligible_18_plus`/`eligible_40_plus` filters on `large_player_defs` no longer exist — do not use `Enum.filter` on boolean fields.

## 5. Database Reset and Migration

- [x] 5.1 Generate Ash migrations: `mix ash_postgres.generate_migrations --name add_player_tagging_system`
- [x] 5.2 Run `mix ecto.reset` and verify seeds run cleanly

## 6. PlayerFilters — Tag-Based Filtering

- [x] 6.1 Replace `maybe_filter_bracket/2` in `PlayerFilters` with `maybe_filter_tags/2` implementing full faceted search: OR within category (include), AND between categories, per-facet show_untagged
- [x] 6.2 Update `fetch_players/4` signature to accept `tag_filter` param (`%{include: %{category_id => [tag_id]}, show_untagged: [category_id]}`) in place of `bracket_filter`
- [x] 6.3 Implement `maybe_filter_tags` at the DB level via Ash.Query (not Elixir-side); this same filter logic is also used by `list_unassigned_players` in the roster planner — consider extracting a shared query-builder function

## 7. Player List LiveView — Tag Filter UI

The player list tag filter UI shall match the roster planner tag filter UI as closely as possible (same faceted pills, per-facet show_untagged toggle). Start with separate components with similar code — do not attempt a single shared top-level component upfront. Shared sub-components (e.g., a facet group, a tag pill) may be worth extracting; evaluate after both are built. The only fundamental difference is state persistence: URL params here (include tags only), session-only in the planner.

- [x] 7.1 Load all TagCategories and Tags for the group in `Players.IndexLive.mount/3`; sort both categories and tags alphabetically ascending by name (A → Z)
- [x] 7.2 Replace `@bracket_options` / `bracket_filter` assigns with `@tag_categories` / `tag_filter` assign: `%{include: %{category_id => [tag_id]}, show_untagged: [category_id]}`; note that `show_untagged` for a facet persists in socket state even when the facet is inactive — if the captain re-selects a tag in that category, the previous `show_untagged` value re-activates; when the last tag in a category is deselected, remove the category key from `include` entirely (absent key = inactive facet; do not keep an empty list)
- [x] 7.3 Replace age bracket filter pills in the template with tag category groups, each with per-tag toggle pills and a per-facet show_untagged toggle (always rendered, disabled when facet inactive)
- [x] 7.4 Update `handle_event("toggle_bracket", ...)` → `handle_event("toggle_tag", ...)` and add `handle_event("toggle_show_untagged", ...)`
- [x] 7.5 Update `filter_url/2` to encode include tag selection only: `tags[]=<uuid>` per selected tag; `show_untagged` state is not URL-encoded
- [x] 7.6 Update `handle_params/3` to parse `tags[]` params into the tag_filter include map; resolve IDs against loaded `@tag_categories`; silently ignore unrecognized IDs; initialize `show_untagged` to empty list (all off) on page load
- [x] 7.7 ~~Update `export_url/4` to pass tag filter params through to the CSV export endpoint~~ — **DEFERRED**: tag filter passthrough to CSV export is a fast-follow; remove any bracket param from the export URL but do not add tag params
- [x] 7.8 Update "Clear all filters" to reset all tag_filter state: include and show_untagged

## 8. Player List — Tag Chips in Table

- [x] 8.1 Load `:tags` relationship (with category preloaded) when fetching players in `PlayerFilters.fetch_players`
- [x] 8.2 Replace `<.age_bracket_chips>` component with a `<.tag_chips>` component that renders tag names as compact badges
- [x] 8.3 Update the players index table template to use the new tag chips component

## 9. Player Show and Edit Pages — Tags

- [x] 9.1 Load `:tags` (with category) on player show page; display tags grouped by category name
- [x] 9.2 Add tag section to player edit page: load all TagCategories+Tags for the group; render grouped checkboxes (one per tag, grouped by category); pre-check current player tags; submit as a list of selected tag IDs alongside the rest of the form
- [x] 9.3 On form submit, diff submitted tag IDs against the player's current tag IDs; create PlayerTag records for newly checked tags; destroy PlayerTag records for unchecked tags; no real-time toggle — changes only take effect on save
- [x] 9.4 Ensure tag section and checkboxes are shown and interactive for all group members (both owners and members can add/remove player tags)

## 10. Roster Planner — Tag Filter

- [x] 10.1 Replace `list_eligible_unassigned_players` with `list_unassigned_players` (there is exactly one caller: `RosterPlannerLive`); the new function returns all players with no membership in the current planning context and accepts a tag filter param; remove the old function entirely
- [x] 10.2 Add `tag_filter` socket assign to `RosterPlannerLive` using the same struct shape as the player list: `%{include: %{category_id => [tag_id]}, show_untagged: [category_id]}`; initialize include facets from `season_rules.default_tags`; initialize `show_untagged` to empty list (all off); the `show_untagged` value for a facet persists in session state when the facet is deactivated and re-activates when a tag in that category is re-selected; when the last tag in a category is deselected, remove the category key from `include` entirely (absent key = inactive facet; do not keep an empty list)
- [x] 10.3 Load `season_rules.default_tags` (with category preloaded) when building the board; use them to populate initial `tag_filter` include facets
- [x] 10.4 Apply tag filter to the unassigned pool at the DB level via Ash query (OR within category, AND between categories, show_untagged per facet). Attempt this with Ash.Query filter expressions before considering any Elixir-side fallback; assess feasibility after implementation and adjust if needed.
- [x] 10.5 Load all TagCategories+Tags for the group in the planner mount; assign as `@tag_categories` for the filter UI; sort both categories and tags alphabetically ascending by name (A → Z)
- [x] 10.6 Add tag filter panel to the planner board toolbar using the same UI pattern as the player list: one facet group per TagCategory; per-tag toggle pills; per-facet "show untagged" toggle (always rendered, disabled when facet inactive)
- [x] 10.7 ~~Add exclude tag list UI to the planner filter panel~~ — **DEFERRED**: exclude list (AND NOT filtering) is out of scope; may be added in a fast-follow if the OR/AND model proves insufficient
- [x] 10.8 Handle `toggle_planner_tag` and `toggle_planner_show_untagged` events; update `tag_filter` assign and re-query the DB with the updated filter (same Ash query path as 10.4; do not apply filter in-memory over a stale list)
- [x] 10.9 Ensure filter state is per-session: no persistence; refresh resets to defaults

## 11. Season Rules — Default Tags

- [x] 11.1 Add tag picker to season rules create/edit form (load all TagCategories+Tags; render grouped multi-select for default_tags)
- [x] 11.2 Handle default tag changes on season rules form submit: call `Tennis.sync_season_rules_default_tags/3` to replace the full set of SeasonRulesDefaultTag records for the season rules with the submitted tag selection
- [x] 11.3 Load `default_tags` when fetching SeasonRules for a planning context

## 12. Tag Management UI

- [x] 12.1 Add route `/g/:group_slug/settings/tags` → `TennisTrackerWeb.Settings.TagsLive`
- [x] 12.2 Create `TagsLive` index: list all TagCategories with their Tags; show create category form inline; display categories and tags sorted alphabetically ascending by name (A → Z)
- [x] 12.3 Implement create TagCategory (inline form; validates unique name; saves and refreshes list)
- [x] 12.4 Implement rename TagCategory (inline edit; validates unique name; saves)
- [x] 12.5 Implement delete TagCategory: always show confirmation modal (standard app pattern); include tag count in message when category has tags; cascade handled by Ash
- [x] 12.6 Implement create Tag within a category (inline form per category; validates unique name within category)
- [x] 12.7 Implement rename Tag (inline edit; validates unique name within category)
- [x] 12.8 Implement delete Tag: show confirmation modal (standard app pattern); cascade handled by Ash
- [x] 12.9 Hide create/edit/delete controls for group members; show read-only view
- [x] 12.10 Add "Tags" link to group settings navigation

## 13. Tests

- [x] 13.1 Unit tests for TagCategory and Tag Ash resources (CRUD, uniqueness constraints, policies)
- [x] 13.2 Unit tests for PlayerTag (add/remove tag, cascade destroy when tag deleted)
- [x] 13.3 Unit tests for SeasonRulesDefaultTag (cascade destroy when tag deleted)
- [x] 13.4 Unit tests for preset taxonomy seeder (correct categories/tags created for new group)
- [x] 13.5 Unit tests for `PlayerFilters.fetch_players` with tag filter (OR within category, AND between categories, inactive facet, empty filter)
- [x] 13.6 LiveView tests for player list tag filter (toggle tag, clear filters, URL param encoding)
- [x] 13.7 LiveView tests for player edit tag assignment (add tag, remove tag)
- [x] 13.8 LiveView tests for roster planner tag filter (initial state from defaults, toggle tag, show_untagged, show_untagged state persistence across facet deactivation/reactivation, session isolation)
- [x] 13.9 LiveView tests for tag management UI (create/rename/delete category and tag, confirmation dialog)
- [x] 13.10 Update existing player tests that reference eligible_18_plus/40_plus/55_plus to remove those field references
- [x] 13.11 Update existing CSV import/export tests to reflect removed columns
- [x] 13.12 Update test factory (ExMachina) to remove boolean eligibility fields from player factory; add tag-related factories
