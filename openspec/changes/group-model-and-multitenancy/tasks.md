## 1. Groups Domain — Group and GroupMembership Resources

- [ ] 1.1 Create `lib/tennis_tracker/groups.ex` — new `TennisTracker.Groups` Ash domain with `extensions: [AshAdmin.Domain]` and `admin do show? true end`
- [ ] 1.2 Create `TennisTracker.Groups.Group` Ash resource with `id`, `name`, `slug` (unique, non-nullable); add to Groups domain
- [ ] 1.3 Create `TennisTracker.Groups.GroupMembership` Ash resource with `user_id`, `group_id`, `role` (`:owner | :member`); unique constraint `[:user_id, :group_id]`; add to Groups domain
- [ ] 1.4 Add `has_many :group_memberships` to Group; add `belongs_to :group` and `belongs_to :user` to GroupMembership
- [ ] 1.5 Generate and run migrations for Group and GroupMembership (`mix ash_postgres.generate_migrations --name add_groups_domain`)
- [ ] 1.6 Add domain functions: `create_group/1`, `list_groups/1`, `get_group_by_slug!/1`, `create_group_membership/1`, `list_group_memberships_for_user/1`, `list_groups_for_user/1`

## 2. TeamRole Resource

- [ ] 2.1 Create `TennisTracker.Tennis.TeamRole` Ash resource with `user_id`, `team_id`, `group_id` (tenant), `role` (`:captain | :member`); unique constraint `[:user_id, :team_id]`; add multitenancy block
- [ ] 2.2 Add `has_many :team_roles` to Team resource
- [ ] 2.3 Generate and run migrations for TeamRole (`mix ash_postgres.generate_migrations --name add_team_role`)
- [ ] 2.4 Add domain functions: `create_team_role/1`, `list_team_roles_for_team/1`, `list_team_roles_for_user/1`

## 3. Add group_id to Tennis Domain Resources

- [ ] 3.1 Add `group_id` attribute and `multitenancy` block to Player resource
- [ ] 3.2 Add `group_id` attribute and `multitenancy` block to Team resource
- [ ] 3.3 Add `group_id` attribute and `multitenancy` block to TeamType resource
- [ ] 3.4 Add `group_id` attribute and `multitenancy` block to TeamMembership resource
- [ ] 3.5 Add `group_id` attribute and `multitenancy` block to Match resource
- [ ] 3.6 Add `group_id` attribute and `multitenancy` block to Location resource; change unique constraint from `[:name]` to `[:group_id, :name]`
- [ ] 3.7 Add `group_id` attribute and `multitenancy` block to SeasonRules resource; change unique constraint from `[:team_type_id, :season_year]` to `[:group_id, :team_type_id, :season_year]`
- [ ] 3.8 Generate and run migrations for all group_id additions (`mix ash_postgres.generate_migrations --name add_group_id_to_tennis_resources`)

## 4. Authorization Policies

- [ ] 4.1 Add `authorizers: [Ash.Policy.Authorizer]` to every Ash resource across all three domains (Accounts, Groups, Tennis) — this is a prerequisite for any policy to take effect; add a test that an unauthenticated call to a tenanted resource (no `actor:`) is rejected to verify the authorizer is active
- [ ] 4.2 **Spike:** Verify that Ash policy expressions support two-level relationship traversal needed for "captain can edit their team's matches" — specifically `exists(team.team_roles, user_id == ^actor(:id) and role == :captain)` on the Match resource. If not natively supported, identify the workaround (manual policy module or calculation) before writing any captain-level policies
- [ ] 4.3 Add system admin `bypass` policy to all Ash resources (Accounts, Groups, and Tennis domains): `bypass actor_attribute_equals(:role, :admin) do authorize_if always() end`
- [ ] 4.4 Add group owner read/write policies to Player, Team, TeamType, TeamMembership, Location, SeasonRules (check GroupMembership relationship: `relates_to_actor_via([:group_memberships])` with role filter)
- [ ] 4.5 Add group member read policies to Team, Player, Match, Location, SeasonRules; add group member write policy for Player create/update
- [ ] 4.6 Add team captain write policies to Match (create/update/destroy for their teams only, using traversal pattern confirmed in 4.2)
- [ ] 4.7 Add team captain/member read policies to Match for their teams
- [ ] 4.8 Add policies to GroupMembership and Group resources (system admin bypass; users can read their own memberships)
- [ ] 4.9 Add policies to TeamRole resource (system admin bypass; group owner can manage; user can read their own)

## 5. Route Restructuring

- [ ] 5.1 Add `/groups` route to router (BEFORE `/g/:group_slug` scope) for the groups listing LiveView
- [ ] 5.2 Add smart redirect from `/`: load user's groups; if exactly one → redirect to `/g/:group_slug/`; otherwise → redirect to `/groups`
- [ ] 5.3 Add `/g/:group_slug` scope to router; move all Tennis LiveView routes under it: teams, players (index, new, show, edit, import), roster-planner, matches (show, edit)
- [ ] 5.4 Move `GET /players/export.csv` controller route to `/g/:group_slug/players/export.csv`; add group membership verification in `PlayerCSVController` using the slug param (this is a controller, not LiveView — membership check goes in the controller action, not a mount hook)
- [ ] 5.5 Remove old flat routes (`/teams`, `/players`, `/players/export.csv`, `/players/import`, `/matches/:id`, `/roster-planner`)
- [ ] 5.6 Update all `<.link navigate={}>` and `push_navigate` calls in LiveViews and templates to use `/g/:group_slug/...` paths
- [ ] 5.7 Audit all hardcoded paths in templates and helpers; replace with slug-scoped equivalents

## 6. /groups Page

- [ ] 6.1 Create `TennisTrackerWeb.GroupsLive.Index` LiveView at `/groups`; load groups for current user via `Groups.list_groups_for_user/1`; system admin uses `Groups.list_groups/1` to see all groups
- [ ] 6.2 Render groups as a card layout sorted alphabetically; each card links to `/g/:group_slug/`
- [ ] 6.3 Add empty state for users with no group memberships: explain they are not yet a member of any group and that a system administrator can add them
- [ ] 6.4 Update post-login redirect in `AuthController` (or AshAuthentication overrides): after successful sign-in, load the user's groups and redirect to `/g/:group_slug/` if exactly one group, otherwise to `/groups`

## 7. LiveView Mount Updates

- [ ] 7.1 Create a shared `on_mount` hook that: resolves Group by slug via `Groups.get_group_by_slug!/1`, verifies the current user has a GroupMembership (or is system admin), assigns `current_group` and `current_group_id` to socket, redirects on failure
- [ ] 7.2 Apply the group mount hook to all group-scoped LiveViews (Teams index/show/edit, Players index/show/edit/new/import, Roster Planner, Matches show/edit)
- [ ] 7.3 Update all Tennis domain Ash calls in LiveViews to pass BOTH `tenant: socket.assigns.current_group_id` AND `actor: socket.assigns.current_user`
- [ ] 7.4 Update all AshPhoenix.Form calls in LiveViews to pass both tenant and actor context
- [ ] 7.5 In each form LiveView (team edit, match edit, etc.), add a role check in `mount/3` and redirect unauthorized users before rendering
- [ ] 7.6 Update PubSub topic strings in roster planner (and any other subscriber) from `"roster:#{team_type_id}:#{season_year}"` to `"roster:#{group_id}:#{team_type_id}:#{season_year}"` to prevent cross-tenant broadcast leakage

## 8. UI Authorization Conventions

- [ ] 8.1 Audit all action buttons and links across templates; conditionally render based on current user's role (group owner, captain, member)
- [ ] 8.2 Teams index: show "New Team" button only to group owners and system admins
- [ ] 8.3 Team show/edit: show edit/delete controls only to group owners and captains of that team
- [ ] 8.4 Match controls: show create/edit/delete only to team captains for their team and group owners
- [ ] 8.5 Roster planner: disable drag-and-drop and hide team create/delete controls for non-owners
- [ ] 8.6 Player list: show "Add Player" to all group members; hide team roster assignment controls from non-owners/non-captains

## 9. Admin Panel Updates

- [ ] 9.1 Configure `TennisTracker.Groups` domain for AshAdmin: add `extensions: [AshAdmin.Domain]` and `admin do show? true end` to the domain (done in 1.1); add per-resource AshAdmin configs for Group (full CRUD) and GroupMembership (full CRUD)
- [ ] 9.2 Add AshAdmin resource configuration for TeamRole (read + destroy for system admin)
- [ ] 9.3 Configure AshAdmin to bypass tenant scoping for all tenanted Tennis resources (system admin sees all groups' data)
- [ ] 9.4 Manually verify: log in as `admin@example.com`; confirm each tenanted resource in admin shows data from both groups
- [ ] 9.5 Manually verify: log in as `member@example.com`; confirm `/admin` is inaccessible

## 10. Seeds Rewrite

- [ ] 10.1 Create all user accounts with shared password `Password1!`:
  - `admin@example.com` — User.role :admin (also a large group owner)
  - `smallgroup@example.com` — User.role :member (small group owner and sole captain)
  - `bigowner1@example.com` — User.role :member (large group owner)
  - `captain@example.com` — User.role :member (large group member and team captain)
  - `member@example.com` — User.role :member (large group member, no captaincy)
- [ ] 10.2 Create Small Group (slug: `small-group`); create GroupMembership for `smallgroup@example.com` as :owner
- [ ] 10.3 Seed Small Group TeamTypes: 18+ 3.5, 40+ 3.5; seed SeasonRules for current year under Small Group tenant
- [ ] 10.4 Seed ~20 Small Group players (tenant: small-group): 5 at NTRP 3.0 (eligible 18+ and/or 40+), 15 at NTRP 3.5; use realistic names
- [ ] 10.5 Create Small Group teams for current season: one 18+ 3.5 team, one 40+ 3.5 team; assign TeamRole :captain to `smallgroup@example.com` for both
- [ ] 10.6 Assign 10+ eligible players from the small group roster to each team via TeamMembership
- [ ] 10.7 Create 8–12 matches per small group team using seeded locations; distribute from 2 weeks ago to 3 months out, max one per week
- [ ] 10.8 Create Large Group (slug: `large-group`); create GroupMemberships: `admin@example.com` :owner, `bigowner1@example.com` :owner, `captain@example.com` :member, `member@example.com` :member
- [ ] 10.9 Seed Large Group TeamTypes: 18+ 3.5, 40+ 3.5, 18+ 4.0, 18+ 4.5; seed SeasonRules for current year under Large Group tenant
- [ ] 10.10 Seed ~80 Large Group players (tenant: large-group) across NTRP 3.0–4.5 with appropriate age eligibility; use realistic names
- [ ] 10.11 Create Large Group teams for current season: 2× 18+ 3.5, 2× 40+ 3.5, 2× 18+ 4.0, 1× 18+ 4.5; assign TeamRole :captain to `bigowner1@example.com` and `captain@example.com` for at least one team each
- [ ] 10.12 Assign 10+ eligible players from the large group roster to each team via TeamMembership
- [ ] 10.13 Create 8–12 matches per large group team using seeded locations; distribute from 2 weeks ago to 3 months out, max one per week
- [ ] 10.14 Run `mix ecto.reset` and verify seed data is correct; confirm seeds are idempotent (run twice, no duplicates); all Ash calls in seeds use `authorize?: false`

## 11. Test Factory Updates

- [ ] 11.1 Add `group/1` factory function in `TennisTracker.Factory` (or a Groups-specific factory module): creates a Group via `Groups.create_group!/1` with a unique name and derived slug; returns the group record
- [ ] 11.2 Add `group_membership/1` factory function: accepts `group:` and `user:` keyword args; creates a GroupMembership with default role `:member`; supports `:owner` trait
- [ ] 11.3 Add `team_role/1` factory function: accepts `user:`, `team:`, `group:` keyword args; creates a TeamRole with default role `:member`; supports `:captain` trait
- [ ] 11.4 Update all existing factory functions (`player/1`, `team/1`, `team_type/1`, `team_membership/1`, `season_rules/1`, `location/1`, `match/1`) to accept a `group:` keyword argument and pass `tenant: group.id` to the underlying Ash call; raise a clear error if `group:` is not provided for tenant-scoped resources
- [ ] 11.5 Add a shared `setup_group/1` helper (or ExUnit tag) to `test/support/` that creates a test group, a test user, and a GroupMembership; usable as `setup :setup_group` in test modules; returns `%{group: group, user: user}`
- [ ] 11.6 Update all existing test files to use the new factory signatures (pass `group:` to every factory call that creates a Tennis domain record)

## 12. Test Updates

- [ ] 12.1 Add unit tests for Group resource: create succeeds, slug uniqueness enforced, name required
- [ ] 12.2 Add unit tests for GroupMembership: create succeeds, duplicate rejected, invalid role rejected
- [ ] 12.3 Add unit tests for TeamRole: create succeeds, duplicate rejected, invalid role rejected
- [ ] 12.4 Add policy enforcement tests (using `actor:` on Ash calls); each test confirms the policy is actually active (not just silently passing):
  - Group member cannot create a team (Ash call raises/returns error)
  - Group member cannot delete a team
  - Team captain can edit their own team's matches
  - Team captain cannot edit another team's matches
  - Group member can create/update a Player
  - Group member cannot create a TeamMembership
  - System admin can perform any action
  - Unauthenticated call (no actor) to a tenanted resource is rejected
- [ ] 12.5 Add LiveView mount tests: accessing a `/g/:group_slug/` route with valid membership renders the page; without membership redirects; with invalid slug redirects
- [ ] 12.6 Add LiveView page visibility tests: group member does not see "New Team" button; captain sees edit controls only for their team; group owner sees all controls
- [ ] 12.7 Add LiveView redirect tests: non-captain navigating directly to team edit URL is redirected; non-owner navigating to match create URL is redirected
- [ ] 12.8 Add /groups page tests: user sees their own groups sorted alphabetically; system admin sees all groups; user with no groups sees empty state
- [ ] 12.9 Add post-login redirect tests: single-group user lands on `/g/:group_slug/`; multi-group user lands on `/groups`
- [ ] 12.10 Run `mix precommit` and ensure all tests pass
