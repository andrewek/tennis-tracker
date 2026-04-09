## 1. TeamLineupSlot Resource

- [x] 1.1 Create `TeamLineupSlot` Ash resource with attributes: `name` (string, required, max 12 chars, unique per team), `expected_count` (nullable integer), `sort_order`, `include_in_clipboard` (boolean, default true), `group_id` (multitenancy), `team_id`
- [x] 1.2 Add unique identity on `(team_id, name)` — slot names must be unique within a team
- [x] 1.3 Add `belongs_to :team` relationship on `TeamLineupSlot`
- [x] 1.4 Add `has_many :lineup_slots` relationship on `Team`
- [x] 1.5 Define CRUD actions on `TeamLineupSlot` with authorization: captains and group owners can create/update/destroy; group members can read
- [x] 1.6 Generate and run migration for `team_lineup_slots` table
- [x] 1.7 Add domain functions: `list_lineup_slots_for_team/2`, `create_lineup_slot/2`, `update_lineup_slot/3`, `delete_lineup_slot/2`
- [x] 1.8 Write tests for TeamLineupSlot CRUD, authorization, and name validation (blank, too long, duplicate within team)

## 2. MatchLineupAssignment Resource

- [x] 2.1 Create `MatchLineupAssignment` Ash resource with attributes: `group_id` (multitenancy), `match_id`, `player_id`, `team_lineup_slot_id`
- [x] 2.2 Add relationships: `belongs_to :match`, `belongs_to :player`, `belongs_to :team_lineup_slot`
- [x] 2.3 Add unique identity `:player_per_match` on `(match_id, player_id)` — a player can only be in one slot per match
- [x] 2.4 Define CRUD actions with authorization: captains and group owners can create/update/destroy; group members can read
- [x] 2.4a Configure `Ash.Notifier.PubSub` on `MatchLineupAssignment` with `prefix("lineup")`, publishing create/update/destroy on `[:group_id, :match_id]`
- [x] 2.5 Generate and run migration for `match_lineup_assignments` table (with cascade delete from `team_lineup_slots`)
- [x] 2.6 Add domain functions: `list_assignments_for_match/2`, `assign_to_slot/3` (Ash upsert using `upsert?: true, upsert_identity: :player_per_match, upsert_fields: [:team_lineup_slot_id]` on the create action), `unassign_from_lineup/2`
- [x] 2.7 Write tests for MatchLineupAssignment CRUD, authorization, and upsert behavior

## 3. Slot Management UI on Team Edit Page

- [x] 3.1 Add a lineup slots section to the team edit LiveView
- [x] 3.2 Render the slot list in sort_order with name, expected_count, include_in_clipboard fields
- [x] 3.3 Add empty state when no slots exist with prompt to add first slot
- [x] 3.4 Implement add-slot form (inline or modal) using `AshPhoenix.Form.for_create`; sort_order is auto-assigned server-side (max + 1), not included in the form
- [x] 3.5 Implement inline edit per slot using `AshPhoenix.Form.for_update`
- [x] 3.6 Implement delete slot with confirmation; handle cascade of assignments
- [x] 3.7 Implement move-up / move-down buttons per slot; swap sort_order values between adjacent slots and persist
- [x] 3.8 Hide slot management section from non-captains (use `Ash.can?` for authorization check)
- [x] 3.9 Write LiveView tests for slot management (create, edit, reorder, delete, auth)

## 4. Read-Only Lineup Section on Match Show Page

- [x] 4.1 Add a read-only lineup section to the match show LiveView; load team lineup slots and match assignments on mount in slot sort_order
- [x] 4.2 Render current assignments as a static list (slot name + assigned player names); show unassigned slots as empty
- [x] 4.3 Show "Edit Lineup" link to `/matches/:id/lineup-edit` for captains only (gate with `Ash.can?`)
- [x] 4.4 Show empty state when team has no slots; captains see a link to the team edit page, non-captains see the message only
- [x] 4.5 Write LiveView tests for read-only section (renders assignments, captain link visible, no link for non-captains, empty state variants)

## 5. Lineup Setter Board — Dedicated Edit Page

- [x] 5.1 Create `MatchLineupEditLive` LiveView and register route `live "/matches/:id/lineup-edit", MatchLineupEditLive`
- [x] 5.2 In `mount/3` or `handle_params/3`, check `Ash.can?({MatchLineupAssignment, :create, %{group_id: group_id, match_id: match_id}}, current_user, domain: Tennis, tenant: group_id)`; redirect non-captains to the match show page
- [x] 5.3 Load team lineup slots and match assignments on mount; derive "Available" pool (team members with no assignment for this match)
- [x] 5.4 Render board using `BoardComponents.board_column` — one "Available" column and one column per slot in sort_order
- [x] 5.5 Render player cards using `BoardComponents.player_card` with `DraggableCard` hook in each column
- [x] 5.6 Configure `DropZone` hook with `data-drop-event="move_lineup_player"` on each column
- [x] 5.7 Handle `"move_lineup_player"` event: parse `player_id` and `target_id`; call `assign_to_slot/3` or `unassign_from_lineup/2` accordingly
- [x] 5.8 Implement expected_count warning: compare assignment count to slot expected_count; pass warning to `board_column` when count != expected_count and expected_count is non-nil
- [x] 5.9 Show empty state when team has no lineup slots with a link to the team edit page
- [x] 5.10 Subscribe to `"lineup:#{group_id}:#{match_id}"` in `mount` when `connected?(socket)`; handle `%Ash.Notifier.Notification{}` by reloading assignments and re-deriving the Available pool
- [x] 5.11 Write LiveView tests for lineup board (assign, move, unassign, expected_count warning, empty state, non-captain redirect)
- [x] 5.12 Write LiveView test for real-time sync: simulate a `%Ash.Notifier.Notification{}` broadcast and assert the board reflects the updated assignment

## 6. Clipboard Copy

- [x] 6.1 Implement server-side lineup text formatter: match date/time/venue header, then for each `include_in_clipboard = true` slot in sort_order: slot name + colon on one line, then one player name per line sorted alphabetically (or `---` if no players assigned); slots separated by a blank line
- [x] 6.2 Add a colocated JS hook on the "Copy Lineup" button: read lineup text from the pre-rendered hidden `<textarea>`, call `navigator.clipboard.writeText(text)`, on success push `"clipboard_copied"` event to the server, on failure reveal the hidden `<textarea>` for manual copy
- [x] 6.3 Handle `"clipboard_copied"` server event: respond with `put_flash(socket, :info, "Copied!")`
- [x] 6.4 Render the formatted lineup text in a hidden `<textarea>` in the match show lineup section (always present, revealed only on clipboard failure)
- [x] 6.5 Add "Copy Lineup" button to the match show lineup section; attach the copy hook; keep it visible in all states including empty state (header-only text)
- [x] 6.6 Write unit tests for the clipboard text formatter
- [x] 6.7 Write LiveView test for clipboard fallback: simulate clipboard failure and assert the textarea is revealed
