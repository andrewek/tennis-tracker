## Context

The current player schema has three boolean attributes (`eligible_18_plus`, `eligible_40_plus`, `eligible_55_plus`) that represent a captain's tracking of which age-group leagues a player participates in. These fields are used in the player list filter (bracket filter pills) and in the roster planner to filter the unassigned player pool. They are too rigid: they don't cover 65+/70+ leagues, can't express gender league preference, NTRP stretch eligibility, availability constraints, or pipeline status. Every new dimension requires a schema change.

The roster planner currently calls `list_eligible_unassigned_players`, which filters by `team_type.age_group` against these booleans. This creates hard eligibility gates that are more restrictive than captains need — they want to scan the full player pool and filter fluidly.

This change introduces a general-purpose tagging system: group-scoped `TagCategory` and `Tag` resources, a `PlayerTag` join, and a `SeasonRulesDefaultTag` join for planner defaults. Tags replace the boolean fields entirely.

## Goals / Non-Goals

**Goals:**
- Replace boolean eligibility fields with flexible tags
- Support faceted filtering (OR within category, AND between categories) on both the player list and the roster planner
- Give group owners full control over tag taxonomy (CRUD on categories and tags)
- Seed a useful preset taxonomy for new groups
- Make the roster planner show all unassigned players by default, with session-state tag filtering that resets on refresh

**Non-Goals:**
- Tags in CSV import/export (deferred)
- Notes/annotations on Player records (deferred)
- Gender as a first-class Player attribute (replaced by League Gender tags)
- Enforcing mutual exclusivity within a tag category
- Storing per-facet `show_untagged` defaults in SeasonRules (always false; session-only)

## Decisions

### D1: TagCategory as its own resource (not a string field on Tag)

Storing category as a free-text string on `Tag` would make renaming a category a bulk update across all tags, and would allow typo-based category fragmentation. A dedicated `TagCategory` resource means a rename is a single-row update, enables future additions (display order, visibility flags) via clean migrations, and makes the category list authoritative and queryable.

**Alternative considered:** `category` string field on `Tag`. Rejected because of rename cost and drift risk.

### D2: Dedicated join resources (PlayerTag, SeasonRulesDefaultTag) over polymorphic association

Ash does not have a built-in polymorphic belongs_to pattern and actively discourages simulating one (no FK constraints, orphan risk, awkward queries). Dedicated join resources per tagged type maintain FK integrity and work naturally with Ash relationships (`many_to_many` through a join resource).

**Alternative considered:** Generic `Tagging` join with `taggable_id` + `taggable_type`. Rejected: no FK integrity, harder to query, non-idiomatic.

### D3: Tag identity is unique by name + tag_category_id per group (case-insensitive)

Two tags in different categories may share a name (e.g., "Active" in Availability and "Active" in some future Status category). Identity is `[:name, :tag_category_id, :group_id]` with case-insensitive name comparison — implement using a `citext` column type or a `lower(name)` expression in the DB unique index. This allows meaningful name reuse across categories while preventing duplicates within a category regardless of casing.

### D4: Cascade delete TagCategory → Tags → PlayerTags + SeasonRulesDefaultTags

Blocking deletion when tags exist would require captains to manually remove all tag assignments before cleaning up a category — poor UX for bulk cleanup. Cascade delete with a confirmation modal gives the captain full information before a destructive action. The cascade is handled via Ash `destroy` action with appropriate `on_delete` config.

**Application standard pattern:** A confirmation modal before any destructive delete is the standard UX pattern in this application (used for players and teams). Tags and tag categories follow the same pattern. For category deletion, the modal message includes the count of tags that will also be removed.

### D5: Faceted filter semantics — OR within category, AND between categories

This is the canonical faceted search model (used by Amazon, Airbnb, Elasticsearch). Within a category, selected tags are alternatives (OR). Between categories, all must match (AND). This gives the expressiveness needed for real-world roster filtering without requiring a query language.

An explicit exclude list (AND NOT filtering) was considered but is deferred — it adds UI complexity and the need for it is unconfirmed. It can be added as a fast-follow if captains find the OR/AND model insufficient.

**Alternative considered:** Full string-based query builder. Rejected: high UX cost, same expressiveness achievable with faceted UI.

### D6: Per-facet `show_untagged` toggle, always rendered but disabled when inactive

When a captain filters by NTRP-related tags, they may also want to see players with no NTRP tags (incomplete records). A per-facet toggle enables this without widening other facets. Always rendering the toggle (disabled when the facet is inactive) avoids layout shift as selections change.

`show_untagged` is never persisted — it defaults to `false` and is session-only. SeasonRules default tags define which tags are pre-selected; show_untagged is always off at session start.

### D7: Roster planner moves to "list all unassigned players" with session-state filter

The current hard eligibility filter (`list_eligible_unassigned_players`) is replaced with an unassigned player query filtered by the session-state tag filter. This enables captains to scan broadly ("show me everyone, then narrow down") rather than being gated by pre-set eligibility. Each browser session maintains its own filter state; refreshing resets to defaults from `season_rules.default_tags`.

The tag filter (OR within category, AND between categories) is applied at the DB level via Ash query — not in-memory after loading. When the filter changes, the DB is re-queried with the updated filter rather than filtering over a stale in-memory list. If Ash query expressions prove insufficient for the full faceted logic, revisit and document the decision here.

**Alternative considered:** Keep eligibility filter, add tags as a supplemental filter. Rejected: two overlapping filter mechanisms, unclear semantics about which takes precedence.

### D8: Preset taxonomy seeded via seeds file and manual tooling (not auto-triggered on group creation)

Six preset categories with opinionated starting tags (Age Group, League Gender, NTRP, Availability, Role, Pipeline) give new groups an immediately useful taxonomy without requiring manual setup. Group owners can rename, add, or delete as needed.

Automatically triggering the preset seeder on group creation is deferred. For now: `priv/repo/seeds.exs` calls the seeder for each seeded group (local development); new production groups can be seeded via AshAdmin or an `iex` shell. A future "group setup wizard" or admin-triggered seed action is tracked in todo.md.

### D9: Database reset instead of migration

No production data exists; all records are seed data. A full `mix ecto.reset` is simpler and cleaner than authoring a migration that removes three boolean columns, creates four new tables, and backfills data. Seeds are updated to assign tags instead of boolean values.

### D10: Filter URL params for player list encode only selected (include) tag IDs

Only the include tag selection is reflected in the player list URL: `tags[]=<uuid>&tags[]=<uuid>`. The `show_untagged` toggles are transient UI state and are not URL-encoded — they reset on page load. The exclude list is deferred (see D5).

Using IDs (rather than names) makes URLs durable across tag renames, avoids URL-encoding issues with special characters in tag names (e.g., "40+ Eligible", "Women's Leagues"), and eliminates the need to disambiguate same-name tags across categories. The LiveView resolves IDs back to tag records using the already-loaded `@tag_categories` assign. URLs are less human-readable but more robust.

**Alternative considered:** `tag[category]=name` style params using tag names. Rejected: tag names may contain characters that require percent-encoding ("+", apostrophes, spaces), making URLs fragile and harder to share; renames would silently break bookmarked URLs; disambiguation of same-name tags across categories adds complexity.

**Tag name constraints:** Because tag names appear in the UI (not URLs), there are no character restrictions on names beyond reasonable length. The URL encoding concern is fully addressed by using IDs.

### D11: Default display ordering is alphabetical ascending (A → Z); custom ordering is deferred

TagCategory and Tag records are displayed in alphabetical ascending (A → Z) order by name wherever they appear in the UI (tag management page, filter panels, player show/edit pages, season rules form). A `position` or `display_order` field enabling custom ordering by group owners is deferred to a future change (see todo.md).

## Risks / Trade-offs

**Preset taxonomy drift** → Groups may rename or delete preset tags, diverging from the documented taxonomy. Mitigation: the preset is a starting point only; no system behavior depends on specific tag names after seeding.

**Tag assignment discipline** → The system doesn't enforce mutual exclusivity (e.g., "Active" and "Sitting Out" on the same player). Mitigation: UI shows all current tags when editing, so captains will see the conflict. Future work could add validation warnings.

**Filter URL complexity** → The player list URL currently uses simple comma-separated params. Tag-based filtering requires a richer encoding. Mitigation: encode selected tag IDs as `tags[]=<uuid>` params (see D10).

**Roster planner performance** → Loading all unassigned players (no hard eligibility filter) may return larger result sets for large groups. Mitigation: the tag filter runs at the DB level via Ash queries (not Elixir-side filtering); indexes on `player_tags(player_id, tag_id)` keep this fast.

**SeasonRules default tags become stale** → If a captain deletes a tag that's referenced in a SeasonRules default, the cascade removes it. The planner opens with fewer default filters than expected — a silent degradation. Mitigation: acceptable for v1; a future "tag in use" indicator in the tag management UI would help.

**Cross-group FK integrity on SeasonRulesDefaultTag** → `SeasonRulesDefaultTag` references both a `SeasonRules` record and a `Tag` record, which must belong to the same group. No DB-level constraint enforces this. Mitigation: the UI always loads tags and season rules through the same tenant context, making a cross-group join practically impossible through normal app flows. We accept this risk for now and do not add a validation. See todo.md for future exploration of FK integrity across the app.

## Migration Plan

1. Implement new Ash resources and modify existing ones
2. Generate migrations with `mix ash_postgres.generate_migrations --name add_player_tagging_system`
3. Run `mix ecto.reset` (drops, recreates, migrates, seeds)
4. Updated seeds create preset taxonomy for each group and assign tags to players
5. No rollback plan needed (development only; no production deployment yet)

## Open Questions

None — all design decisions were resolved during exploration.
