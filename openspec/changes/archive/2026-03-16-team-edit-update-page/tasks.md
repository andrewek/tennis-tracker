## 1. Ash Layer

- [x] 1.1 Add `update :update` action to `Match` resource (accept: opponent, home_or_away, match_start_datetime, timezone, duration_minutes, location_id)
- [x] 1.2 Add `destroy :destroy` action to `Match` resource
- [x] 1.3 Add `define(:update_match, action: :update)` to the Tennis domain
- [x] 1.4 Add `define(:destroy_match, action: :destroy)` to the Tennis domain

## 2. Shared Helper

- [x] 2.1 Create `TennisTrackerWeb.MatchHelpers` module with both `format_match_datetime/2` and `build_match_datetime_params/3` extracted from `Teams.ShowLive`
- [x] 2.2 Replace both helpers in `Teams.ShowLive` with `import TennisTrackerWeb.MatchHelpers`
- [x] 2.3 Replace `format_match_datetime/2` in `Matches.ShowLive` with `import TennisTrackerWeb.MatchHelpers`

## 3. Router

- [x] 3.1 Add `live "/teams/:id/edit", Teams.EditLive, :edit` route
- [x] 3.2 Add `live "/matches/:id/edit", Matches.EditLive, :edit` route

## 4. Teams.EditLive

- [x] 4.1 Create `lib/tennis_tracker_web/live/teams/edit_live.ex`
- [x] 4.2 Mount: load team with `Ash.get` + load only `:team_type` (not full roster — roster is not displayed here); redirect to `/` with flash if pseudo or not found; initialize team settings form via `AshPhoenix.Form.for_update/3`; stream upcoming and past matches
- [x] 4.3 Handle `validate_team` and `save_team` events for the name/timezone form; on success show flash "Team updated." and refresh form
- [x] 4.4 Handle `open_match_form` / `close_match_form` / `validate_match` / `save_match` events (moved from ShowLive); use `import TennisTrackerWeb.MatchHelpers`; on save success re-stream both match lists and flash "Match added."
- [x] 4.5 Handle `show_delete_match_modal` / `hide_delete_match_modal` events with a `:match_to_delete` assign (set to the `%Match{}` struct fetched by ID via `Ash.get`)
- [x] 4.6 Handle `delete_match` event: call `Tennis.destroy_match/1` with the loaded `%Match{}` from assigns, re-stream both match lists, clear `:match_to_delete`, flash "Match deleted."
- [x] 4.7 Render: team settings form — name text input + timezone select with 7 US zones: Eastern (America/New_York), Central (America/Chicago), Mountain (America/Denver), Mountain - no DST (America/Phoenix), Pacific (America/Los_Angeles), Alaska (America/Anchorage), Hawaii (Pacific/Honolulu)
- [x] 4.8 Render: upcoming matches stream — each row shows opponent, date/time, location; "Edit" link (`<.link navigate>`) to `/matches/:id/edit`; "Delete" button that fires `show_delete_match_modal` with the match ID
- [x] 4.9 Render: past matches stream — same row structure as upcoming
- [x] 4.10 Render: Add Match modal (same form fields as was in ShowLive)
- [x] 4.11 Render: delete confirmation modal (`:if={@match_to_delete}`) following the same pattern as player deletion in `Players.ShowLive` — Delete (btn-error) and Cancel buttons
- [x] 4.12 Render: back link to `/teams/:id`

## 5. Teams.ShowLive

- [x] 5.1 Remove `open_match_form`, `close_match_form`, `validate_match`, `save_match` event handlers
- [x] 5.2 Remove match form modal from the template
- [x] 5.3 Remove `:show_match_form`, `:form`, `:locations`, `:team_timezone` assigns from `mount/3`
- [x] 5.4 Remove `build_match_datetime_params/3` and `format_match_datetime/2` private functions; add `import TennisTrackerWeb.MatchHelpers`
- [x] 5.5 Add "Edit Team" link to `/teams/:id/edit` in the page header area
- [x] 5.6 Remove "Add Match" button from the upcoming matches section header

## 6. Matches.EditLive

- [x] 6.1 Create `lib/tennis_tracker_web/live/matches/edit_live.ex`
- [x] 6.2 Mount: load match via `Ash.get` + load `[:team, :location]`; redirect to `/` with flash if not found; initialize update form via `AshPhoenix.Form.for_update/3`; assign `:team_timezone` from `match.timezone` (not `team.default_timezone` — editing uses the timezone the match was originally created with)
- [x] 6.3 Handle `validate_match` event using `import TennisTrackerWeb.MatchHelpers` for `build_match_datetime_params/3`; use `match.timezone` from assigns as the timezone
- [x] 6.4 Handle `save_match` event: call `AshPhoenix.Form.submit/2` → on success redirect to `/teams/#{team_id}/edit` with flash "Match updated."
- [x] 6.5 Handle `show_delete_modal` / `hide_delete_modal` events (same pattern as `Players.ShowLive`)
- [x] 6.6 Handle `delete_match` event: call `Tennis.destroy_match/1` with the loaded match from assigns → redirect to `/teams/#{team_id}/edit` with flash "Match deleted."
- [x] 6.7 Render: form with opponent (text), home/away (select), date (date), time (time), location (select) fields; pre-populate date and time by converting `match.match_start_datetime` from UTC to `match.timezone`
- [x] 6.8 Render: delete confirmation modal following `Players.ShowLive` pattern
- [x] 6.9 Render: back link to `/teams/:id/edit`

## 7. Matches.ShowLive

- [x] 7.1 Add `import TennisTrackerWeb.MatchHelpers`; remove local `format_match_datetime/2`
- [x] 7.2 Add "Edit Match" link to `/matches/:id/edit` on the page

## 8. Tests

- [x] 8.1 `Teams.EditLive`: page loads pre-populated with team name and timezone
- [x] 8.2 `Teams.EditLive`: valid name + timezone update saves and shows flash
- [x] 8.3 `Teams.EditLive`: blank name shows validation error, does not save
- [x] 8.4 `Teams.EditLive`: pseudo-team ID redirects to `/` with flash
- [x] 8.5 `Teams.EditLive`: non-existent team ID redirects to `/` with flash
- [x] 8.6 `Teams.EditLive`: add match via modal appears in match list with flash
- [x] 8.7 `Teams.EditLive`: delete match removes it from list and shows flash
- [x] 8.8 `Matches.EditLive`: page loads pre-populated with match fields
- [x] 8.9 `Matches.EditLive`: non-existent match ID redirects to `/` with flash
- [x] 8.10 `Matches.EditLive`: valid update redirects to `/teams/:id/edit` with flash
- [x] 8.11 `Matches.EditLive`: invalid update (blank opponent) shows validation error
- [x] 8.12 `Matches.EditLive`: delete redirects to `/teams/:id/edit` with flash
- [x] 8.13 `Teams.ShowLive` (update existing tests): assert no "Add Match" button; assert "Edit Team" link is present
- [x] 8.14 `TennisTracker.Tennis.MatchTest`: update and destroy actions
