## Context

The application is a single-tenant Phoenix/Ash app. All Tennis domain data (players, teams, locations, season rules, etc.) is globally visible — there is no isolation between different sets of users. Introducing a `Group` as the tenant boundary allows multiple independent organizations to coexist safely in the same database.

**Current state:**
- 9 Ash resources: User, Token, Player, Team, TeamType, TeamMembership, Match, Location, SeasonRules
- No `group_id` or tenant field anywhere
- Authorization: User.role (:admin | :member) only; no per-resource policies
- Routes: flat, e.g. `/teams`, `/players`, `/roster-planner`
- No production data — DB can be reset from scratch

**Constraints:**
- Users are cross-tenant (a User can belong to multiple Groups)
- No data shared between Groups except User accounts
- System admins must be able to see all Groups' data via Admin panel
- Setup is "concierge" — no self-serve tenant creation yet

## Goals / Non-Goals

**Goals:**
- Add `Group` as the root tenant entity with `GroupMembership` linking Users to Groups
- Add `TeamRole` linking Users to Teams with :captain/:member roles
- Apply AshMultitenancy attribute-based scoping to all Tennis domain resources
- Restructure all Tennis routes under `/g/:group_slug/`
- Add Ash authorization policies to all resources enforcing the three-axis permission model
- Update seeds to create a default Group and seed all data under it
- System admin bypass in Admin panel

**Non-Goals:**
- Self-serve group creation (concierge only for now)
- Player-User account linking (future work)
- TeamRole/TeamMembership merge (future work)
- Schema-based multitenancy
- Fine-grained per-team permissions beyond captain/member
- Player-facing access (future work)

## Decisions

### D1: Attribute-based multitenancy over schema-based

**Chosen:** Attribute-based (`multitenancy do strategy :attribute; attribute :group_id end` on each Tennis resource)

**Rationale:**
- Users are cross-tenant by design — they cannot live in a tenant schema, meaning schema-based requires a "public" schema split anyway
- Adding a new tenant requires only creating a Group record; schema-based requires creating a PG schema + running all migrations on it
- Scale (tens to low hundreds of tenants) does not warrant schema complexity
- Ash enforces tenant context at the query layer — calls without `tenant:` set fail loudly at the Ash level, not silently

**Alternative considered:** Schema-based multitenancy gives Postgres-level isolation. Rejected because User cross-tenancy and concierge setup simplicity outweigh the stronger isolation guarantee at this scale.

### D2: Group and GroupMembership live in a new Groups domain; TeamRole lives in the Tennis domain

**Chosen:** New `TennisTracker.Groups` domain for Group and GroupMembership; `TennisTracker.Tennis` for TeamRole.

**Rationale:**
- Group and GroupMembership are the intersection between Accounts (Users) and Tennis (data). They don't cleanly belong in either existing domain — they sit between them. A dedicated Groups domain makes this explicit and avoids bloating Accounts with Tennis-adjacent concepts.
- TeamRole is a Tennis-domain concern (it references Team, is tenant-scoped, and governs Tennis data access) — it belongs in Tennis.
- Group itself is NOT tenant-scoped (it IS the tenant). GroupMembership is also not tenant-scoped (it governs access to a tenant, not data within one).

**Alternative considered:** Group/GroupMembership in Accounts domain. Rejected because Group is not an auth/identity primitive — it's an organizational concept that happens to involve users.

### D3: URL structure `/g/:group_slug/...` for all Tennis routes; `/groups` for the group listing

**Chosen:** Slug-prefix scoping, e.g. `/g/:group_slug/teams`. Navigating to `/g/:group_slug/` shows that group's home page. `/groups` lists all groups the user belongs to. `/` redirects to `/groups`.

**Rationale:**
- Human-readable slugs make URLs meaningful: `/andrewek-tennis/teams` vs `/01J3K.../teams`
- Shareable, bookmarkable — group context survives reload/reconnect without session state
- Slug at root level (no `/groups/` prefix) keeps URLs short
- `/groups` as an explicit separate route avoids the ambiguity of a slug matching "groups"

**Router ordering note:** The `/groups` route MUST be defined before the `/g/:group_slug` dynamic segment in the Phoenix router, otherwise the literal string "groups" would be interpreted as a slug. All other fixed top-level paths (`/admin`, `/login`, `/sign-in`, etc.) must also precede `/g/:group_slug`.

**Alternative considered:** Session-stored `current_group_id` (simpler routing). Rejected because links shared between users would open in the wrong group context.

### D4: Three-axis permission model with OR logic

**Axes:**
1. `User.role == :admin` → system admin; bypasses all policies
2. `GroupMembership.role` → `:owner` (full group management) or `:member` (read + player edit)
3. `TeamRole.role` → `:captain` (edit own team) or `:member` (read-only team access)

**OR logic:** If ANY applicable role grants the action, it is permitted. A group owner who also captains teams gets both sets of permissions — whichever is broader applies.

**Implementation:** Ash `bypass` for system admins; separate `policy` blocks per role axis per resource.

### D5: Roster planner write access limited to group owners; members are read-only

**Rationale:** Drag-and-drop assignment is a consequential action affecting all teams in a planning context. Group owners coordinate across all teams; members should observe but not accidentally disrupt others' rosters. More granular permissions (e.g., per-team captain can edit their own team on the board) are future scope.

### D6: Seeds reset rather than backfill; two groups with realistic data

**Rationale:** No production data exists. Seeds are rewritten with two groups and realistic data volumes to exercise the permission model during development.

**Small group** (`smallgroup@example.com` as :owner and sole captain): ~20 players (5 at 3.0, 15 at 3.5); 1× 18+ 3.5 team, 1× 40+ 3.5 team; 8–12 matches each ranging from 2 weeks ago to 3 months out.

**Large group** (`admin@example.com` and `bigowner2@example.com` as :owner; `captain@example.com` as :member captain; `member@example.com` as :member non-captain): ~80 players (3.0–4.5); 7 teams (2× 18+ 3.5, 2× 40+ 3.5, 2× 18+ 4.0, 1× 18+ 4.5) each with 10+ eligible players from the roster; 8–12 matches per team.

All users share the same password. Locations reuse existing seeds. Seeds are idempotent.

### D7: UI hides unauthorized actions; unauthorized form access redirects

**Chosen:** If a user cannot perform an action, the button or link to trigger that action SHALL NOT be rendered. If a user navigates directly to an unauthorized form URL, they SHALL be redirected (not shown a blank or error page).

**Rationale:** "Grey out" and "show then reject" patterns create confusing UX. Hiding the control entirely is cleaner and reduces accidental attempts. The Ash policy still enforces at the data layer regardless — the UI convention is defense-in-depth plus UX clarity.

**Implementation:** Each LiveView or component checks the current user's roles before conditionally rendering action buttons. Unauthorized form LiveViews (e.g., team edit page for a non-captain) redirect in `mount/3` after the role check.

### D8: TeamRole unique constraint is `[:user_id, :team_id]` (not including group_id)

**Rationale:** A user can only have one role per team. Since teams already belong to one group, including `group_id` in the constraint would be redundant. The tenant attribute is still present for query scoping.


## Risks / Trade-offs

**[Risk] Forgetting `tenant:` on an Ash call** → Ash raises a runtime error (not a silent full-table scan) when multitenancy is configured and no tenant is set. The CLAUDE.md rule reinforces this. Still, every new domain function call needs review.
*Mitigation:* Integration tests assert that domain calls work correctly with a tenant; the pattern becomes habitual quickly.

**[Risk] System admin bypass in Admin panel exposes cross-tenant data** → If the bypass policy is configured incorrectly, a non-admin user could bypass tenant scoping.
*Mitigation:* Manual verification checklist after configuration: confirm each resource in admin shows all tenants' data for admins and correctly scopes for non-admins. Noted in CLAUDE.md.

**[Risk] AshAdmin and AshMultitenancy interaction** → AshAdmin may need explicit configuration to handle resources with multitenancy enabled. Each tenanted resource may require `tenant_field` or `bypass_tenant: true` configuration in its admin resource block.
*Mitigation:* Verify each resource in admin after configuration. Test with both system admin and non-admin accounts.

**[Risk] Unique constraint changes break existing queries** → Location's `[:name]` unique constraint becomes `[:group_id, :name]`. Any code asserting on Location uniqueness by name alone will need updating.
*Mitigation:* Covered by test updates; seeds reset clears old data.

**[Risk] URL restructuring breaks all existing LiveView routes** → Every route, link, and redirect in the app changes. Missing even one causes navigation errors.
*Mitigation:* Systematic router audit; test each LiveView mount path after restructuring.

## Migration Plan

1. Reset DB (`mix ecto.reset`) — no backfill needed, no production data
2. Create Group, GroupMembership, TeamRole resources + migrations
3. Add `group_id` to all Tennis resources + generate migrations
4. Enable `multitenancy` block on each Tennis resource
5. Add Ash authorization policies to all resources (system admin bypass first, then per-role)
6. Restructure router: add `/groups` listing route first; add `/g/:group_slug` scope for all Tennis routes; redirect `/` to `/groups`
7. Update all LiveViews: resolve group by slug in mount, verify membership, pass `tenant: group_id` to all Ash calls; redirect from unauthorized forms
8. Update AshAdmin: add bypass for system admins, verify each resource
9. Update seeds: create default Group → associate users → seed Tennis data under tenant
10. Run `mix precommit` and verify all tests pass

**Rollback:** Not applicable (no production deployment). Local dev reset via `mix ecto.reset`.

## Open Questions

- Does AshAdmin need `Ash.set_tenant(nil, ...)` explicitly, or does the bypass policy suffice? Needs verification during implementation.
- Should `/` redirect to `/groups`, or should `/groups` be the actual root route? (Current plan: redirect.)
