## Context

The app already has a `TeamRole` resource that links `User` accounts to `Team` records with a `:captain` or `:member` role. Policies currently only allow group owners to manage these records. There is no UI for it — only the admin panel.

`User` records have no display name — only `email`. The `GroupMembership` resource links Users to Groups but its read policy currently only allows group owners or the user themselves, so members cannot see other members.

## Goals / Non-Goals

**Goals:**
- Group admins and team captains can assign/unassign team captains from the team edit page
- All group members can see who the captain is (read access)
- Inline add UX for small groups; remove confirmation modal with three options
- `User` gets an optional `name` field for display

**Non-Goals:**
- Inviting users not yet in the system (out of scope)
- `:member` TeamRole permissions downstream of this change (deferred — "Convert to Member" is implemented as a remove option, but the `:member` role has no effect on lineup access, match management, or any other UI; those behaviors are out of scope)
- Enforcing a minimum captain count (zero captains is acceptable)

## Decisions

### 1. Extend GroupMembership reads to all group members

To populate the captain picker, the LiveView needs to read all `GroupMembership` records for the group and load their associated `User`. Currently only group owners or the user themselves can read GroupMembership records.

**Decision**: Extend `GroupMembership` read policy to allow any group member (via `IsGroupMember` FilterCheck).

**Alternative considered**: Query `User` directly filtered by existence of a GroupMembership. Rejected — `User` read policies are very restrictive (only system admin bypass) and would require a larger policy change.

### 2. Two new policy checks for TeamRole create

For update/destroy on `TeamRole`, the existing `IsTeamCaptain` FilterCheck already works — it queries for a TeamRole where `team_id == parent(team_id) and user_id == actor.id and role == :captain`, which correctly checks if the actor is a captain of the same team as the record being modified.

For create, a new `IsTeamCaptainForTeamRoleCheck` SimpleCheck is needed. It reads `team_id` and `group_id` off the changeset and does a direct TeamRole lookup to verify the actor is a captain of that team.

**Alternative considered**: A single combined policy file. Rejected — the codebase separates FilterCheck and SimpleCheck into distinct modules (see `IsTeamCaptainForLineupAssignment` vs `IsTeamCaptainForLineupAssignmentCheck`).

### 3. Add/update logic for captain picker (Option A)

When "Add" is clicked in the picker, the LiveView checks if the selected user already has a TeamRole for this team:
- If yes (role `:member`) → call `update` action, set `role: :captain`
- If no → call `create` action with `role: :captain`

This is transparent to the admin. The unique constraint `[:user_id, :team_id]` is the guard — create would fail on a duplicate anyway.

### 4. Remove modal in LiveView (not a separate component)

The confirmation modal state is tracked in the LiveView assigns (`remove_pending_role`). When "Remove" is clicked, the TeamRole struct is stored in assigns and the modal renders inline. Three events handle the three modal options.

**Alternative considered**: A separate LiveComponent for the modal. Rejected — the group is small (7–8 users), the state is simple, and inline LiveView events are easier to follow.

### 5. Migration for User.name

A new optional `:name` field is added to the `users` table via `mix ash_postgres.generate_migrations`. No backfill needed (nullable). Display everywhere uses `user.name || user.email`.

## Risks / Trade-offs

- **GroupMembership read expansion** → Group members can now enumerate all other members in their group. This is intentional and low-risk for a private group app, but worth noting as a scope expansion.
- **Captain modifying own record** → A captain can technically update or destroy their own TeamRole, removing themselves. This is acceptable — zero captains is fine and the group admin can re-add them.
- **Captain picker loads all group members** → For large groups this could be a long list, but the target is 7–8 members. Revisit with search/autocomplete if groups grow.

## Migration Plan

1. Add `:name` attribute to `User`, generate and run migration
2. Extend `GroupMembership` read policy
3. Add new `IsTeamCaptainForTeamRoleCheck` policy module
4. Update `TeamRole` policies (read, create, update/destroy)
5. Add domain functions for listing group members and updating TeamRole role
6. Update `EditLive` — load captain data, add Captains section, wire events
