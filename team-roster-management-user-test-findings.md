# User Test Findings: team-roster-management

**Tested:** 2026-05-02
**Branch:** team-roster-management-enhancements
**App:** http://localhost:4000
**Account used:** mainowner@example.com (group owner)

## Summary

12 passed · 1 failed · 5 blocked · 8 skipped

The tab bar, roster display, health summary, authorization guards, and remove flow all work correctly. The **Add Player panel is broken** — the candidate list is empty due to a LiveView stream / conditional rendering bug. All add-flow tests are blocked as a result.

---

## Results

### Delta Spec Tests

| # | Scenario | Result | Notes |
|---|----------|--------|-------|
| 1 | Tab bar renders all five tabs | PASS | General, Match Schedule, Lineup Settings, Roster, Members |
| 2 | Roster tab is styled as active | PASS | Bold + underline indicator |
| 3 | Clicking Roster tab navigates to /settings/roster | PASS | |
| 4 | Group owner navigates to Roster tab | PASS | Page loads with roster data |
| 5 | Team captain navigates to Roster tab | BLOCKED | captain@example.com has no group membership in DB — seeds partially applied |
| 6 | Group member (non-captain, non-owner) is redirected | PASS | Flash: "You don't have permission to manage this team's roster." |
| 7 | Members listed with name and NTRP rating | PASS | e.g. "Aaron Blake 4.5" |
| 8 | Health summary shows roster size and on-level % | PASS | "On-Level % 100%" · "Roster Size 10 / 10–18" |
| 9 | Add Player panel lists eligible candidates | **FAIL** | Panel opens but candidate list is always empty — see failure detail below |
| 10 | Adding a player creates membership and appears in roster | BLOCKED | Depends on #9 |
| 11 | NTRP not in allowed levels — eligibility warning | BLOCKED | Depends on #9 |
| 12 | NTRP in allowed levels — no eligibility warning | BLOCKED | Depends on #9 |
| 13 | Off-level add drops below threshold — warning shown | BLOCKED | Depends on #9 |
| 14 | Add Player affordance not shown to group member | PASS | Member redirected before reaching page |
| 15 | Remove player (no match assignments) — removed | PASS | Paul Quinn removed from 4.0 A; count 12→11 |
| 16 | Cancelling remove leaves membership intact | PASS | |
| 17 | Group owner can remove a player | PASS | Same flow as #15 |
| 18 | Remove player assigned to match — inline error | PASS | "Cannot remove: player is assigned to a match lineup and cannot be removed from the roster." |

### Smoke Tests

| # | Scenario | Result | Notes |
|---|----------|--------|-------|
| 19 | General tab still renders correctly | PASS | Form present, all 5 tabs visible |
| 20 | Members tab still renders correctly | PASS | Loads cleanly |

### Skipped (Not Browser-Testable)

- `team-membership` action authorization scenarios (6 scenarios) — Ash action contracts; tested indirectly via UI behavior
- "Empty roster shows empty state" — all seeded teams have members
- "Empty roster — on-level percentage omitted" — same
- "No SeasonRules — roster size targets omitted" — all team types have SeasonRules in seeds
- "Player has nil NTRP — eligibility unknown note" — no nil-NTRP players in seeds
- "No SeasonRules — on-level impact omitted in add flow" — same

---

## Failures Requiring Attention

### FAIL: Add Player panel candidate list is always empty

**File:** `lib/tennis_tracker_web/live/teams/settings/roster_live.ex`

**Root cause:** The `<div id="candidate-list" phx-update="stream">` container is inside a `:if={@show_add_panel}` block. The `candidate_players` stream is populated once in `handle_params`, but when `open_add_panel` is fired (which just sets `show_add_panel: true`), the container is newly inserted into the DOM. LiveView does not replay already-dispatched stream events into a newly-mounted stream container — the items were sent before the container existed.

The DOM confirms it: `candidate-list` has 0 children and empty innerHTML even though the DB has ~61 eligible candidates for the 4.5 team.

**Fix options (pick one):**

1. **Always render the container, hide with CSS** — remove `:if` from the `candidate-list` div and instead toggle the parent panel with `display: none`. Stream events will always land in the mounted container.

2. **Reload candidates on panel open** — in the `open_add_panel` handler, reload and re-stream candidates with `reset: true`:
   ```elixir
   def handle_event("open_add_panel", _params, socket) do
     candidates = load_candidates(...)
     socket
     |> assign(:show_add_panel, true)
     |> stream(:candidate_players, candidates, reset: true)
     |> noreply()
   end
   ```

3. **Use a plain list assign instead of a stream** — candidates are not a large or real-time collection; a regular `@candidates` assign avoids the stream/conditional-render issue entirely.

---

## Additional Notes

### Seeds partially applied — captain user has no group membership

`captain@example.com` exists in the users table but has no `group_memberships` record for the "main" group. The team role record (captain of Main 18+ 4.5 and Main 18+ 4.0 B) is also absent. Running `mix run priv/repo/seeds.exs` should fix this.

Consequence: captain-specific authorization could not be browser-tested (test #5). All tested owner paths passed, and the policy code references `IsTeamCaptainCheck` / `IsTeamCaptain` which exist as compiled modules.

### Server restart was needed before testing

On first load, the roster page crashed: `ArgumentError: No such action add_to_roster on TennisTracker.Tennis.TeamMembership`. The running Phoenix server had a stale BEAM in memory from before the new actions were compiled. After restarting `mix phx.server`, the page worked correctly. Not a code defect — dev workflow artifact.

Screenshots saved in `tmp/`:
- `tmp/fail-01-tab-bar-missing-roster.png` — tab bar before server restart (4 tabs, no Roster)
- `tmp/fail-04-roster-page-crashes.png` — ArgumentError on stale server
- `tmp/add-player-panel-open.png` — empty candidate list (the FAIL)
- `tmp/remove-match-assigned-error.png` — inline error when removing match-assigned player (PASS)
- `tmp/pass-roster-tab-loaded.png` — roster tab working correctly after restart
