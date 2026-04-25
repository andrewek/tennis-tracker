## 1. User :invite action

- [x] 1.1 Add `:invite` action to `TennisTracker.Accounts.User` accepting `email` and `password` (plaintext argument), using `HashPasswordChange` to hash, defaulting role to `:member`; declare no `authorize_if` policy on this action (inaccessibility to arbitrary actors is enforced by the absence of a passing policy; authorization is enforced at the `add_member_by_email` call site)
- [x] 1.2 Write tests for `:invite`: creates user with hashed password, fails on duplicate email, sets role to `:member`

## 2. GroupMembership policy and action updates

- [x] 2.1 Add `:update_role` action to `GroupMembership` accepting `:role`, with policy: `forbid_if expr(user_id == ^actor(:id))` first, then `authorize_if IsGroupOwner`
- [x] 2.2 Add a new `policy action(:destroy)` block (more specific than the existing `action_type` block, so it takes precedence) containing `forbid_if expr(user_id == ^actor(:id))` first, then `authorize_if IsGroupOwner`; leave the shared `action_type` block untouched
- [x] 2.3 Add `define(:update_group_membership_role, action: :update_role)` to the `Groups` domain
- [x] 2.4 Write tests for `:update_role`: owner can change other's role, owner denied on own, non-owner denied
- [x] 2.5 Write tests for updated destroy policy: owner can remove other, owner denied on self

## 3. add_member_by_email domain function

- [x] 3.1 Implement `TennisTracker.Groups.add_member_by_email/3` — accepts `email`, `role`, and `opts` (actor:, tenant:); looks up User by email; if not found calls `User :invite` with `authorize?: false` and a generated password; creates GroupMembership; returns `{:ok, %{membership: m, new_user?: bool, temp_password: string | nil}}` or `{:error, reason}`
- [x] 3.2 Handle the race-condition case: if User create fails on unique identity, retry the lookup path and treat as existing-user case
- [x] 3.3 Write tests for `add_member_by_email`: existing user added, new user created with temp password, already-member returns error, race condition (user created between lookup and invite) falls through to the existing-user path and succeeds

## 4. LiveView: group member management page

- [x] 4.1 Create `TennisTrackerWeb.Live.Settings.Members.IndexLive` — mount loads members via `Groups.list_group_memberships_for_group/2` (already exists; `:for_group` action preloads `:user`, so `user.name` and `user.email` are available on each membership), streams results; redirects non-owners in `mount/3` using `socket.assigns.current_group_role in [:owner, :admin]` (consistent with existing settings pages)
- [x] 4.2 Add route `live "/g/:group_slug/settings/members", Settings.Members.IndexLive, :index` in the group-scoped `ash_authentication_live_session` block
- [x] 4.3 Implement the add-member form: `to_form/2`-driven form with email input and role select; `handle_event("add_member", ...)` calls `add_member_by_email`; on success streams new membership and resets the form; on new-user also assigns `@new_user_password`; on error surfaces the error inline on the form (not as a flash) — use `AshPhoenix.Form.add_error/3` or an equivalent form-level error assign rendered near the email field
- [x] 4.4 Implement the prominent new-user password card: shown when `@new_user_password` is not nil; includes the password in a styled block; "Dismiss" button triggers `handle_event("dismiss_new_user_card", ...)` which clears the assign
- [x] 4.5 Implement per-row role change: each non-self row has a role `<select>` with `phx-change="change_role"`; `handle_event("change_role", %{"membership_id" => id, "role" => role}, socket)` calls `update_group_membership_role`; updates stream on success
- [x] 4.6 Implement per-row remove with confirmation: each non-self row has a "Remove" button; clicking assigns `@confirming_removal_id`; confirmation prompt appears inline; confirming fires `handle_event("confirm_remove", ...)` which destroys the membership and removes from stream; cancelling clears `@confirming_removal_id`
- [x] 4.7 Ensure actor's own row renders a static role badge and no role-change or remove controls

## 5. Navigation

- [x] 5.1 Add a "Members" link to the group settings dropdown in `layouts.ex` (alongside the existing Locations, Tags, and Season Rules links) — gated by the same `@current_group_role in [:owner, :admin]` condition already used there; no new assign required

## 6. Tests

- [x] 6.1 Write LiveView tests for the members page: owner can access, non-owner is redirected
- [x] 6.1a Write LiveView test asserting the Members link in the group settings nav is visible for owners and absent for non-owners
- [x] 6.2 Write LiveView tests for add-member form: existing user added, new user created with password card shown, duplicate member shows error
- [x] 6.3 Write LiveView tests for role change: success case, self-change is not rendered
- [x] 6.4 Write LiveView tests for remove: confirmation flow, cancel, successful removal, own row has no remove button
