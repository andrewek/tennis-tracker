## Context

`GroupMembership` records link `User` to `Group` with a `role` (`:owner` | `:member`). Authorization policies on `GroupMembership` already gate creates and updates to group owners, but there is no application UI for managing membership — changes require direct DB access. The `User` resource has no `create` action; users are created only through AshAuthentication's registration flow.

## Goals / Non-Goals

**Goals:**
- Group owners can add, change role of, and remove members via `/g/:group_slug/settings/members`
- Adding by email handles both existing accounts and new-account creation in one flow
- Policy enforcement prevents owners from modifying or removing their own membership

**Non-Goals:**
- Email-based invitation flow (deferred — out of scope for this change)
- Soft delete / membership history
- "Last owner" guard (handled by admin conversation, not enforced programmatically)
- Self-service group leaving for regular members

## Decisions

### 1. `add_by_email` as a domain function, not an Ash action

Adding a member by email crosses two domains: it may create a `User` (Accounts) before creating a `GroupMembership` (Groups). Ash actions are scoped to a single resource. A plain Elixir function in `TennisTracker.Groups` owns the orchestration:

```
Groups.add_member_by_email(email, role, actor: owner, tenant: group_id)
  → Accounts: find User by email
  → if nil: Accounts.User :invite → new user + plaintext temp password
  → Groups: create GroupMembership
  → return {:ok, %{membership: m, new_user?: bool, temp_password: string | nil}}
```

Alternative considered: a custom Ash generic action. Rejected — generic actions don't have clean multi-domain orchestration and complicate error handling.

### 2. Placeholder password: generated in domain function, returned once, never stored as plaintext

`add_member_by_email` generates a random password (`Base.encode64(:crypto.strong_rand_bytes(16))`), passes it to `User :invite` (which hashes it), and returns the plaintext to the caller. The LiveView holds it in assigns until the owner explicitly dismisses it, displaying it in a dismissible card. It is never written to the DB as plaintext.

Alternative considered: "forgot password" email flow. Rejected — depends on email deliverability, which is deferred.

### 3. `User :invite` action called internally with `authorize?: false`

The `:invite` action should not be callable by arbitrary actors. Authorization is enforced one layer up — only the `add_member_by_email` domain function (which requires a group owner actor) calls it. The action itself is called with `authorize?: false` to keep policies simple and avoid a cross-domain policy check.

Alternative considered: policy on `:invite` allowing any group owner. Rejected — Accounts domain should not know about Groups domain policy structure.

### 4. Self-modification blocked via inline `expr` policies on GroupMembership

Rather than new policy check modules, the `:update_role` and `:destroy` actions use inline `forbid_if(expr(user_id == ^actor(:id)))`. This is concise and co-located with the actions they protect.

`GroupMembership` has an existing `:update` action used for other purposes (e.g., admin and profile-level updates). The new `:update_role` action is a separate, focused action for the member management UI. Authorization rules on each action are intentionally independent — the new `policy action(:update_role)` block governs `:update_role`, and a new `policy action(:destroy)` block governs destroy self-removal. Both are more specific than the existing `policy action_type([:update, :destroy])` block, so they take precedence. The shared `action_type` block is left untouched and continues to govern the existing `:update` action. This separation is accepted: keeping update actions small and focused makes permission evolution easier as requirements grow.

### 5. LiveView access guard via `current_group_role`

In `mount/3`, check `socket.assigns.current_group_role in [:owner, :admin]` to gate access and redirect non-owners to the group home page. This is consistent with how existing settings pages (e.g., `TagsLive`) gate access and avoids an unnecessary `Ash.can?` call when the role is already resolved by the group mount hook. The navigation link in `layouts.ex` uses the same `@current_group_role in [:owner, :admin]` condition, so no additional assign is needed.

### 6. Role change UI: per-row select element, not a separate form page

Each member row shows a `<select>` for role. `phx-change` fires `handle_event("change_role", ...)` which calls the `update_role` action inline. No separate page or modal needed. The actor's own row shows a static role badge with no select.

### 7. Remove: confirmation modal before destroy

Clicking "Remove" opens an inline confirmation (assigns a `@confirming_removal_id`). Confirming fires `handle_event("confirm_remove", ...)`. The actor's own row has no remove button.

## Risks / Trade-offs

- **Plaintext password in LiveView assigns** → Mitigation: assign is cleared on dismiss (`handle_event("dismiss_new_user_card", ...)`). Password is never logged or written to DB.
- **User :invite is callable with authorize?: false** → Mitigation: the only call site is `add_member_by_email`, which enforces group owner actor before calling. Keep the `:invite` action documented as internal-only.
- **Cross-domain read in domain function** → `Accounts` is read without tenant (User is not tenant-scoped). This is consistent with how the rest of the app reads User records.
- **Email uniqueness mismatch** → If an invite is in flight and a user self-registers with the same email between lookup and create, the create will fail on the unique identity. The domain function should handle `{:error, %Ash.Error.Invalid{}}` and retry the lookup path.

## Open Questions

- None — all decisions settled in exploration.
