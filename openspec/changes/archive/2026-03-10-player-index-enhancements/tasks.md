## 1. Seed Data

- [x] 1.1 Add 4–5 unrated players (ntrp_rating: nil) to `priv/repo/seeds.exs` with the same idempotent name-check guard

## 2. PlayerFilters — "No rating" filter support

- [x] 2.1 Update `PlayerFilters.maybe_filter_ntrp/2` to handle `"none"` as a sentinel: when `"none"` is in the list and no rated values are present, filter `WHERE ntrp_rating IS NULL`; when `"none"` is present alongside rated values, use an OR condition to include both rated matches and NULL rows
- [x] 2.2 Add `ntrp_sort` parameter to `PlayerFilters.fetch_players/4` (default `:desc`) and apply it to the `Ash.Query.sort` call for `ntrp_rating`

## 3. Index LiveView — sort direction

- [x] 3.1 Add `ntrp_sort` assign (default `"desc"`) to `mount/3`
- [x] 3.2 Parse `ntrp_sort` from URL params in `handle_params/3` (accept `"asc"` or `"desc"`, default `"desc"`)
- [x] 3.3 Pass `ntrp_sort` through `fetch_players/4` and include it in `filter_url/2` and `export_url/3` helpers
- [x] 3.4 Add `toggle_ntrp_sort` event handler: flips `"asc"` ↔ `"desc"` and `push_patch`es with updated param

## 4. Index LiveView — "No rating" filter UI

- [x] 4.1 Add `"none"` entry to `@ntrp_ratings` list (display label "No rating") and update the NTRP filter loop to show the correct label for this entry

## 5. Index LiveView — NTRP sort direction toggle UI

- [x] 5.1 Add a sort direction toggle control (button or link) near the NTRP filter label that shows the current direction and fires `toggle_ntrp_sort` on click

## 6. Database Index

- [x] 6.1 Add a composite `custom_index [:ntrp_rating, :name]` to the `postgres` block in `Player` resource
- [x] 6.2 Generate migration with `mix ash_postgres.generate_migrations --name add_ntrp_name_index` and run `mix ecto.migrate`

## 7. Tests

- [x] 7.1 Add `PlayerFilters` unit tests for `"none"` only, `"none"` + rated, and rated-only scenarios (verifying unrated players are included/excluded correctly)
- [x] 7.2 Add LiveView integration tests for the "No rating" checkbox showing/hiding unrated players
- [x] 7.3 Add LiveView integration tests for NTRP sort direction toggle (default desc, toggle to asc, toggle back)
