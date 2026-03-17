## Why

The system currently has no notion of tenancy — all data is globally visible, making it impossible to open the application to other team captains without exposing everyone's data to everyone else. Introducing a `Group` model creates independent namespaces so multiple captains and their organizations can use the system safely and independently.

## What Changes

- **New `Group` resource**: The root tenant entity. A group is an independent namespace encapsulating teams, players, locations, season rules, and team types for a cluster of related teams.
- **New `GroupMembership` resource**: Links users to groups with a role (`:owner` or `:member`). Owners have full management access; members have read access and can add/edit players.
- **New `TennisTracker.Groups` domain**: Group and GroupMembership live in a dedicated Groups domain — the intersection between Accounts and Tennis — rather than in either existing domain.
- **New `TeamRole` resource**: Links users to specific teams with a role (`:captain` or `:member`). Captains can edit their teams' matches and rosters; members get read-only access to that team's lineup and schedule.
- **`group_id` added to all Tennis domain resources**: Player, Team, TeamType, TeamMembership, Match, Location, SeasonRules all become tenant-scoped via attribute-based AshMultitenancy.
- **BREAKING: All Tennis routes become group-scoped via slug**: URLs change from `/teams` to `/g/:group_slug/teams`, etc. The group slug is human-readable (e.g., `/g/my-tennis-group/teams`). Navigating to `/g/:group_slug/` shows that group's home page.
- **New `/groups` page**: Lists all groups the current user belongs to as a card layout, sorted alphabetically. This replaces the previous home page and serves as the entry point after login.
- **BREAKING: All Tennis domain Ash calls require `tenant: group_id`**: Calls without a tenant fail at the Ash layer.
- **Authorization policies added to all resources**: Three-axis permission model (system admin → group role → team role). System admins bypass all policies via Ash `bypass`.
- **Player CSV export and import routes group-scoped**: `GET /players/export.csv` becomes `/g/:group_slug/players/export.csv`; `Players.ImportLive` moves to `/g/:group_slug/players/import`; both include group membership verification.
- **UI convention: hide unauthorized actions**: Buttons and links for actions the current user cannot perform SHALL NOT be rendered. Navigating directly to an unauthorized form SHALL redirect rather than render.
- **Seeds updated**: DB reset from scratch; seeds create two groups with realistic player/team/match data and multiple user accounts with distinct roles across both groups.

## Capabilities

### New Capabilities

- `group-model`: The Group resource and GroupMembership resource in a new Groups domain; group creation, user association, role management (owner/member)
- `group-multitenancy`: Attribute-based tenant scoping on all Tennis domain resources via AshMultitenancy; all Ash calls require explicit tenant; system admin bypass
- `team-role`: TeamRole resource linking users to teams with captain/member roles; team-level access control
- `group-scoped-routing`: Slug-based URL structure (`/g/:group_slug/...`); LiveView mount verification that current user belongs to the group; `/groups` listing page

### Modified Capabilities

- `user-auth`: Authorization policies added to all resources; system admin bypass behavior; the current `:admin`/`:member` User role values are unchanged but now interact with group and team-level roles
- `team-management`: All team CRUD operations now require group context; team creation/edit/delete restricted to group owners and team captains respectively
- `roster-planner`: Write access restricted to group owners; group members are read-only
- `matches`: Match creation and editing restricted to team captains for their own teams
- `locations`: Location records are now group-scoped; unique constraint changes from `[:name]` to `[:group_id, :name]`
- `season-rules`: SeasonRules records are now group-scoped
- `player-list-view`: Player records are now group-scoped; group members can add/edit players; roster assignment (TeamMembership) remains owner/captain territory
- `admin-panel`: System admins bypass tenant scoping; each resource view must be verified to show cross-tenant data for admins without leaking to non-admins

## Impact

- **Database**: Migration adds `group_id` to 7 Tennis domain tables; new `groups`, `group_memberships`, and `team_roles` tables; unique constraint changes on `locations`; DB reset required (no production data to migrate)
- **New domain**: `TennisTracker.Groups` added alongside `Accounts` and `Tennis`
- **Router**: All Tennis LiveView routes restructured under `/g/:group_slug/` scope; `/groups` added as the groups listing page; `/` smart-redirects based on group count
- **LiveViews**: Every LiveView mount gains group membership verification (by slug) + tenant and actor assignment to socket assigns
- **Ash domain functions**: All Tennis domain function calls gain `tenant: group_id` argument
- **AshAdmin**: Admin resource configurations need bypass policies for system admins
- **Seeds**: `priv/repo/seeds.exs` rewritten with two groups, multiple user accounts with distinct roles, realistic player populations, teams, and match schedules
