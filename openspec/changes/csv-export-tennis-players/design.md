## Context

The players index page (`/players`) is a LiveView with name search, NTRP rating, and age bracket filters encoded as URL query params (`?name=&ntrp=3.5,4.0&bracket=55`). Players are fetched via Ash domain queries. There is already a CSV import flow for reference.

The export must reflect what the user is currently viewing — same filters, same effective order — not a dump of all players.

## Goals / Non-Goals

**Goals:**
- Export the currently-filtered player list as a CSV download
- Pass active filter params from the LiveView to the download endpoint
- No new dependencies (use Elixir's built-in `NimbleCSV` already available, or stdlib)

**Non-Goals:**
- Exporting a specific page/chunk (export all matching records, not just visible page)
- Custom column selection
- Async/background export job (roster sizes are small; synchronous is fine)
- Sorting beyond what filters already imply

## Decisions

### Plain HTTP controller action, not a LiveView event

**Decision**: Add a `GET /players/export.csv` controller action. The "Export CSV" link in the LiveView includes current filter params as query string: `href="/players/export.csv?#{current_params}"`.

**Why**: CSV downloads require a proper HTTP response with `content-disposition: attachment`. LiveView cannot send file downloads directly. A controller action is the standard Phoenix pattern for this.

**Alternative considered**: `send_download/3` via a LiveView `handle_event` with a temporary file — more complex, requires temp file cleanup, no advantage at this scale.

### Filter params passed via query string

**Decision**: The export link is a plain `<a href>` (or `<.link href>`) that mirrors the current URL params into the export URL. The controller re-runs the same Ash query logic using those params.

**Why**: The filter state already lives in URL params on the index page. Reusing them for the export keeps the two in sync automatically. No additional LiveView assigns or JS hooks needed.

### Share filter logic via a module function

**Decision**: Extract the player filtering query into a shared function in the `Tennis` domain or a dedicated `PlayerFilters` module, called by both the LiveView and the CSV controller.

**Why**: Avoids duplicating the `maybe_filter_name/maybe_filter_ntrp/maybe_filter_bracket` logic. Single source of truth for what "matching players" means.

## Risks / Trade-offs

- [Large roster] If a club has thousands of players, a synchronous CSV response could be slow → Acceptable for foreseeable use; can add streaming later if needed.
- [Filter drift] If the LiveView filter logic changes without updating the shared function, export and display could diverge → Mitigated by sharing the function.
- [No sort guaranteed] DB query order is not deterministic without an explicit `ORDER BY` → Add `ORDER BY name ASC` so exports are consistently ordered.
