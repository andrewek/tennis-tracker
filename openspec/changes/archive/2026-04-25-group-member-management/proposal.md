## Why

Group owners have no way to add or remove users from their group through the application — membership changes require direct database access. This change gives group owners a self-serve UI to manage who belongs to their group.

## What Changes

- New settings page at `/g/:group_slug/settings/members` (owner-only)
- Group owners can add a user by email — if no account exists, one is created with a system-generated placeholder password displayed prominently on screen for the owner to share
- Group owners can change any member's role (`:owner` ↔ `:member`), except their own
- Group owners can remove any member from the group (destroys the `GroupMembership`, not the `User`), except themselves
- New `:invite` action on `User` resource to support owner-initiated account creation
- New `:add_member_by_email` domain function on `Groups` domain encapsulating find-or-create user + create membership logic
- New `:update_role` action on `GroupMembership` with policy blocking self-modification
- Existing `GroupMembership` destroy policy extended to block self-removal

## Capabilities

### New Capabilities

- `group-member-management`: UI and backend for group owners to add, change role of, and remove group members

### Modified Capabilities

- `group-model`: New `:update_role` action on `GroupMembership`; new policy constraints (no self role-change, no self-removal); new `add_member_by_email` domain function
- `user-auth`: New `User` `:invite` action (owner-initiated account creation with placeholder password)

## Impact

- `TennisTracker.Accounts.User` — new `:invite` action
- `TennisTracker.Groups.GroupMembership` — new `:update_role` action; destroy policy updated
- `TennisTracker.Groups` domain — new `add_member_by_email` domain function; new `define` entries; `list_group_memberships_for_group` consumed as-is (no changes)
- New LiveView: `TennisTrackerWeb.Live.Settings.Members.IndexLive`
- Router: new route `/g/:group_slug/settings/members`
- No database migrations required (no new fields or tables)
