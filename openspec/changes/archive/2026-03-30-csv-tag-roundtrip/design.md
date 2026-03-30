## Context

The CSV export currently outputs four fixed columns (`name`, `ntrp_rating`, `email`, `phone_number`). The import accepts those same four columns and rejects anything else. Tags — the primary player categorization mechanism since the tagging system replaced boolean eligibility fields — are entirely absent from both directions.

The core challenge is that tags are dynamic and group-scoped: every group has its own taxonomy, so column headers cannot be hardcoded. The import also needs to work across groups, meaning it must match tags by name rather than ID.

Existing infrastructure:
- `PlayerFilters.fetch_players/4` already accepts and applies tag filters — the filtered player set for export is already correct
- `PlayerCsvImport` uses `NimbleCSV` and a strict `@known_columns` allowlist that will reject any new headers unless explicitly handled
- `TagCategory` has a case-sensitive unique identity; `Tag` has a case-insensitive unique index (`lower(name)`) within category+group

## Goals / Non-Goals

**Goals:**
- Export includes all tag columns for the group as boolean (`true`/`""`) values
- Import recognizes `tag:CategoryName:TagName` headers, resolves tags via case-insensitive find-or-create, and assigns them to newly created players
- Round-trip is portable: export from Group A, import into Group B, tags are matched or created by name
- All cell values and header names are trimmed before parsing

**Non-Goals:**
- Import does not upsert existing players — it only creates new ones (deferred; see `todo.md`)
- Auto-created tags are not rolled back if player inserts later fail in the same import (deferred; see `todo.md`)
- No DB-level check constraint for the `:` prohibition (app-level validation is sufficient)
- No changes to the import UI or error-display LiveView

## Decisions

### Decision: `tag:CategoryName:TagName` column header format

**Rationale:** The `tag:` prefix unambiguously distinguishes tag columns from player field columns without requiring changes to `@known_columns`. The `CategoryName:TagName` suffix encodes both dimensions needed for cross-group resolution. Two `:` characters divide the header into exactly three segments; any other count is a parse error.

**Alternative considered:** A single `tags` column with semicolon-separated values (pipe or CSV-within-CSV). Rejected because it loses per-tag boolean granularity and makes import parsing fragile with nested escaping.

**Alternative considered:** One column per category with semicolon-separated tag names. Rejected because it requires a different quoting strategy and makes boolean roundtrip awkward.

**Constraint:** `:` must not appear in `TagCategory.name` or `Tag.name`. Enforced via Ash `validate` on both resources. This validation is added as part of this change.

### Decision: Case-insensitive find-or-create for tag resolution on import

**Rationale:** CSV exports preserve the original casing of tag names (e.g., `"Age Group"`, `"40+"`). When importing into a different group that already has the same taxonomy under identical or differently-cased names, case-insensitive matching avoids spurious duplicates. On create, the original casing from the CSV header is preserved — so an import that brings in `"age group"` to a group with no existing category will create `"age group"`, not `"Age Group"`.

**Algorithm:**
1. For each unique tag column header, parse `category_raw` and `tag_raw`
2. Normalize: `category_key = downcase(trim(category_raw))`
3. Query: `SELECT * FROM tag_categories WHERE group_id = ? AND lower(name) = category_key LIMIT 1`
4. If found → use it; if not → `Tennis.create_tag_category!(%{name: category_raw, group_id: group_id}, ...)`
5. With resolved category, normalize: `tag_key = downcase(trim(tag_raw))`
6. Query: `SELECT * FROM tags WHERE group_id = ? AND tag_category_id = ? AND lower(name) = tag_key LIMIT 1`
7. If found → use it; if not → `Tennis.create_tag!(%{name: tag_raw, ...}, ...)`

This runs once before the row loop, building `%{header_string => tag_id}`.

**Note on TagCategory uniqueness:** The existing `identity(:unique_name_per_group, ...)` on `TagCategory` is exact-match (not case-insensitive). The `Tag` unique index already uses `lower(name)`. For this change, we rely on app-level lowercase lookup for categories and the DB-level lowercase index for tags. Adding a case-insensitive DB index to `TagCategory` is deferred — with the new `:` validation preventing ambiguous names going forward, the risk of stale case-duplicates is minimal.

### Decision: Tag resolution runs outside the per-player transaction

**Rationale:** Multiple player rows may reference the same tag. Resolving tags once before the row loop avoids repeated lookups and prevents duplicate creates within a single import run. The tradeoff is that auto-created tags are not rolled back if later player inserts fail. This is accepted for now and noted in `todo.md`.

### Decision: Use `Ash.transact/3` for the player insert transaction

**Rationale:** The existing `insert_all/2` uses `Repo.transaction/1` + `Repo.rollback/1`. Replace this with `Ash.transact/3`, which wraps the block in the resource's data layer transaction and properly collects and fires Ash notifications after a successful commit. `Ecto.Multi` is explicitly ruled out: it bypasses Ash lifecycle hooks, meaning PubSub notifications and policy side-effects do not run. `Repo.transaction` works at the DB level but is non-idiomatic in an Ash-first codebase. `Ash.transact/3` is the Ash 3.x recommended approach. Tag resolution runs before this transaction; auto-created tags remain a known non-rollback item (see `todo.md`).

### Decision: `import_csv/2` returns `{:ok, %{players: N, categories_created: X, tags_created: Y}}` on success

**Rationale:** Users need visibility into what the import did, especially when tags were auto-created in their group. Returning a structured map (rather than just a player count integer) allows the LiveView to surface a message like "Created 18 players. Created 2 tag categories. Created 7 tags." `categories_created` counts only auto-created `TagCategory` records; `tags_created` counts only auto-created `Tag` records. Reused records are not counted in either field.

### Decision: `coerce_row` returns `{player_params, tag_header_strings}` tuple

**Rationale:** `coerce_row` is a normalization step — it parses and validates raw CSV data. Extending it to `{:ok, {params_map, [tag_header_string]}}` keeps tag column identifiers separate from player fields and confines `coerce_row` to its role: parsing and validation. ID resolution is a separate concern: `insert_all/3` already holds `tag_map` (from `resolve_tag_columns/2`) and maps the returned header strings to tag IDs before creating `PlayerTag` records. This avoids passing `tag_map` into `coerce_row` and keeps each function's responsibility clear.

### Decision: Strict boolean parsing for tag cell values

**Rationale:** Accepting any truthy value (e.g., `"yes"`, `"1"`, `"x"`) in tag cells would silently absorb typos and make CSV editing error-prone. Restricting to `"true"` (case-insensitive after trim) or blank/empty (treated as false) gives users a clear contract and catches accidental edits.

## Risks / Trade-offs

- **Auto-created tags not rolled back on failure** → Mitigation: document in `todo.md`; the success result includes a `tags_created` count so users can see that tags were auto-created and know they persist even if a subsequent import run fails mid-way
- **Import always creates, never upserts** → Mitigation: document in `todo.md`; re-importing to same group creates duplicate players. Users should be aware of this.
- **Tag column count can be large** for groups with many tags → Mitigation: no action needed; CSV tools handle wide files; export is still a single HTTP response

## Open Questions

None — all decisions made during exploration.
