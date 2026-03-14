## 1. Prerequisites (user handles these before implementation begins)

- [x] 1.1 Run `mix igniter.install ash_authentication ash_authentication_phoenix` and commit the generated scaffold
- [x] 1.2 Run `mix igniter.install ash_admin` and commit the generated scaffold
- [x] 1.3 Verify the app still compiles and tests pass after both installs (`mix precommit`)

## 2. Add role attribute to User

- [x] 2.1 Add a `role` attribute to the generated `TennisTracker.Accounts.User` resource: type `:atom`, `constraints: [one_of: [:admin, :member]]`, `default: :member`, `allow_nil?: false`, `public?: true`
- [x] 2.2 Run `mix ash_postgres.generate_migrations --name add_role_to_users` and inspect the generated migration
- [x] 2.3 Run `mix ecto.migrate`

## 3. Add missing actions to Tennis resources

- [x] 3.1 Add `:update` action to `TennisTracker.Tennis.TeamType` accepting `[:name, :age_group, :ntrp_level, :allowed_ntrp_levels]`
- [x] 3.2 Add `:destroy` action to `TennisTracker.Tennis.TeamType`
- [x] 3.3 Add `:destroy` action to `TennisTracker.Tennis.SeasonRules`
- [x] 3.4 Run `mix ash_postgres.generate_migrations --name add_team_type_and_season_rules_actions` — verify no schema changes are generated (actions only, no migration needed); if no-op migration is generated, delete it

## 4. Configure AshAdmin on domains

- [x] 4.1 Add `AshAdmin.Domain` extension to `TennisTracker.Accounts` domain; add `admin do ... end` block with `show?: true` and a `can_access?/2` callback that checks `actor.role == :admin`
- [x] 4.2 Add `AshAdmin.Domain` extension to `TennisTracker.Tennis` domain; add `admin do ... end` block with `show?: true` and the same `can_access?/2` check

## 5. Configure AshAdmin on resources

- [x] 5.1 Add `AshAdmin.Resource` extension to `TennisTracker.Accounts.User`; configure admin block to show all public attributes and expose all CRUD actions
- [x] 5.2 Add `AshAdmin.Resource` extension to `TennisTracker.Tennis.Player`; configure admin block to expose all actions
- [x] 5.3 Add `AshAdmin.Resource` extension to `TennisTracker.Tennis.TeamType`; configure admin block to expose read, create, update, and destroy actions
- [x] 5.4 Add `AshAdmin.Resource` extension to `TennisTracker.Tennis.Team`; configure admin block to expose all actions
- [x] 5.5 Add `AshAdmin.Resource` extension to `TennisTracker.Tennis.SeasonRules`; configure admin block to expose read, create, update, and destroy actions
- [x] 5.6 Add `AshAdmin.Resource` extension to `TennisTracker.Tennis.TeamMembership`; configure admin block to expose read and destroy actions only (no create, no update)

## 6. Wire up the router

- [x] 6.1 Add (or verify Igniter already added) an `:authenticated` pipeline in the router that runs the AshAuthentication session plug
- [x] 6.2 Add an `/admin` scope that pipes through `[:browser, :authenticated]` and mounts `ash_admin "/"`
- [x] 6.3 Verify unauthenticated access to `/admin` redirects to the login page (manual check or test)

## 7. Update seeds

- [x] 7.1 Add `alias TennisTracker.Accounts` at the top of `priv/repo/seeds.exs`
- [x] 7.2 Seed `admin@example.com` with role `:admin` — use `upsert` or existence check to keep seeds idempotent
- [x] 7.3 Seed `user@example.com` with role `:member` — same idempotency pattern
- [x] 7.4 Run `mix ecto.reset` and verify seeds complete without errors

## 8. Authenticate all routes and add logout to nav

- [x] 8.1 Add a `current_user` attr to `Layouts.app` in `lib/tennis_tracker_web/components/layouts.ex` and add a logout link (DELETE to the sign-out route) in the nav bar, rendered only when `@current_user` is not nil
- [x] 8.2 Move all LiveView routes (`/players/*`, `/roster-planner/*`) inside the `ash_authentication_live_session :authenticated_routes` block and add `on_mount: [{TennisTrackerWeb.LiveUserAuth, :live_user_required}]` to the session options
- [x] 8.3 Protect the `PageController` home route: add an `ensure_authenticated` plug (or equivalent) so unauthenticated `GET /` redirects to `/sign-in`; update all LiveView `<Layouts.app>` calls to pass `current_user={@current_user}`

## 9. Add admin link to home page

- [x] 9.1 Add an "Admin" card to the grid in `lib/tennis_tracker_web/controllers/page_html/home.html.heex` linking to `/admin`, following the existing card pattern (icon, label, subtitle)

## 10. Update documentation

- [x] 10.1 Add a section to `README.md` documenting the admin panel: URL (`/admin`), access requirement (`:admin` role), and how to promote a user via IEx or the DB

## 11. Verify and clean up

- [x] 11.1 Log in as `admin@example.com` and verify the admin panel loads at `/admin` with all 6 resources visible
- [x] 11.2 Log in as `user@example.com` and verify access to `/admin` is denied
- [x] 11.3 Verify TeamType update and destroy work from the admin panel
- [x] 11.4 Verify SeasonRules destroy works from the admin panel
- [x] 11.5 Verify TeamMembership shows no create or update controls in the admin panel
- [x] 11.6 Verify unauthenticated access to `/` and `/players` redirects to `/sign-in`
- [x] 11.7 Verify logout link appears in nav when logged in and signs the user out
- [x] 11.8 Run `mix precommit` and fix any issues
