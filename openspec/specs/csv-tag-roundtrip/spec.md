## Requirements

### Requirement: CSV export includes a boolean column for every tag in the group
The export SHALL output one column per `Tag` in the group, sorted by `TagCategory.name` ascending then `Tag.name` ascending. Each column header SHALL use the format `tag:CategoryName:TagName`. Each cell value SHALL be `"true"` if the player has that tag assigned, or `""` (empty string) otherwise.

#### Scenario: Export includes tag columns for all group tags
- **WHEN** a group has tag categories and tags defined
- **THEN** the CSV header row SHALL include a `tag:CategoryName:TagName` column for every tag in the group, sorted by category name then tag name

#### Scenario: Player with a tag has "true" in the corresponding column
- **WHEN** a player has tag T from category C assigned
- **THEN** the cell in the `tag:C:T` column for that player's row SHALL be `"true"`

#### Scenario: Player without a tag has empty string in the corresponding column
- **WHEN** a player does not have tag T from category C assigned
- **THEN** the cell in the `tag:C:T` column for that player's row SHALL be `""` (empty)

#### Scenario: Export with no tags defined produces no tag columns
- **WHEN** a group has no tag categories or tags defined
- **THEN** the CSV header row SHALL contain only the base columns (`name`, `ntrp_rating`, `email`, `phone_number`)

### Requirement: CSV import recognizes and validates tag column headers
The import SHALL accept column headers matching the pattern `tag:CategoryName:TagName`. Tag headers SHALL be parsed separately from regular player field headers. The import SHALL reject malformed tag headers with a descriptive error identifying the invalid header and the reason.

#### Scenario: Valid tag column header is accepted
- **WHEN** a CSV contains a header `tag:Age Group:40+`
- **THEN** the header is recognized as a tag column and processed without error

#### Scenario: Tag header with missing tag name is rejected
- **WHEN** a CSV contains a header `tag:Age Group:`
- **THEN** the import fails with `{:error, :invalid_headers, [...]}` identifying the malformed header and stating the tag name is missing

#### Scenario: Tag header with missing category name is rejected
- **WHEN** a CSV contains a header `tag::40+`
- **THEN** the import fails with `{:error, :invalid_headers, [...]}` identifying the malformed header and stating the category name is missing

#### Scenario: Tag header with only one segment after "tag:" is rejected
- **WHEN** a CSV contains a header `tag:OnlyOneSegment`
- **THEN** the import fails with `{:error, :invalid_headers, [...]}` identifying the malformed header

#### Scenario: Duplicate tag column header is rejected
- **WHEN** a CSV contains two columns with the identical header `tag:Age Group:40+`
- **THEN** the import fails with `{:error, :invalid_headers, [...]}` identifying the duplicate

#### Scenario: Case-insensitively equivalent tag column headers are treated as duplicates
- **WHEN** a CSV contains headers `tag:Age Group:40+` and `tag:age group:40+` (which normalize to the same category and tag key)
- **THEN** the import fails with `{:error, :invalid_headers, [...]}` identifying the duplicate — duplicate detection uses normalized (downcased, trimmed) segment comparison, not raw string equality

#### Scenario: Unknown non-tag headers are still rejected
- **WHEN** a CSV contains a header that is neither a known player column nor a `tag:*` header
- **THEN** the import fails with `{:error, :invalid_headers, [...]}` as before

### Requirement: CSV import resolves tag columns to existing or new tags via case-insensitive name matching
Before processing any player rows, the import SHALL resolve each tag column to a `tag_id`. Resolution is case-insensitive: the import SHALL find an existing `TagCategory` whose name matches the CSV header's category segment (case-insensitively) and an existing `Tag` whose name matches the tag segment (case-insensitively) within that category. If no match is found, the import SHALL create the missing `TagCategory` and/or `Tag` using the original casing from the CSV header. Resolution happens once, before any player rows are inserted.

#### Scenario: Exact-match category and tag are reused
- **WHEN** the group already has category "Age Group" with tag "40+" and the CSV column header is `tag:Age Group:40+`
- **THEN** the existing category and tag are used; no new records are created

#### Scenario: Case-insensitive category match reuses existing category
- **WHEN** the group has category "Age Group" and the CSV column header is `tag:age group:40+`
- **THEN** the existing "Age Group" category is used; no new category is created

#### Scenario: Case-insensitive tag match reuses existing tag
- **WHEN** the group has tag "40+" in category "Age Group" and the CSV column header is `tag:Age Group:40+` (exact category, tag with matching normalized form)
- **THEN** the existing tag is used; no new tag is created

#### Scenario: Missing category and tag are auto-created
- **WHEN** the group has no category matching the CSV header's category segment
- **THEN** a new `TagCategory` is created with the original casing from the CSV header, and a new `Tag` is created within it

#### Scenario: Existing category, missing tag — only tag is created
- **WHEN** the group has the matching category but no matching tag within it
- **THEN** the existing category is reused and only a new `Tag` is created

#### Scenario: Missing category, same-named tag exists under a different category — new category and tag are created
- **WHEN** the group has a tag named "40+" under category "NTRP" but the CSV header is `tag:Age Group:40+` and no "Age Group" category exists
- **THEN** a new "Age Group" category is created and a new "40+" tag is created within it; the existing "40+" under "NTRP" is not affected

### Requirement: CSV import assigns tags to players during row insertion
For each player row, tag cells with value `"true"` (case-insensitive, trimmed) SHALL result in a `PlayerTag` record being created for the player. Empty or missing tag cells SHALL result in no assignment. Any other value SHALL cause a row error. Tag assignment occurs within the same transaction as player creation. The transaction is wrapped using `Ash.transact/3` (not `Repo.transaction/1` or `Ecto.Multi`) to stay within Ash's data layer and ensure notifications fire correctly after commit.

#### Scenario: "true" cell value causes tag assignment
- **WHEN** a player row has `"true"` in a tag column
- **THEN** a `PlayerTag` record is created linking the player to that tag after the player is created

#### Scenario: Empty cell causes no tag assignment
- **WHEN** a player row has `""` or a missing value in a tag column
- **THEN** no `PlayerTag` record is created for that column

#### Scenario: Invalid tag cell value causes a row error
- **WHEN** a player row has a value other than `"true"` or `""` in a tag column (e.g., `"yes"`, `"1"`, `"x"`)
- **THEN** the import fails with `{:error, :row_error, line, "..."}` identifying the column and the invalid value

#### Scenario: All cell values are trimmed before parsing
- **WHEN** a tag cell contains `" true "` (with surrounding whitespace)
- **THEN** it is treated as `"true"` after trimming

#### Scenario: Import transaction rolls back player creation on failure
- **WHEN** a tag cell on row 5 has an invalid value after rows 1–4 have been processed
- **THEN** the entire import is rolled back and no players are created

### Requirement: Tag column headers and all cell values are trimmed before parsing
The import SHALL trim leading and trailing whitespace from all header names and cell values before any parsing or validation occurs.

#### Scenario: Header with surrounding whitespace is recognized
- **WHEN** a CSV header is `"  tag:Age Group:40+  "` (with surrounding whitespace)
- **THEN** it is recognized as the tag column `tag:Age Group:40+` after trimming

#### Scenario: Category and tag name segments in headers are trimmed
- **WHEN** a CSV header is `tag: Age Group : 40+ ` (with internal whitespace around delimiters)
- **THEN** the category is resolved as `"Age Group"` and the tag as `"40+"` after trimming each segment

### Requirement: Successful import returns player, auto-created category, and auto-created tag counts
On success, `import_csv/2` SHALL return `{:ok, %{players: N, categories_created: X, tags_created: Y}}` where `N` is the number of players created, `X` is the number of `TagCategory` records auto-created during resolution, and `Y` is the number of `Tag` records auto-created during resolution. Records that were found and reused are not counted in either field. The import UI SHALL surface any non-zero counts in the success message (e.g., "Created 18 players. Created 2 tag categories. Created 7 tags."). Zero counts for categories and tags MAY be suppressed — the UI is not required to say "Created 0 tag categories" when no auto-creation occurred.

#### Scenario: Import with no new categories or tags reports zero for both counts
- **WHEN** all tag headers matched existing categories and tags and no auto-creation occurred
- **THEN** the result is `{:ok, %{players: N, categories_created: 0, tags_created: 0}}`
- **AND** the UI success message SHALL include the player count and MAY omit mention of tag categories and tags

#### Scenario: Import with auto-created categories and tags reports counts separately
- **WHEN** 2 new `TagCategory` records and 7 new `Tag` records were auto-created during resolution and 18 players were imported
- **THEN** the result is `{:ok, %{players: 18, categories_created: 2, tags_created: 7}}`
- **AND** the UI success message SHALL include all three counts

#### Scenario: New tag under existing category increments only tags_created
- **WHEN** a CSV header resolves to an existing category but a new tag is created within it
- **THEN** `categories_created` is 0 and `tags_created` is 1
- **AND** the UI success message SHALL include the tag count and MAY omit mention of tag categories

#### Scenario: Import with no tag columns reports zero for both counts
- **WHEN** the CSV has no tag columns
- **THEN** the result is `{:ok, %{players: N, categories_created: 0, tags_created: 0}}`
- **AND** the UI success message SHALL include the player count and MAY omit mention of tag categories and tags
