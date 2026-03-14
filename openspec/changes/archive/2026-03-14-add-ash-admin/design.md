## Context

The application currently has no user accounts — it is a single-tenant tool accessible to anyone who can reach the server. All Ash resources live under `TennisTracker.Tennis`. There is no auth pipeline in the router.

AshAuthentication is being installed separately via Igniter before this change begins. That install generates the `User` resource scaffold, token tables, LiveView auth flows, and router plugs. This change picks up from that baseline and adds the role attribute, admin panel, and resource configurations.

## Goals / Non-Goals

**Goals:**
- Provide a working admin panel at `/admin` for all environments
- Gate admin access on `user.role == :admin`
- Surface all 5 Tennis resources and the User resource in the panel
- Allow full CRUD on Player, Team, and User from the panel
- Allow read/create/update/destroy on TeamType and SeasonRules (adding missing actions)
- Restrict TeamMembership in admin to read + destroy only
- Seed two dev users: `admin@example.com` (`:admin`) and `user@example.com` (`:member`)

**Non-Goals:**
- Organization/group membership or group-scoped roles
- Foreign keys from Tennis resources to Accounts/User
- Any UI beyond the admin panel and home page link for user management
- Fine-grained per-resource authorization within the panel (all-or-nothing admin access for now)

## Decisions

### Accounts domain is separate from Tennis

`TennisTracker.Accounts` houses `User`. Tennis resources remain domain-isolated. This makes the future organizations/groups addition cleaner — group memberships can live in Accounts or a new domain without touching Tennis.

### Role as an enum attribute on User

A simple `:role` attribute with values `[:admin, :member]` on the `User` resource. Default is `:member`. This is the minimum needed to gate admin access. Future group-scoped roles will be a separate attribute on group membership records, not an extension of this enum.

AshAdmin authorization uses the `can_access?/2` callback on `AshAdmin.Domain` — the implementation checks `actor.role == :admin`.

### Admin mounted in all environments, not dev-only

Unlike LiveDashboard (which lives behind `dev_routes`), the admin panel is mounted unconditionally because it's needed in staging/production for data management. Auth gates access — no environment check needed.

### AshAuthentication Igniter install is a prerequisite

The Igniter-generated scaffold (User resource skeleton, token tables, router plugs, LiveView auth flows) is the baseline this change builds on. Attempting to do both in one step would create ordering conflicts. The user runs the Igniter install first, then this change adds the `role` attribute and admin configuration on top.

### TeamMembership exposes read + destroy only in admin

Creating or updating memberships through the admin panel requires manually entering denormalized `team_type_id` and `season_year` values consistent with the chosen team — a footgun. The admin use case is inspection and cleanup (deleting stale/broken records), not creation. Limiting to read + destroy prevents accidental data corruption.

### TeamType gets update + destroy actions

TeamType is seeded reference data with no edit UI. The admin panel is the appropriate management surface for correcting seed data errors. Adding `:update` and `:destroy` does not break existing callers — all current call sites use read or create only.

### SeasonRules gets a destroy action

SeasonRules has no UI and is managed via console/seeds. Being able to delete a misconfigured record from the admin panel is more ergonomic than dropping to `iex`. Adding `:destroy` does not break existing callers.

## Risks / Trade-offs

**PubSub broadcasts fire on Team and TeamMembership changes from admin**
→ This is actually correct behavior — if admin deletes a membership, the roster planner board should update. No mitigation needed; document it as expected.

**Admin panel is open until auth is configured**
→ After Igniter install but before the authenticated pipeline is wired, `/admin` will be accessible without login. Implementation order mitigates this: wire the auth pipeline before mounting admin.

**Igniter-generated User resource shape may vary**
→ The `role` attribute addition assumes a standard Igniter scaffold. If the scaffold deviates (e.g., different module name or attribute structure), minor adjustments may be needed. Low risk for a standard install.

**TeamType destroy in production could break seeded data**
→ Destroying a TeamType that has Teams referencing it will fail at the DB level (foreign key). This is the correct behavior. No mitigation needed beyond the constraint existing.

## Migration Plan

1. Run `mix igniter.install ash_authentication ash_authentication_phoenix` (user handles this)
2. Run `mix igniter.install ash_admin` (user handles this)
3. Add `role` attribute to `User`, generate and run migration
4. Add `AshAdmin.Domain` to `TennisTracker.Accounts` and `TennisTracker.Tennis`
5. Add `AshAdmin.Resource` configuration to all resources
6. Add `:update`/`:destroy` to `TeamType`; add `:destroy` to `SeasonRules`; generate and run migrations (no schema changes needed — actions only)
7. Wire authenticated pipeline in router; mount admin scope
8. Add admin link to home page
9. Update seeds with dev users
10. Update README

Rollback: remove admin scope from router, revert resource action additions, remove role migration.
