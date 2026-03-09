# CSV Import Feature for Tennis Players

## Overview

Add a CSV import feature so users can bulk-import tennis players from a CSV file.
Accessible via a button on the players index page (`/players`).

---

## CSV Format

Headers must match the writable schema field names exactly (case-sensitive):

| Header | Required? | Notes |
|---|---|---|
| `name` | Yes | Non-blank string |
| `email` | No | Optional string |
| `phone_number` | No | Optional string |
| `ntrp_rating` | No | One of: 2.5, 3.0, 3.5, 4.0, 4.5, 5.0 |
| `eligible_18_plus` | No | `true`/`false` (defaults to `true` if omitted) |
| `eligible_40_plus` | No | `true`/`false` (defaults to `false` if omitted) |
| `eligible_55_plus` | No | `true`/`false` (defaults to `false` if omitted) |

`id`, `inserted_at`, `updated_at` are not accepted (server-generated).

---

## Error Handling Rules

1. **Unknown headers** — any header not in the known set causes an immediate error before any
   records are imported. Message lists the unexpected header(s).

2. **Missing required headers** — if `name` is not present in the header row, error immediately.

3. **Partial columns** — a CSV with only `name` and `ntrp_rating` is fine. Missing optional
   columns use schema defaults. No error.

4. **Malformed / invalid row data** — validation runs row-by-row in order. On the first row
   that fails (blank name, invalid ntrp value, unparseable boolean, etc.) the import stops,
   reports the error and the file line number as it would appear in a text editor (header row
   = line 1, first data row = line 2, etc.), and rolls back any records inserted in that
   transaction.

5. **Duplicate records** — imported as-is; no uniqueness check. De-duplication is out of scope.

---

## Architecture

### New module: `TennisTracker.Tennis.PlayerCsvImport`

Path: `lib/tennis_tracker/tennis/player_csv_import.ex`

Responsibilities:
- Parse raw CSV binary using the stdlib `NimbleCSV` (already available via `nimble_csv`)
  or Elixir's built-in `CSV` — **check mix.exs first**; if neither is present, use the
  built-in `String.split`-based approach with `NimbleCSV` defined inline or add `nimble_csv`
  as a dependency.
- Validate headers against the known set.
- Parse and coerce each row into a map of player params.
- Run all creates inside a single `Ecto.Multi` / `Ash` transaction so a failure rolls back
  all inserts from that batch.

Public API:

```elixir
@spec import_csv(binary()) ::
  {:ok, count :: non_neg_integer()} |
  {:error, :invalid_headers, unknown_headers :: [String.t()]} |
  {:error, :missing_required_headers, missing :: [String.t()]} |
  {:error, :row_error, line :: pos_integer(), message :: String.t()}
```

Internal steps:
1. `parse_headers/1` — split first row, check for unknown/missing required headers.
2. `parse_rows/2` — zip each subsequent row with headers → list of param maps, returning
   `{:error, line, message}` on the first bad row. Line numbers are editor-style: header = 1,
   first data row = 2, etc.
3. `coerce_row/2` — convert string values to proper types:
   - booleans: `"true"` → `true`, `"false"` → `false`, anything else → error
   - ntrp_rating: parse decimal, validate it is one of the allowed values
   - name: reject blank/empty string
4. `insert_all/1` — iterate params, calling `Tennis.create_player/1` for each inside a
   `Repo.transaction/1`. On `{:error, changeset}` from any create, return `{:error, :row_error, line, message}` and the transaction rolls back.

> **Note on Ash transactions:** Ash resources with AshPostgres use the Ecto repo under the
> hood. We can wrap the loop in `TennisTracker.Repo.transaction/1`. Each `Tennis.create_player`
> call inside the transaction will participate in the same DB transaction, so a failure at any
> point rolls everything back.

---

### Router change

Add one route inside the existing `scope "/"` block:

```elixir
live "/players/import", Players.ImportLive, :import
```

Place it **before** `/players/:id` to avoid the import path being captured as an ID.

---

### New LiveView: `TennisTrackerWeb.Live.Players.ImportLive`

Path: `lib/tennis_tracker_web/live/players/import_live.ex`

State:

```elixir
@impl true
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:status, :idle)          # :idle | :success | :error
   |> assign(:result, nil)            # {:ok, n} | {:error, ...}
   |> allow_upload(:csv_file,
        accept: ~w(.csv),
        max_entries: 1,
        max_file_size: 1_000_000)}    # 1 MB limit
end
```

Events:
- `"validate"` (phx-change) — standard upload validation hook (no-op body, just `{:noreply, socket}`)
- `"import"` (phx-submit) — consume upload, read binary, call `PlayerCsvImport.import_csv/1`,
  set `:status` and `:result`.

On success: flash `:info` with "Imported N player(s)", `push_navigate` to `~p"/players"`.
On error: display error inline (no redirect).

Template displays:
- File input (`<.live_file_input upload={@uploads.csv_file} />`)
- Upload errors (wrong type, too large)
- Import error message with line number when `@status == :error`
- Submit button

---

### Index page change

Add an "Import CSV" button/link to the existing `IndexLive` that navigates to `/players/import`.

---

## Tests

### Unit: `test/tennis_tracker/tennis/player_csv_import_test.exs`

Uses `TennisTracker.DataCase`.

Test cases:
1. Valid CSV with all columns → `{:ok, 3}` (3 rows)
2. Valid CSV with only required + some optional columns → `{:ok, n}`
3. Unknown header → `{:error, :invalid_headers, ["bad_col"]}`
4. Missing required header (`name` absent) → `{:error, :missing_required_headers, ["name"]}`
5. Blank name on line 2 (first data row) → `{:error, :row_error, 2, _message}` and DB has no new players
6. Invalid ntrp_rating value on line 3 → `{:error, :row_error, 3, _message}`
7. Invalid boolean string for eligibility on line 3 → `{:error, :row_error, 3, _message}`
8. Rollback verification: 2 valid rows then 1 bad row → 0 players persisted
9. Duplicate rows → both inserted successfully

### LiveView: `test/tennis_tracker_web/live/players/import_live_test.exs`

Uses `TennisTrackerWeb.ConnCase`.

Test cases:
1. Renders the import form
2. Upload and submit a valid CSV → redirects to index, flash present
3. Upload a CSV with unknown headers → shows error message, no redirect
4. Upload a CSV with a bad row → shows error with line number, no redirect

---

## File Checklist

- [ ] Check `mix.exs` for CSV parsing library (`nimble_csv`, `csv`, etc.); add if missing
- [ ] `lib/tennis_tracker/tennis/player_csv_import.ex` — new module
- [ ] `lib/tennis_tracker_web/live/players/import_live.ex` — new LiveView
- [ ] `lib/tennis_tracker_web/router.ex` — add import route
- [ ] `lib/tennis_tracker_web/live/players/index_live.ex` — add Import CSV button
- [ ] `test/tennis_tracker/tennis/player_csv_import_test.exs` — unit tests
- [ ] `test/tennis_tracker_web/live/players/import_live_test.exs` — LiveView tests

---

## Decisions

1. **CSV library** — use `nimble_csv`. Add it as a dependency if not already in `mix.exs`.
2. **File size limit** — 1 MB.
3. **Max rows** — no cap.
4. **ntrp_rating blank** — treat empty string as `nil` (not an error). Only error on a
   non-empty, non-numeric value.
5. **Boolean blank** — treat an empty cell as `nil` and let the Ash schema default apply.
   No error.
