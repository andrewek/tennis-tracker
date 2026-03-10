## Context

The players index page uses `PlayerFilters.fetch_players/3` for both the LiveView and the CSV export controller. Filters are encoded in URL query params and managed via `push_patch`. The current NTRP filter only supports rated players (2.5–5.0) and the sort direction is hardcoded to descending.

## Goals / Non-Goals

**Goals:**
- Allow filtering for players with no NTRP rating via a "No rating" checkbox
- Allow toggling NTRP sort between ascending and descending (default: descending)
- Add a handful of unrated players to the seed file

**Non-Goals:**
- Sort direction controls for any column other than NTRP
- Persisting sort preference across sessions
- Changing the CSV export sort behavior (it inherits whatever `fetch_players` does)

## Decisions

**"No rating" filter as a sentinel string value**
The NTRP filter param is a comma-separated list of strings. `"none"` will be used as the sentinel value for unrated players. `PlayerFilters.maybe_filter_ntrp/2` will be updated to:
1. Detect `"none"` in the list and build an OR condition: `ntrp_rating in ^rated_list OR is_nil(ntrp_rating)`
2. If only `"none"` is present, filter `WHERE ntrp_rating IS NULL`

Alternatives considered: a separate `unrated=true` param. Rejected because the existing list-param pattern is simpler and keeps `filter_url` unified.

**Sort direction as URL param `ntrp_sort`**
A new `ntrp_sort` assign (`:asc` or `:desc`) is read from the `ntrp_sort` query param (`"asc"` / `"desc"`). Defaults to `"desc"` when absent. A small toggle button/link near the NTRP column header triggers `toggle_ntrp_sort` event → `push_patch` with updated param. `fetch_players/4` gains a fourth `ntrp_sort` argument.

**Seed unrated players as explicit records**
Add 3–5 named players with `ntrp_rating: nil` to `seeds.exs` below the existing pool-based seeding, using the same idempotent name-check guard.

## Risks / Trade-offs

- [Risk] "No rating" + rated filters combined → the query uses an OR, which is slightly more complex but straightforward with Ash.Query fragment or `or_filter`. Mitigation: keep rated and unrated filter branches explicit.
- [Risk] CSV export inherits the new sort direction default but callers currently don't pass `ntrp_sort`. Mitigation: `fetch_players/4` defaults `ntrp_sort` to `:desc` so existing callers are unaffected unless they pass the param.
