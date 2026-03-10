## 1. Shared Filter Logic

- [x] 1.1 Extract player filter functions (`maybe_filter_name`, `maybe_filter_ntrp`, `maybe_filter_bracket`) from `IndexLive` into a shared module (e.g., `TennisTracker.Tennis.PlayerFilters`)
- [x] 1.2 Update `IndexLive` to call the shared filter module instead of its private functions
- [x] 1.3 Add a `parse_list_param/1` helper to the shared module (or keep in a shared web helper) so the controller can reuse it

## 2. CSV Export Controller

- [x] 2.1 Add a `PlayerCSVController` (or `PlayersController`) with a `export/2` action at `GET /players/export.csv`
- [x] 2.2 In the controller action, parse filter params from query string (`name`, `ntrp`, `bracket`) using the shared parse helpers
- [x] 2.3 Query players using the shared filter module, ordered by `name ASC`
- [x] 2.4 Build CSV content: header row (`name,email,phone_number,ntrp_rating,eligible_18_plus,eligible_40_plus,eligible_55_plus`) followed by one row per player
- [x] 2.5 Return response with `content-type: text/csv` and `content-disposition: attachment; filename="players.csv"`

## 3. Router

- [x] 3.1 Add `get "/players/export.csv", PlayerCSVController, :export` to the router (before the LiveView catch-all for `/players/:id`)

## 4. UI

- [x] 4.1 Add an "Export CSV" link in the `IndexLive` header actions that points to `/players/export.csv` with the current filter params encoded as query string

## 5. Tests

- [x] 5.1 Unit test the shared filter module: verify each filter type (name, ntrp, bracket, combined) returns correct players
- [x] 5.2 Controller test: export with no filters returns all players as CSV with correct headers
- [x] 5.3 Controller test: export with NTRP + bracket filters returns only matching players
- [x] 5.4 Controller test: export with no matching players returns header-only CSV
- [x] 5.5 Controller test: response has correct `content-type` and `content-disposition` headers
