## Tasks

- [x] 1. Add `next_upcoming_match_for_team` read action to `Match` (same filter as `list_upcoming_matches_for_team`, limit 1, sort asc); expose as `get_next_upcoming_match_for_team` via `define` in the `Tennis` domain
- [x] 2. Update teams index LiveView to load next match for each team after fetching teams; store as `@next_matches` map (team_id → match or nil)
- [x] 3. Replace "Next match: TBD" placeholder in team card template with real date/time from `@next_matches`, falling back to "Next match: TBD" when nil
- [x] 4. Update teams index LiveView tests: add case for team with upcoming match showing date/time; verify TBD still shown when no matches
