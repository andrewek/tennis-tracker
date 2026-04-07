## Context

The match-lineups change shipped a working lineup setter: `TeamLineupSlot` (name, sort_order, expected_count, include_in_clipboard), `MatchLineupAssignment` (match_id, player_id, team_lineup_slot_id), a full-screen drag-and-drop board at `/matches/:id/lineup-edit`, and a read-only section on the match show page. The board reuses `BoardComponents` unchanged.

Three structural gaps emerged from modeling real league formats:

1. **No slot grouping** — for 18+ USTA (7 slots: S1, S2, D1–D3, Sub, Out) the flat board is too wide. A string `slot_group` field was considered and rejected because strings carry no ordering — group order would be coupled to slot order.
2. **No multi-slot support** — the DB-level `identity(:player_per_match, [:match_id, :player_id])` on `MatchLineupAssignment` unconditionally prevents a player from appearing in more than one slot per match. High school and informal formats require relaxing this.
3. **No exclusion semantics** — "Out" is currently just a slot name. Nothing prevents a player from being in both "Out" and "#1 Singles" simultaneously.

The data model additions (`TeamLineupColumn`, `lineup_assignment_mode`, `is_exclusion_slot`) have already been migrated and seeded. This document covers the remaining implementation decisions for the UI and constraint enforcement.

## Goals / Non-Goals

**Goals:**
- Group slots into named columns with independent sort ordering
- Enforce `is_exclusion_slot` on assignment: exclusion ↔ playing slots are mutually exclusive
- Replace the `player_per_match` DB identity with mode-aware application-layer validation
- Embed the lineup board on the match show page (captain sees board, member sees read-only)
- Adapt the board layout to grouped columns (vertical slots within horizontal column groups)
- Add tap-to-assign interaction for mobile
- Expose column management and `lineup_assignment_mode` in the team edit UI

**Non-Goals:**
- Per-match slot overrides (slots remain team-level)
- Drag-to-reorder columns or slots (move-up/move-down buttons, as in v1)
- Lineup history or audit trail
- Notifications when a lineup is set
- Multi-player pairing within a slot (e.g. doubles partner matching)

## Decisions

### TeamLineupColumn is a first-class resource, not a slot attribute

**Decision:** Column grouping is a separate resource (`TeamLineupColumn`) with its own `name` and `sort_order`, rather than a `slot_group` string field on `TeamLineupSlot`.

**Rationale:** A string field has no inherent ordering — you would need to bolt on a secondary sort field, coupling slot order to group order. With a first-class resource, column order is independent: reordering columns doesn't require touching every slot in those columns.

**Alternative considered:** `display_column` integer + `column_label` string on each slot. Rejected — the label would need to be consistent across all slots in a group (two sources of truth), and renaming a column would require updating every slot in it.

---

### Slots must be assigned to a column

**Decision:** `TeamLineupSlot.team_lineup_column_id` is required. A slot cannot be created or saved without a column assignment. Captains must create at least one column before defining lineup slots.

**Rationale:** Requiring a column keeps the board well-structured — there are no slots that exist but cannot appear on the board. With all slots in columns, the board faithfully represents the team's full lineup configuration.

**Empty columns:** A column with no slots assigned is valid and shown on the team settings page. It is not rendered on the lineup board.

---

### Changing `lineup_assignment_mode` is blocked when existing assignments would violate the new mode

**Decision:** When a captain updates a team's `lineup_assignment_mode` to a more restrictive mode, the change is blocked if any existing `MatchLineupAssignment` records across any of the team's matches would violate the new constraint. The captain must resolve conflicting assignments before the mode change is accepted.

**Validation logic per target mode:**
- `:one_per_match` — block if any match has a player with more than one assignment.
- `:one_per_column` — block if any match has a player with more than one assignment in the same column.
- `:many_per_match` — no check needed (least restrictive; all existing data is valid).

**Rationale:** Silently destroying assignments would surprise captains. Grandfathering violations would leave the lineup board in an inconsistent state. Blocking with an actionable error message keeps the captain in control.

---

### `lineup_assignment_mode` enforced at the application layer, not DB

**Decision:** The three modes (`:one_per_match`, `:one_per_column`, `:many_per_match`) are enforced by a custom Ash validation in `MatchLineupAssignment.create`, not by DB unique constraints. The `player_per_match` identity is dropped when multi-slot UI is shipped.

**Rationale:** DB unique constraints cannot be conditional on a related record's field. A partial index on `(match_id, player_id) WHERE ...` could theoretically work for `:one_per_match`, but the logic would live in raw SQL migration rather than Ash, breaking the resource-as-source-of-truth convention. Application-layer validation keeps all constraint logic in Elixir where it is testable.

**Race condition window:** Two concurrent captains could both pass the application-layer check and both insert — violating `:one_per_match`. This is acceptable: matches are edited by one captain in practice, and a lineup collision is low-stakes (easily corrected). A DB baseline constraint `(match_id, player_id, team_lineup_slot_id)` prevents exact duplicates in all modes.

**Constraint logic per mode:**
- `:one_per_match` — check no existing assignment for `(match_id, player_id)`. Upsert: if player already has an assignment, update `team_lineup_slot_id` in place (existing `assign_to_slot` upsert behavior).
- `:one_per_column` — check no existing assignment where the target slot's column matches an existing assignment's slot's column for this `(match_id, player_id)`. Load target slot's column; query existing assignments and their slot columns. Block if collision.
- `:many_per_match` — no extra check beyond the baseline `(match_id, player_id, team_lineup_slot_id)` uniqueness.

---

### `assign_to_slot` upsert behavior changes per mode

**Decision:** The domain function `assign_to_slot/3` currently upserts on `player_per_match` — if the player has any assignment for this match, it updates the slot. With multi-slot modes, the semantics change:
- `:one_per_match` — preserve existing upsert behavior.
- `:one_per_column` / `:many_per_match` — create a new assignment (do not update existing ones). Removing from a slot is a separate explicit operation.

**Consequence:** `move_lineup_player` in the board LiveView must apply different semantics per mode:
- `:one_per_match` — always a move: update the player's existing assignment to the target slot.
- `:one_per_column`, cross-column drag — an add: create a new assignment in the target column without removing the existing assignment in the source column.
- `:one_per_column`, same-column drag — a move within the column: destroy the player's existing assignment in that column and create a new one for the target slot. The captain's intent is to reposition, not to double-book.
- `:many_per_match` — always an add: create a new assignment regardless of source.

---

### Exactly one exclusion slot per team, always assigned to a column

**Decision:** Every team's lineup definition has exactly one slot where `is_exclusion_slot == true`. That slot must always be assigned to a column. Creating a second exclusion slot is rejected. Deleting the sole exclusion slot is rejected.

**Auto-provisioning:** When a team is created, a default "Reserve" column (sort_order: 1) and a default "Out" exclusion slot in that column are created automatically. Captains can rename the column and slot or reassign the slot to a different column, but cannot delete either until the slot is no longer the exclusion slot (which is never allowed).

**Rationale:** The exclusion slot represents "this player is out for the match" — there is only one such concept per lineup. Auto-provisioning it at team creation ensures the board always has a way to mark a player out from day one, without requiring captain setup before the lineup is usable.

---

### `is_exclusion_slot` enforcement is on-write, not read-time

**Decision:** Exclusion enforcement happens in the `MatchLineupAssignment.create` (and update) action, not as a filter on read.

**Enforcement rules:**
- Assigning to a playing slot when the player is in an exclusion slot → hard block (return error).
- Assigning to an exclusion slot when the player is in one or more playing slots → auto-remove playing slot assignments, then assign to exclusion slot.

**Rationale:** Auto-removing playing assignments on exclusion assignment mirrors the semantic intent ("this player is out for the match") and eliminates the need for the captain to manually un-assign first. Blocking in the other direction (playing → out) is safe because playing assignments shouldn't be accidentally created for an out player.

**Definition:** A playing slot is any slot where `is_exclusion_slot == false`.

---

### Available column is mode-aware

**Decision:** The board LiveView computes the Available column differently per mode:

- `:one_per_match` — current behavior: `all_members − assigned_players`.
- `:one_per_column` — Available column shows all non-excluded members always, regardless of playing slot assignments. Player cards display small column badges (e.g. "S", "D") for their current column assignments.
- `:many_per_match` — Available column shows all members who are not assigned to the exclusion slot, regardless of playing slot assignments.

**Consequence for the LiveView:** The Available column's data must be recomputed differently based on `team.lineup_assignment_mode`. The socket assign `:available` carries different semantics per mode. The player card component receives an `:assignments` list in `:one_per_column` mode to render badges.

---

### Lineup board location — deferred

**Decision:** The grouped lineup board is implemented in `LineupEditLive` at `/matches/:id/lineup-edit` for this change. Embedding the board on the match show page and retiring `LineupEditLive` is deferred to a follow-on change once the new board functionality is validated.

**Rationale:** Separating the board migration from the functional changes reduces risk. The new grouped layout, mode enforcement, and tap-to-assign can be fully exercised on the existing page before taking on the LiveView restructuring.

---

### Tap-to-assign for mobile

**Decision:** On touch devices, drag-and-drop is unreliable. A tap-to-assign interaction is added: tap a player card to select it (highlighted ring), then tap a destination slot's drop zone to assign. Tap the same player again to deselect.

**Implementation:** The HTML5 drag API does not fire on touch screens — the browser provides a natural desktop/mobile split. A `phx-click` handler on each player card sets/clears `socket.assigns.selected_player_id`. A `phx-click` handler on each slot drop zone, when `selected_player_id` is set, calls `assign_to_slot`. Both interactions fire `move_lineup_player` on the server — same handler.

**No feature detection needed:** Drag-and-drop and tap-to-assign coexist. On desktop both are technically available but drag is more ergonomic; on mobile only tap works. No UA sniffing required.

---

### Column management on team edit page

**Decision:** The team edit page gains a "Lineup Columns" section above the existing "Lineup Slots" section. A captain can create columns (name required), rename columns inline, reorder via move-up/move-down, and delete columns (only when the column has no slots assigned — an error is shown if slots remain). Captains must reassign or delete all slots in a column before deleting the column. Slots can be reassigned to a column via a dropdown on each slot row.

**sort_order assignment:** When a new column is created, its sort_order is assigned as `MAX(sort_order) + 1` across the team's existing columns, or `1` if no columns exist yet. Gaps in the sort_order sequence are acceptable — only relative order matters. Move-up/move-down swaps the sort_order values of the two adjacent columns; no renumbering of other columns occurs.

**Slot deletion:** Deleting a slot cascades to destroy all `MatchLineupAssignment` records referencing that slot across all matches. The captain sees a confirmation dialog warning that existing match assignments will be removed. The exclusion slot cannot be deleted.

**`lineup_assignment_mode`** is a select input in a new "Lineup Settings" section of the team edit page, editable by captains and group owners only.

## Risks / Trade-offs

- **Race condition on `:one_per_column` and `:many_per_match`** → Two concurrent writes can both pass the application-layer check. Mitigation: baseline `(match_id, player_id, team_lineup_slot_id)` identity prevents exact duplicate assignments. For the column-scoped check, a collision is low-stakes and easily corrected manually. Accept.

- **Column deletion blocked when slots assigned** → A column can only be deleted when it has no slots. Captains must reassign or delete all slots in a column before deleting it. The UI shows an error if deletion is attempted while slots remain, preventing accidental stranding of slots.

- **`assign_to_slot` upsert behavior changes break `:one_per_match` teams that upgrade** → The upsert on `player_per_match` currently moves a player from one slot to another in a single DB call. Dropping that identity requires the LiveView to issue an explicit unassign + assign. This is a behavioral change in the drag handler, not a data migration. Mitigation: implement `:one_per_match` upsert logic in the new `assign_to_slot` (load existing, update in place if found).

## Migration Plan

1. Data model additions are already migrated (`TeamLineupColumn`, `is_exclusion_slot`, `lineup_assignment_mode`).
2. Ship `is_exclusion_slot` enforcement (validation in `MatchLineupAssignment.create`).
3. Drop `player_per_match` identity, add `player_per_slot_per_match` identity, implement mode-aware application-layer validation in `MatchLineupAssignment.create`.
4. Update `assign_to_slot` to handle `:one_per_match` upsert without relying on the identity.
5. Add column management to the team edit page.
6. Implement new grouped board layout component.
7. Add tap-to-assign interaction.

**Rollback:** All data model changes are additive. If the new board is reverted, the `/matches/:id/lineup-edit` route and `LineupEditLive` can be restored. The `lineup_assignment_mode` column defaults to `:one_per_match` so all existing behavior is preserved.

## Open Questions

*All resolved.*

- **Column deletion with assigned slots:** Resolved — column deletion is blocked when slots are assigned. Captains must clear the column first.
- **Available column badges:** Resolved — show the full column name as the badge label. Column names are typically short and few in number.
- **No-columns fallback:** Resolved — all slots must belong to a column. If a team has no columns defined yet, no slots can be created. The board renders no lineup columns (only the Available column header is shown) until at least one column with slots exists.
