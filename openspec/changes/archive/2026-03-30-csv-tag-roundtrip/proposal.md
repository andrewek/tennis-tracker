## Why

Tags replaced the old boolean eligibility columns as the primary way to categorize players, but CSV export omits all tag data and import cannot restore it — making the CSV useless for cross-group player transfer, local dev round-trips, or sharing player lists with collaborators.

## What Changes

- **Validation**: Add a `:` prohibition to `TagCategory.name` and `Tag.name` (app-level Ash validation), making `:` a safe delimiter for CSV column headers
- **CSV export**: Add dynamic tag columns to the export — one column per tag for the group, sorted by category name then tag name, with `true`/`""` values; continues to respect active filters
- **CSV import**: Recognize `tag:CategoryName:TagName` column headers; validate format; resolve tags via case-insensitive find-or-create before inserting players; assign tags within the insert transaction
- **`todo.md`**: Add notes on deferred import upsert behavior and tag auto-creation rollback

## Capabilities

### New Capabilities

- `csv-tag-roundtrip`: Full round-trip CSV support for player tags — export includes all group tags as boolean columns; import recognizes, validates, resolves, and assigns those tag columns; portable across groups via name-based matching

### Modified Capabilities

- `player-csv-export`: Column headers now include dynamic `tag:Category:Tag` columns in addition to the existing base columns; export link encodes active tag filter params
- `tag-management`: `TagCategory.name` and `Tag.name` gain a `:` prohibition validation

## Impact

- **`TennisTrackerWeb.PlayerCSVController`**: Dynamic header generation, load tags on player fetch, boolean tag columns in rows
- **`TennisTracker.Tennis.PlayerCsvImport`**: Header validation expanded to handle tag columns; new tag resolution phase; `coerce_row` shape changes; `insert_all` creates `PlayerTag` records
- **`TennisTracker.Tennis.TagCategory`**: New `:` prohibition validation on `name`
- **`TennisTracker.Tennis.Tag`**: New `:` prohibition validation on `name`
- **`TennisTracker.Tennis` domain**: May need find-or-create actions on `TagCategory` and `Tag`
- **`openspec/changes/csv-tag-roundtrip/specs/player-csv-export/spec.md`**: Updated requirements for tag columns and tag filter encoding
