## Context

**Primary files touched:**
- `lib/tennis_tracker/tennis/team_lineup_slot.ex` — attribute change + constraint update
- `lib/tennis_tracker/tennis/match_lineup_assignment.ex` — all `is_exclusion_slot` references
- `lib/tennis_tracker/tennis/team.ex` — default slot creation on team create uses `is_exclusion_slot`
- `lib/tennis_tracker/tennis.ex` — new domain function for season stats
- `lib/tennis_tracker_web/live/matches/lineup_edit_live.ex` — drawer, sort, prev/next, stats load
- `lib/tennis_tracker_web/live/matches/show_live.ex` — filters out exclusion slots for display
- `lib/tennis_tracker_web/live/teams/edit_live.ex` — slot CRUD UI, exclusion slot delete guard

**Existing domain functions that compose into stats:**
- `Tennis.list_all_matches_for_team!/1` — all matches for a team, sorted by date ASC
- `Tennis.list_memberships_for_team!/1` — roster members with player loaded
- `Tennis.list_lineup_slots_for_team!/1` — slot definitions including participation type
- `Tennis.list_assignments_for_match!/1` — all assignments for one match

---

## Goals / Non-Goals

**Goals:**
- Replace the binary `is_exclusion_slot` with a three-value `participation_type` that cleanly handles sub, duty, and any other neutral role a team defines
- Compute per-player season participation stats scoped to one team
- Add a sortable stats drawer to the lineup editor that updates live as assignments change
- Add prev/next match navigation to the lineup editor

**Non-Goals:**
- Mobile layout for the stats drawer (open question, deferred)
- Per-player target match counts (no `desired_matches` field)
- Forfeit tracking
- Stats visible outside the lineup editor (e.g. on the match show page or team page)

---

## Decisions

### 1. `participation_type` as an Ash enum type

**Decision:** Add `lib/tennis_tracker/tennis/participation_type.ex` using `use Ash.Type.Enum, values: [:playing, :out, :neutral]`, matching the pattern of `HomeOrAway`. Replace the `is_exclusion_slot` boolean attribute on `TeamLineupSlot` with `participation_type` defaulting to `:playing`.

**Migration:** Generate with `mix ash_postgres.generate_migrations --name replace_exclusion_slot_with_participation_type`. The auto-generated migration adds the column but won't handle the data migration. Manually add to the `up` function:

```sql
UPDATE team_lineup_slots SET participation_type = 'out' WHERE is_exclusion_slot = true;
UPDATE team_lineup_slots SET participation_type = 'playing' WHERE is_exclusion_slot = false;
```

Then drop `is_exclusion_slot`. The `down` function reverses this.

**Constraint update:** The "only one exclusion slot per team" constraint currently checks `is_exclusion_slot == true`. It becomes `participation_type == :out`. No change to the constraint logic shape, only the field being checked.

**Immutability:** `participation_type` is set at slot creation and cannot be changed afterward. The slot edit form (rename, reorder) omits the `participation_type` field entirely. This avoids mid-season stats mutation — changing a neutral slot to playing would silently alter historical participation counts.

**All call sites:**

| File | Change |
|------|--------|
| `TeamLineupSlot` | attribute + constraint |
| `MatchLineupAssignment` | `slot.is_exclusion_slot` → `slot.participation_type == :out` (3 occurrences) |
| `Team` | default slot creation: `is_exclusion_slot: true` → `participation_type: :out` |
| `LineupEditLive` | `& &1.is_exclusion_slot` → `& &1.team_lineup_slot.participation_type == :out` |
| `ShowLive` | `Enum.reject(& &1.is_exclusion_slot)` → reject where `participation_type == :out` |
| `EditLive` (teams) | delete guard: `slot.is_exclusion_slot` → `slot.participation_type == :out` |

---

### 2. Season stats computation in Elixir, not SQL

**Decision:** Add `Tennis.season_stats_for_team!/3` that accepts a pre-loaded `all_matches` list (fetched by `load_board` for prev/next navigation), queries only the assignments, then aggregates in Elixir.

```elixir
Tennis.season_stats_for_team!(team_id, all_matches, tenant: group_id, actor: current_user)
# returns %{
#   total_matches: integer,
#   by_player: %{player_id => %{
#     played_past:   integer,
#     played_future: integer,
#     out:           integer,
#     neutral:       %{slot_name => integer}   # only includes slots with count > 0; drawer derives columns from slot definitions and defaults absent keys to 0
#   }}
# }
```

**Why Elixir aggregation, not SQL:** The neutral slot breakdown requires grouping by slot name, which varies per team and would require dynamic SQL or multiple queries. The full dataset is small — a season is at most ~15 matches × ~14 players = ~200 assignments. Elixir aggregation is clear, testable in isolation, and fast enough.

**Scoping:** Uses the `team_id` from the current match. Past vs future is determined by comparing `match.match_start_datetime` against `DateTime.utc_now()` in Elixir — no separate past/future queries needed.

**Neutral slot name uniqueness:** The neutral stats map keys on `team_lineup_slot.name`. Name uniqueness per team is already enforced by the existing `identity(:unique_slot_name_per_team, [:team_id, :name])` on `TeamLineupSlot` — no new constraint needed.

**Implementation note:** This is a plain `def` in `tennis.ex`, not an Ash `define`. It cannot be generated by Ash because it takes non-Ash inputs and returns a plain map — there is no corresponding Ash read action.

**Where it's called:** Inside `load_board/2` in `LineupEditLive`, which already runs after every assignment change. `load_board` fetches all team matches once (for prev/next navigation and `total_matches`), then passes that list directly into `season_stats_for_team!`. The function only queries assignments — no duplicate match fetch.

**Implementation sketch:**

```elixir
def season_stats_for_team!(team_id, all_matches, opts) do
  now = DateTime.utc_now()
  total_matches = length(all_matches)
  matches_by_id = Map.new(all_matches, &{&1.id, &1})

  assignments =
    MatchLineupAssignment
    |> Ash.Query.filter(match.team_id == ^team_id)
    |> Ash.Query.load([:team_lineup_slot])
    |> Ash.read!(...)

  by_player =
    Enum.group_by(assignments, & &1.player_id)
    |> Map.new(fn {player_id, assignments} ->
      stats = Enum.reduce(assignments, %{played_past: 0, played_future: 0, out: 0, neutral: %{}}, fn a, acc ->
        case Map.fetch(matches_by_id, a.match_id) do
          :error -> acc
          {:ok, match} ->
            past? = DateTime.before?(match.match_start_datetime, now)
            case a.team_lineup_slot.participation_type do
              :playing -> if past?, do: %{acc | played_past: acc.played_past + 1},
                                   else: %{acc | played_future: acc.played_future + 1}
              :out     -> %{acc | out: acc.out + 1}
              :neutral -> %{acc | neutral: Map.update(acc.neutral, a.team_lineup_slot.name, 1, & &1 + 1)}
            end
        end
      end)
      {player_id, stats}
    end)

  %{total_matches: total_matches, by_player: by_player}
end
```

---

### 3. Stats drawer as a component inside `LineupEditLive`

**Decision:** Implement the stats drawer as a private `defp stats_drawer(assigns)` component within `LineupEditLive`, not a separate LiveComponent. It shares the LiveView's assigns directly, so live updates are automatic — no message passing needed.

**New assigns on the LiveView:**

| Assign | Type | Purpose |
|--------|------|---------|
| `:stats_open` | boolean | Drawer toggle state |
| `:stats_sort` | atom | `:name` \| `:total_asc` \| `:total_desc` \| `:out_desc` |
| `:season_stats` | map | Return value of `season_stats_for_team!` |
| `:prev_match` | Match \| nil | Adjacent match for navigation |
| `:next_match` | Match \| nil | Adjacent match for navigation |

**Layout:** The outer board wrapper becomes `flex flex-row`. The board scrolls horizontally as today. The stats drawer sits alongside at a fixed width (`w-80` or similar), visible only when `@stats_open`. On small screens, it would obscure the board — that's an acceptable known limitation until mobile is addressed.

**Toggle button:** A small button in the lineup editor header bar, to the right of the "Back" link and match title. Something like a table/list icon. Sends `toggle_stats` event.

**Neutral columns:** Derived from the team's slot definitions loaded in `load_board` — all slots where `participation_type == :neutral`. A column is shown for every neutral slot on the team, even if all player counts are zero. Computed once in the LiveView and passed to the drawer component.

---

### 4. Prev/next navigation from the all-matches list

**Decision:** Load all matches for the team when building the board (needed anyway for `total_matches`). Find the current match's index in the sorted list to derive `prev_match` and `next_match`.

```elixir
all_matches = Tennis.list_all_matches_for_team!(team_id, ...)
current_index = Enum.find_index(all_matches, &(&1.id == match.id))
prev_match = if current_index && current_index > 0, do: Enum.at(all_matches, current_index - 1)
next_match = if current_index, do: Enum.at(all_matches, current_index + 1)
```

Navigation uses `<.link navigate={~p"/g/.../matches/#{match.id}/lineup-edit"}>` so the LiveView remounts with the new match. The stats drawer's open/closed state resets on navigation (LiveView remount). This is acceptable — the drawer stays open within a session of editing one match, but navigating is a fresh start. If this proves annoying in practice, it can be persisted in the URL.

---

## Risks / Trade-offs

- **`is_exclusion_slot` is referenced in 6+ places.** Missing one would cause a runtime error on slot create/delete or silent stats miscounting. The task list calls each one out explicitly.
- **Stats load on every `load_board` call.** `load_board` already runs after every assignment change. Adding a second query (all assignments for the team) on each change is a minor increase. At season scale (200 rows) this is negligible, but it's worth noting if the call frequency ever becomes a concern.
- **No existing test coverage for slot participation type logic.** The `MatchLineupAssignment` constraint tests (if any) will need updating. New stats function needs its own tests.
