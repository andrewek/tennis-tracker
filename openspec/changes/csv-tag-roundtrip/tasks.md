## 1. Validation — Prohibit colons in tag and category names

- [ ] 1.1 Add `validate match(:name, ~r/^[^:]+$/, message: "cannot contain ':'")` (or equivalent custom validation) to `TennisTracker.Tennis.TagCategory`
- [ ] 1.2 Add the same `:` prohibition validation to `TennisTracker.Tennis.Tag`
- [ ] 1.3 Write unit tests for both validations: colon in name is rejected, name without colon is accepted

## 2. CSV Export — Dynamic tag columns

- [ ] 2.1 In `PlayerCSVController.export/2`, fetch all tag categories + tags for the group (sorted by category name asc, tag name asc); build dynamic tag headers in `tag:CategoryName:TagName` format
- [ ] 2.2 Change the `load:` option in `PlayerFilters.fetch_players/4` call to include `[:tags]` so each player has its tags loaded
- [ ] 2.3 Update `player_row/1` to append one boolean cell (`"true"` or `""`) per tag column, in the same order as the headers
- [ ] 2.4 Update `@headers` (or replace with a dynamic header list) to include the tag headers
- [ ] 2.5 Write controller tests: export with no tags produces base headers only; export with tags produces correct tag columns; a player with a tag has `"true"` in that column; a player without a tag has `""` in that column; export with an active tag filter returns only players matching that tag (smoke test — guards against regressions in filter passthrough)
- [ ] 2.6 Update the players index LiveView to include active tag filter IDs as `tags[]` query params in the "Export CSV" link href, alongside any existing name/NTRP filter params
- [ ] 2.7 Write LiveView tests: export link encodes active tag filter params; encodes combined name + NTRP + tag filters; link with no active filters has no filter params

## 3. CSV Import — Header parsing for tag columns

- [ ] 3.1 Update `validate_headers/1` in `PlayerCsvImport` to split headers into regular columns and tag columns (prefix `tag:`)
- [ ] 3.2 For regular columns: retain existing `@known_columns` validation unchanged
- [ ] 3.3 For tag columns: parse each as `tag:CategoryName:TagName` (trim all segments); return `{:error, :invalid_headers, [...]}` for: fewer than 3 segments, empty category name, empty tag name
- [ ] 3.4 Detect and reject duplicate tag column headers with `{:error, :invalid_headers, [...]}` — duplicate detection uses normalized (downcased, trimmed) segment comparison so that `tag:Age Group:40+` and `tag:age group:40+` are treated as duplicates
- [ ] 3.5 Update `validate_headers/1` return type to carry tag column metadata alongside regular headers (e.g., `{:ok, {regular_headers, tag_columns}}`)
- [ ] 3.6 Write unit tests for all header validation cases: valid tag headers accepted; malformed headers rejected with correct error; exact-string duplicates rejected; case-insensitively equivalent headers rejected as duplicates; unknown non-tag headers still rejected

## 4. CSV Import — Tag resolution (find-or-create)

- [ ] 4.1 Add a `:find_by_name` read action (or use existing query) on `TagCategory` that looks up by `lower(name)` within a group — or implement the lookup inline in the import module
- [ ] 4.2 Add a `:find_by_name` read action (or inline query) on `Tag` that looks up by `lower(name)` within a category and group
- [ ] 4.3 Implement `resolve_tag_columns/2` in `PlayerCsvImport`: takes the list of parsed tag columns + Ash opts (tenant, actor); for each column, find-or-create category then tag (case-insensitive lookup, original-casing create); returns `{%{header_string => tag_id}, categories_created_count, tags_created_count}` where `categories_created_count` is the number of `TagCategory` records auto-created and `tags_created_count` is the number of `Tag` records auto-created during this run
- [ ] 4.4 Wire `resolve_tag_columns/2` into `import_csv/2` so it runs once before the row loop; thread the resulting map into `parse_rows/3` and `insert_all/2`
- [ ] 4.5 Write unit tests for `resolve_tag_columns/2`: exact match reuses existing; case-insensitive match reuses existing; missing category + tag are created; missing tag under existing category creates only tag; same-named tag under different category creates new category and tag

## 5. CSV Import — Row parsing and player tag assignment

- [ ] 5.1 Update `coerce_row/3` to handle tag columns: `"true"` (case-insensitive, trimmed) → collect tag_id; `""` / nil → skip; any other value → `{:error, :row_error, line, "tag column '...' has invalid value '...'; expected 'true' or empty"}`
- [ ] 5.2 Update `coerce_row/2` return type to `{:ok, {player_params, [tag_header_string]}}` instead of `{:ok, params_map}`; `coerce_row` does not receive or use `tag_map` — it returns the header strings for tag columns whose value was `"true"` (after trimming and case-insensitive check)
- [ ] 5.3 Update `insert_all/3` to accept `[{player_params, tag_header_strings}]` and `tag_map`; wrap the entire loop in `Ash.transact/3` (replacing the existing `Repo.transaction/1`); after each `Tennis.create_player/2` call, map `tag_header_strings` to IDs via `tag_map` and create `PlayerTag` records for each within that same `Ash.transact/3` block so player creation and tag assignment are atomic
- [ ] 5.4 Ensure all header names and cell values are trimmed before parsing (apply `String.trim/1` at parse entry points)
- [ ] 5.5 Write unit tests: `"true"` cell assigns tag; `""` cell skips; `" true "` (trimmed) assigns tag; `"yes"` causes row error; invalid value in row 5 rolls back all rows
- [ ] 5.6 Update `import_csv/2` return type to `{:ok, %{players: N, categories_created: X, tags_created: Y}}` on success, where `categories_created` is the count of `TagCategory` records auto-created and `tags_created` is the count of `Tag` records auto-created during `resolve_tag_columns/2` (reused records not counted in either field); update the `@spec` annotation; update the import LiveView to display a success message using all three counts (e.g., "Created 18 players. Created 2 tag categories. Created 7 tags.")
- [ ] 5.7 Write tests for the success result shape: no tag columns → `%{categories_created: 0, tags_created: 0}`; all tags reused → `%{categories_created: 0, tags_created: 0}`; new category + tag auto-created → `categories_created` and `tags_created` each match their respective counts independently

## 6. todo.md updates

- [ ] 6.1 Add a note to `todo.md`: "CSV import always creates new players — re-importing to the same group will produce duplicates. Explore upsert (match by name or email) as a future improvement."
- [ ] 6.2 Add a note to `todo.md`: "Tags auto-created during CSV import are not rolled back if player inserts later fail. Explore transactional tag resolution or a cleanup step as a future improvement."
