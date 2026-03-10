## Context

PostgreSQL places NULLs first by default for `DESC` sorts and last for `ASC` sorts. The current `fetch_players/4` uses `Ash.Query.sort(ntrp_rating: ntrp_sort, name: :asc)` with `ntrp_sort` as `:asc` or `:desc`, accepting the database defaults. This causes unrated players (NULL `ntrp_rating`) to float to the top of the list in the default descending sort — appearing above 5.0-rated players, which is unintuitive.

## Goals / Non-Goals

**Goals:**
- Unrated players appear below all rated players when NTRP sort is descending
- Unrated players appear above all rated players when NTRP sort is ascending

**Non-Goals:**
- Changing any other sort behavior
- Affecting the CSV export (inherits the fix automatically via `fetch_players/4`)

## Decisions

**Use Ash's built-in null-sort direction atoms**

Ash (via AshPostgres) supports extended sort direction atoms that map to PostgreSQL's `NULLS FIRST` / `NULLS LAST` syntax:

- `:desc_nils_last` → `ORDER BY ntrp_rating DESC NULLS LAST` — unrated players sink to the bottom
- `:asc_nils_first` → `ORDER BY ntrp_rating ASC NULLS FIRST` — unrated players rise to the top

`fetch_players/4` currently accepts `ntrp_sort` as `:asc` or `:desc`. We change it to accept `:asc_nils_first` or `:desc_nils_last` instead, and update callers (the LiveView) accordingly. The LiveView currently translates the URL param `"asc"` / `"desc"` to an atom — we update that translation in `handle_params/3`.

Alternatives considered:
- **Calculated column with COALESCE**: Replace NULL with a sentinel value (e.g., `-1.0`) for sorting. Rejected — it couples sort logic to the data model and makes the approach less transparent.
- **Raw SQL fragment**: `Ash.Query.sort(fragment("ntrp_rating DESC NULLS LAST"))`. Rejected — bypasses Ash's sort abstraction and would be harder to toggle dynamically.

## Risks / Trade-offs

- [Risk] Ash atom names may differ from what's documented above — `:asc_nils_first` / `:desc_nils_last` are conventional but need verification in the running project. Mitigation: test immediately; fall back to a COALESCE calculated attribute if unsupported.
- [Risk] Existing tests that assert sort order including unrated players will need updating. Mitigation: small, localized changes to the two test files already covering this.
