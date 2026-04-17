## 1. Router and Redirect

- [ ] 1.1 Add four new settings routes to `router.ex`: `/settings`, `/settings/schedule`, `/settings/lineup`, `/settings/members`
- [ ] 1.2 Remove the old `live "/g/:group_slug/teams/:id/edit", Teams.EditLive, :edit` route

## 2. Shared Infrastructure

- [ ] 2.1 Create `TennisTrackerWeb.TeamComponents` module (or extend if it exists) with a `settings_layout/1` component that renders the four-tab nav bar and `render_slot(@inner_block)`. Attrs: `current_page`, `team`, `current_group`.
- [ ] 2.2 Create a shared helper (e.g., `TennisTrackerWeb.Teams.Settings.Helpers`) with a function that loads the team by ID, checks permissions (can_update_team, can_manage_slots, can_manage_captains), and returns either a map of assigns or a redirect instruction.

## 3. General Tab

- [ ] 3.0 Update the `Team` `:update` action policy to authorize `TennisTracker.Policies.IsTeamCaptainOfSelf` in addition to `IsGroupOwner`.
- [ ] 3.1 Create `lib/tennis_tracker_web/live/teams/settings/general_live.ex` — mounts with team + permissions, renders name/timezone/assignment_mode form. Use `Ash.can?` on the `:update` action to determine editability: if the user can perform the action, all three fields are editable; otherwise the form is rendered read-only (disabled) with no submit button.
- [ ] 3.2 Wire validate and save events for the General form (can reuse logic from `Teams.EditLive` `save_team` and `save_assignment_mode` handlers, consolidated into one form submission).

## 4. Match Schedule Tab

- [ ] 4.1 Create `lib/tennis_tracker_web/live/teams/settings/schedule_live.ex` — loads upcoming and past matches, renders the match list with add/delete affordances.
- [ ] 4.2 Port the match-related event handlers from `Teams.EditLive` to `ScheduleLive`: `open_match_form`, `close_match_form`, `validate_match`, `save_match`, `show_delete_match_modal`, `hide_delete_match_modal`, `delete_match`.

## 5. Lineup Settings Tab

- [ ] 5.1 Create `lib/tennis_tracker_web/live/teams/settings/lineup_live.ex` with assigns: `lineup_columns`, `lineup_slots`, `slot_modal` (nil | `{:add, col_id}` | `{:edit, slot_id}`), `slot_form`, `slot_to_delete` (nil | `%TeamLineupSlot{}`), `column_modal` (nil | `:add` | `{:edit, column_id}`), `column_form`, `column_to_delete` (nil | `%TeamLineupColumn{}`).
- [ ] 5.2 Implement the render function using card-per-category layout: iterate `@lineup_columns`, group `@lineup_slots` by `team_lineup_column_id`, render each category as an expanded card with its slots nested inside.
- [ ] 5.3 Add "Add slot" button per category card that fires `open_add_slot_modal` with the column_id. Add `handle_event("open_add_slot_modal", ...)` that sets `slot_modal: {:add, col_id}` and builds an `AshPhoenix.Form.for_create` with the column pre-selected.
- [ ] 5.4 Add edit button per slot row that fires `open_edit_slot_modal` with the slot_id. Add `handle_event("open_edit_slot_modal", ...)` that sets `slot_modal: {:edit, slot_id}` and builds an `AshPhoenix.Form.for_update`.
- [ ] 5.5 Add `handle_event("close_slot_modal", ...)` that clears `slot_modal` and `slot_form`.
- [ ] 5.6 Add `validate_slot_modal` and `save_slot_modal` handlers that validate/submit the `slot_form`. On save success: close modal, reload `lineup_slots`.
- [ ] 5.7 Implement column management event handlers using the modal pattern:
  - `open_add_column_modal`: sets `column_modal: :add`, builds `AshPhoenix.Form.for_create`
  - `open_edit_column_modal`: sets `column_modal: {:edit, column_id}`, builds `AshPhoenix.Form.for_update`
  - `close_column_modal`: clears `column_modal` and `column_form`
  - `validate_column_modal` / `save_column_modal`: validate/submit `column_form`; on success close modal and reload `lineup_columns`
  - `show_delete_column_modal`: sets `column_to_delete` to the column struct (only reachable when column has no slots)
  - `hide_delete_column_modal`: clears `column_to_delete`
  - `delete_column`: deletes the column, clears `column_to_delete`, reloads `lineup_columns`
  - `move_column_up` / `move_column_down`: reorder columns; disable up for first, down for last
  Render the delete button as disabled when `Enum.any?(@lineup_slots, & &1.team_lineup_column_id == column.id)`.
- [ ] 5.8 Port slot reorder handlers: `move_slot_up`, `move_slot_down`. Reorder is restricted within a category — a slot cannot move past the first or last position in its category. Disable the up button for the first slot in a category and the down button for the last slot in a category.
- [ ] 5.9 Add delete slot confirmation modal: `show_delete_slot_modal` sets `slot_to_delete` to the slot struct; `hide_delete_slot_modal` clears it to nil; `delete_slot` deletes the slot, clears `slot_to_delete`, and reloads `lineup_slots`.
- [ ] 5.10 Render the slot modal in the template — a `<.modal>` that renders the slot form with name, expected_count, include_in_clipboard, participation_type, and category dropdown fields.

## 6. Members Tab

- [ ] 6.1 Create `lib/tennis_tracker_web/live/teams/settings/members_live.ex` — loads captains stream and candidate members.
- [ ] 6.2 Port captain management event handlers from `Teams.EditLive`: `select_captain_candidate`, `add_captain`, `remove_captain`, `confirm_remove_entirely`, `confirm_convert_to_member`, `cancel_remove`.

## 7. Update Existing Links and Remove Old Code

- [ ] 7.1 Update `matches/edit_live.ex`: change any `push_navigate` targets from `/teams/:id/edit` to `/teams/:id/settings`.
- [ ] 7.2 Update `matches/show_live.ex`: change any navigate links from `/teams/:id/edit` to `/teams/:id/settings`.
- [ ] 7.3 Update `matches/lineup_edit_live.ex`: change any navigate links from `/teams/:id/edit` to `/teams/:id/settings`.
- [ ] 7.4 Update `teams/show_live.ex`: change any navigate links from `/teams/:id/edit` to `/teams/:id/settings`.
- [ ] 7.5 Delete `lib/tennis_tracker_web/live/teams/edit_live.ex`.

## 8. Tests

- [ ] 8.1 Rewrite `test/tennis_tracker_web/live/teams/edit_live_test.exs` — split into tests for each new settings LiveView at the correct routes.
- [ ] 8.2 Rewrite `test/tennis_tracker_web/live/teams/slot_management_test.exs` — update URLs to `/settings/lineup` and update slot form interactions to use the modal flow.
- [ ] 8.3 Rewrite `test/tennis_tracker_web/live/teams/captain_management_test.exs` — update URLs to `/settings/members`.
- [ ] 8.4 Update `test/tennis_tracker_web/live/matches/edit_live_test.exs` if it asserts on the `/teams/:id/edit` back-navigation URL.
- [ ] 8.5 Update `test/tennis_tracker_web/live/matches/lineup_edit_test.exs` if it asserts on the `/teams/:id/edit` back-navigation URL.
- [ ] 8.6 Run `mix test` and fix any remaining failures.
