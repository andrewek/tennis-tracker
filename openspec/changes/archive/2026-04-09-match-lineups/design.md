## Context

The app has Match, Team, Player, and TeamMembership resources with a fully working Roster Planner (drag-and-drop board) that reuses `BoardComponents` (`board_column`, `player_card`, `DraggableCard`/`DropZone` JS hooks). No lineup or slot concept currently exists.

Team captains need a way to assign players to named match positions and share a formatted lineup with their team. Different league formats have different slot structures (18+ gender: S1, S2, D1, D2, D3; 40+: S1, D1, D2, D3; mixed/tri-level: D1, D2, D3; informal: C1–C4 with 4 players). Slot structures are stable within a season — they are defined once per team and reused for every match.

## Goals / Non-Goals

**Goals:**
- Define named lineup slots on a team (persisted, reused across all matches for that team)
- Assign players to slots for a specific match via a drag-and-drop board
- Copy a formatted lineup text block to the clipboard from the match show page
- Warn when a slot's assignment count does not match its expected_count (if set)

**Non-Goals:**
- Per-match slot overrides (slots always come from the team definition)
- Hard enforcement of expected_count (no blocking drops — consistent with Roster Planner)
- Explicit per-match availability tracking beyond "assigned to Out slot"
- Sub-slot pairing within multi-player courts

## Decisions

### Slots live on Team, not TeamType or Match

**Decision:** `TeamLineupSlot` belongs to `Team`.

**Rationale:** Teams are already season-scoped via `season_year`. A team's slots naturally inherit that scope — no extra work needed. TeamType-level slots would require every team of the same type to share slots, which is too rigid. Per-match slots would require re-entering them for every match, which is too tedious. Team-level is the right granularity.

**Alternative considered:** A "slot template" resource that gets copied to each match on creation. Rejected — adds model complexity and doesn't help the stated use case (formats almost never change mid-season).

---

### No intermediate Lineup record

**Decision:** `MatchLineupAssignment` holds `match_id`, `player_id`, `team_lineup_slot_id` directly — no parent `Lineup` record.

**Rationale:** There is exactly one lineup per match (since each match belongs to one team). An intermediate record adds a join with no behavioral benefit. The "Available" pool is derived: team members with no `MatchLineupAssignment` for the match.

---

### `include_in_clipboard` boolean on slot (not a slot type enum)

**Decision:** Slots have an `include_in_clipboard` boolean rather than a type enum like `:playing | :administrative`.

**Rationale:** Keeps the model uniform — Out and Sub are slots like any other. Captains can create custom non-clipboard slots (e.g. "Emergency Sub") without needing a new enum variant. A boolean flag is also easier to toggle in the UI.

---

### Reuse BoardComponents without modification

**Decision:** The lineup setter board uses existing `board_column`, `player_card`, `DraggableCard`, and `DropZone` hooks unchanged.

**Rationale:** These were explicitly designed for reuse (the `BoardComponents` docstring mentions "Lineup Setter" as a planned consumer). The Roster Planner established the pattern: columns = destinations, cards = players, drop → `move_player` event → Ash mutation. A new drop event name (`"move_lineup_player"`) is configured via the `data-drop-event` attribute, already supported by the existing hook.

**Available column sentinel:** The Available column uses `target_id="unassigned"` — matching the Roster Planner convention. When the `move_lineup_player` handler receives `target_id == "unassigned"` it calls `unassign_from_lineup/2`; any other value is treated as a slot ID and calls `assign_to_slot/3`.

---

### sort_order auto-assigned on slot creation

**Decision:** When a captain creates a new slot, `sort_order` is automatically set to `coalesce(max(existing sort_order), -1) + 1` for that team — so the first slot gets `sort_order = 0`, subsequent slots increment from there. Captains do not supply `sort_order` in the create form.

**Rationale:** Requiring captains to enter a sort number manually is poor UX and risks duplicates. New slots naturally belong at the end; the reorder controls handle any subsequent position changes.

---

### Slot reorder via move-up / move-down buttons

**Decision:** The slot management UI on the team edit page uses move-up and move-down buttons to reorder slots — no drag-to-reorder.

**Rationale:** Move-up/move-down is simpler to implement (two LiveView click handlers that swap `sort_order` values) and requires no additional JS hook. The slot list is typically short (4–6 entries) so drag-to-reorder's ergonomic advantage is minimal.

---

### expected_count warnings, consistent with Roster Planner

**Decision:** When a slot has a non-nil `expected_count` and its assignment count does not exactly match it (either under or over), render a warning indicator on the column header. No drop is ever blocked. Slots with nil `expected_count` never show a warning.

**Rationale:** Captains shuffle players around frequently. Hard enforcement would create friction (you'd have to move someone out before moving someone in). The Roster Planner uses the same approach for NTRP violations — warn, don't block. Warnings on both under and over (not just over) reflect that the captain cares about filling the slot correctly, not just preventing overflow.

---

### Real-time sync via Ash.Notifier.PubSub

**Decision:** `MatchLineupAssignment` is configured with `Ash.Notifier.PubSub`. The `MatchLineupEditLive` LiveView subscribes to the topic `"lineup:#{group_id}:#{match_id}"` on mount (when connected) and handles `%Ash.Notifier.Notification{}` by reloading assignments and re-deriving the Available pool. The match show page does not subscribe — it loads assignments once on mount and reflects a snapshot.

**Rationale:** Matches are commonly viewed by multiple people simultaneously — a captain assigning players while teammates watch. The pattern mirrors the Roster Planner exactly: the Ash resource emits a notification on every create/update/destroy; all subscribed LiveViews (including the initiating session) reload. No manual broadcast or special-casing of the originating session is needed.

**Topic format:** `"lineup:#{group_id}:#{match_id}"`

**pub_sub block configuration on `MatchLineupAssignment`:**
```elixir
pub_sub do
  module(Phoenix.PubSub)
  name(TennisTracker.PubSub)
  prefix("lineup")

  publish(:create, [:group_id, :match_id])
  publish(:update, [:group_id, :match_id])
  publish(:destroy, [:group_id, :match_id])
end
```

**Scope:** Only `MatchLineupAssignment` mutations broadcast on this topic. `TeamLineupSlot` changes (which happen on the team edit page) do not trigger board reload in v1. Only `MatchLineupEditLive` subscribes; the match show page does not.

---

### Lineup setter is a dedicated page

**Decision:** The drag-and-drop lineup assignment board lives at `/matches/:id/lineup-edit`, not as a section of the match show page. The match show page renders a read-only summary of current assignments and a "Edit Lineup" link for captains.

**Rationale:** Separates the editing surface from the viewing surface, mirrors the existing match show / match edit page split, and eliminates the need to conditionally render two very different UIs (draggable board vs. read-only list) inside one LiveView based on a `can_edit_lineup` flag.

**Route:** `live "/matches/:id/lineup-edit", MatchLineupEditLive` (alongside the existing `live "/matches/:id/edit"`).

---

### Authorization for the lineup edit page

**Decision:** The `MatchLineupEditLive` `mount/3` or `handle_params/3` checks `Ash.can?({MatchLineupAssignment, :create, %{group_id: group_id, match_id: match_id}}, current_user, domain: Tennis, tenant: group_id)`. If the check fails, redirect to the match show page.

**Rationale:** Non-captains should not reach the edit board at all — no need for a read-only board variant inside `MatchLineupEditLive`. The match show page already provides the read-only view. Passing the input map `%{group_id: group_id, match_id: match_id}` satisfies the create-action convention from CLAUDE.md (no existing record available).

---

### Clipboard copy is available to all group members

**Decision:** The "Copy Lineup" button is visible and functional for all group members, not just captains.

**Rationale:** Copying is a read operation — it formats already-visible data. Restricting it to captains would provide no security benefit (anyone can type out what they see on screen) and would prevent members from easily sharing the lineup.

---

### Clipboard generation is server-side

**Decision:** The formatted lineup text is computed in Elixir and stored in a socket assign (`@lineup_text`). It is rendered in the page as a hidden `<textarea>`. A JS hook on the "Copy Lineup" button reads the text directly from that element and calls `navigator.clipboard.writeText(text)`. On success the hook pushes a `"clipboard_copied"` event to the server, which responds with a `"Copied!"` flash message. On failure the hook reveals the hidden `<textarea>` so the user can select-all and copy manually — no extra server roundtrip needed for the fallback.

**Rationale:** The server already has all the data (slot order, player names, match datetime/location). Formatting in Elixir is simpler to test. Storing the text in a pre-rendered `<textarea>` means the fallback requires no modal or server event — the element is already in the DOM.

**Clipboard date/time format:** Use `MatchHelpers.format_match_datetime/2` to produce the date and time strings (e.g. `"Sun, Mar 29"` and `"2:00 PM"`), keeping output consistent with the rest of the app. The header line format is `"{date_str} · {time_str} ({venue_name})"`, e.g. `Sun, Mar 29 · 2:00 PM (Genesis Westroads)`.

**Slot format:** Each clipboard-included slot is rendered as the slot `name` followed by a colon on its own line, then one player name per line. Players are sorted alphabetically by full name. An empty slot renders the slot name line followed by `---` on the next line. Slots are separated by a blank line.

Example:
```
Sun, Mar 29 · 2:00 PM (Genesis Westroads)

#1 Doubles:
Rafael Nadal
Novak Djokovic

#1 Singles:
---

Out:
Andy Murray
```

**Empty-state clipboard:** When the team has no lineup slots defined, `@lineup_text` contains only the match header line. The "Copy Lineup" button remains visible and functional.

## Risks / Trade-offs

- **Slot deletion with existing assignments** → If a captain deletes a slot that has existing `MatchLineupAssignment` records, those assignments become orphaned (slot FK is gone). Mitigation: cascade delete assignments when a slot is deleted. Accept data loss — the captain explicitly chose to delete the slot.

- **Slots shared across all matches** → If a captain needs a one-off slot for a single match, they cannot — slots are team-level in v1. Mitigation: none in v1; per-match overrides are explicitly out of scope.

- **Clipboard API availability** → `navigator.clipboard.writeText` requires a secure context (HTTPS or localhost). In dev this is fine; in production the app should already be HTTPS. Fallback: the lineup text is pre-rendered as a hidden `<textarea>` in the DOM; if the clipboard write fails, the JS hook reveals it so the user can copy manually without any server roundtrip.

## Migration Plan

1. Generate and run two new Ash migrations: `team_lineup_slots` table, `match_lineup_assignments` table
2. No changes to existing tables — purely additive
3. No data migration required
4. Rollback: drop the two new tables
