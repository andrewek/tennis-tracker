## 1. PlayerFilters — null-aware sort directions

- [x] 1.1 In `PlayerFilters.fetch_players/4`, replace `Ash.Query.sort(ntrp_rating: ntrp_sort, name: :asc)` with null-aware sort atoms: `:desc_nils_last` when descending, `:asc_nils_first` when ascending
- [x] 1.2 Verify the Ash null-sort atoms compile and produce the expected SQL by running the app and checking sort output with unrated players present

## 2. LiveView — translate URL param to null-aware atom

- [x] 2.1 In `IndexLive.handle_params/3`, update the `ntrp_sort` atom translation from `String.to_atom("asc"/"desc")` to pass `:asc_nils_first` for `"asc"` and `:desc_nils_last` for `"desc"`

## 3. Tests — update for correct null position

- [x] 3.1 Update the existing `PlayerFiltersTest` sort test ("returns players sorted by NTRP descending then name ascending") to assert unrated players appear after all rated players
- [x] 3.2 Add a `PlayerFiltersTest` test asserting unrated players appear before all rated players when `ntrp_sort` is `:asc_nils_first`
- [x] 3.3 Update `IndexLiveTest` sort tests that involve unrated players to assert the correct position (bottom for desc, top for asc)
