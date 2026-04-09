## 1. User.name attribute

- [x] 1.1 Add optional `:name` attribute (string, nullable) to the `User` Ash resource
- [x] 1.2 Generate and run the migration (`mix ash_postgres.generate_migrations --name add_user_name`)
- [x] 1.3 Add `:name` to the `update` action's `accept` list on `User` (or add a dedicated `update_profile` action)

## 2. GroupMembership read policy

- [x] 2.1 Extend `GroupMembership` read policy to authorize any group member (add `authorize_if(TennisTracker.Policies.IsGroupMember)`)

## 3. TeamRole policy expansion

- [x] 3.1 Extend `TeamRole` read policy to authorize any group member (add `authorize_if(TennisTracker.Policies.IsGroupMember)`)
- [x] 3.2 Create `TennisTracker.Policies.IsTeamCaptainForTeamRoleCheck` SimpleCheck — reads `team_id` and `group_id` from the create changeset, queries TeamRole to verify actor is `:captain` for that team
- [x] 3.3 Add `authorize_if(TennisTracker.Policies.IsTeamCaptainForTeamRoleCheck)` to the `TeamRole` create policy
- [x] 3.4 Add `authorize_if(TennisTracker.Policies.IsTeamCaptain)` to the `TeamRole` update and destroy policy

## 4. Domain functions

- [x] 4.1 Add a `Groups` domain function to list all `GroupMembership` records for a group with their `User` loaded (e.g., `list_group_memberships_for_group/1`)
- [x] 4.2 Add a read action on `GroupMembership` for listing by group (e.g., `:for_group` with a `group_id` argument)
- [x] 4.3 Add an `update_role` action on `TeamRole` that accepts `[:role]` (if not already present), and define it in the `Tennis` domain (e.g., `update_team_role_role`)
- [x] 4.4 Add a `destroy_team_role` define in the `Tennis` domain
- [x] 4.5 Add a `:candidate_members_for_team` read action on `GroupMembership` that accepts `group_id` and `team_id` arguments and filters out users who already have a `:captain` TeamRole for that team using `filter(expr(...))` (DB-level, no Elixir filtering). Add a corresponding `Groups` domain function (e.g., `list_candidate_members_for_team!/2`).

## 5. Team edit LiveView — Captains section

- [x] 5.0 In `handle_params/3`, extend the access gate condition from `can_update_team or can_manage_slots` to `can_update_team or can_manage_slots or can_manage_captains` — team captains who cannot update team settings or manage lineup slots must still be allowed through to reach the Captains section. (Note: `can_manage_captains` must be computed before the gate check.)
- [x] 5.1 In `mount/3`, add `stream(:captains, [])`, `assign(:remove_pending_role, nil)`, and `assign(:candidate_user_id, nil)` to the socket
- [x] 5.2 In `handle_params/3`, load `TeamRole` records with `:captain` role for the team (using `list_team_roles_for_team!` with `load: [:user]`), stream them as `:captains`
- [x] 5.3 In `handle_params/3`, call `list_candidate_members_for_team!` (task 4.5) with the current `group_id` and `team_id` to fetch group members who are not already `:captain` for this team (filtered at the DB level), and assign the result as `:candidate_members`
- [x] 5.4 Compute and assign `can_manage_captains` by calling `Ash.can?({TennisTracker.Tennis.TeamRole, :create, %{team_id: team_id, group_id: group_id}}, current_user, domain: TennisTracker.Tennis, tenant: group_id)` — true for group owners and team captains, false otherwise
- [x] 5.5 Add a "Captains" section to the `render/1` template — list captains from `@streams.captains` showing `user.name || user.email` with a "Remove" button per row (only if `@can_manage_captains`)
- [x] 5.6 Add an empty state message when the captains stream is empty
- [x] 5.7 Add the inline add-captain control: a `<select>` of `@candidate_members` (display: `user.name || user.email`) bound to `@candidate_user_id`, and an "Add Captain" button (only if `@can_manage_captains`)
- [x] 5.8 Add the removal confirmation modal (rendered when `@remove_pending_role` is not nil) with three buttons: "Remove from team entirely", "Convert to Member", "Cancel"

## 6. Team edit LiveView — event handlers

- [x] 6.1 Handle `"select_captain_candidate"` event — update `@candidate_user_id` assign
- [x] 6.2 Handle `"add_captain"` event — if `@candidate_user_id` is nil, do nothing and return. Otherwise, look up if selected user has an existing TeamRole for this team; if `:member` update role to `:captain`, else create a new `:captain` TeamRole; refresh captains stream and candidate list. If the action fails (e.g. unique constraint conflict from a concurrent update), display the error message and prompt the user to refresh the page; do not crash or silently swallow the error.
- [x] 6.3 Handle `"remove_captain"` event (receives `team_role_id`) — load the TeamRole, assign to `@remove_pending_role`, render modal
- [x] 6.4 Handle `"confirm_remove_entirely"` event — destroy the TeamRole at `@remove_pending_role`, clear `@remove_pending_role`, refresh captains stream and candidate list
- [x] 6.5 Handle `"confirm_convert_to_member"` event — update the TeamRole role to `:member`, clear `@remove_pending_role`, refresh captains stream and candidate list
- [x] 6.6 Handle `"cancel_remove"` event — clear `@remove_pending_role`

## 7. Team show LiveView — Captains section

- [x] 7.1 In `mount/3` or `handle_params/3`, load `:captain` TeamRole records for the team (using `list_team_roles_for_team!` with `load: [:user]`) and stream them as `:captains`
- [x] 7.2 Add a read-only "Captains" section to the show template — list captains showing `user.name || user.email` per row, with no add/remove controls
- [x] 7.3 Add an empty state message when the captains stream is empty

## 8. Tests

- [x] 8.1 Test `IsTeamCaptainForTeamRoleCheck` — captain of team A can create, captain of team A cannot create for team B, non-captain cannot create
- [x] 8.2 Test `TeamRole` read policy — any group member can read, non-group-member cannot
- [x] 8.3 Test `TeamRole` update/destroy — captain of team A can modify, captain cannot modify team B's roles, member cannot modify
- [x] 8.4 Test `GroupMembership` read policy — member can read all group memberships, outsider cannot
- [x] 8.5 Test `User.name` attribute — can be nil, can be set, falls back to email in display context
- [x] 8.6 LiveView test (edit page) — group owner sees Captains section with controls
- [x] 8.7 LiveView test (edit page) — team captain sees Captains section with controls
- [x] 8.8 LiveView test (edit page) — regular group member navigating to the edit URL is redirected to the show page
- [x] 8.9 LiveView test (edit page) — adding a captain (no existing TeamRole) creates a new :captain TeamRole and refreshes the list
- [x] 8.10 LiveView test (edit page) — adding a captain who has a :member TeamRole updates the role to :captain
- [x] 8.10a LiveView test (edit page) — clicking "Add Captain" with no candidate selected is a no-op (no TeamRole created or updated, no crash)
- [x] 8.11 LiveView test (edit page) — removal modal "Remove from team entirely" destroys the TeamRole
- [x] 8.12 LiveView test (edit page) — removal modal "Convert to Member" updates the role to :member
- [x] 8.13 LiveView test (edit page) — removal modal "Cancel" makes no changes
- [x] 8.14 LiveView test (show page) — any group member sees the Captains section with captain names
- [x] 8.15 LiveView test (show page) — empty state shown when no captains assigned
