## Why

Users need a way to export their tennis player roster to CSV for use in external tools (spreadsheets, reporting, other apps). Currently, data can only be viewed in the app with no way to extract it.

## What Changes

- Add a "Export to CSV" button/link on the players list page
- The export respects the currently active filters (name search, NTRP rating, age bracket) and sort order shown in the browser
- Implement a controller action that queries players using the same filter parameters and streams a CSV response
- CSV includes all relevant player fields (name, ranking, etc.)

## Capabilities

### New Capabilities

- `player-csv-export`: Download all players as a CSV file via a browser-triggered HTTP request

### Modified Capabilities

<!-- none -->

## Impact

- `lib/tennis_tracker_web/` — new controller action or LiveView event for CSV download
- `lib/tennis_tracker/` — query through existing Ash domain functions
- No new dependencies required (Elixir stdlib `NimbleCSV` or built-in CSV module)
- No database schema changes
