## 1. Migrate Home Page to LiveView

- [ ] 1.1 Create `lib/tennis_tracker_web/live/home_live.ex` with `mount/3` that performs the same redirect logic as `PageController.home/2`: one group → `push_navigate` to that group's teams; otherwise → `push_navigate` to `/groups`
- [ ] 1.2 Render a minimal loading state in `render/1` wrapped in `<Layouts.app flash={@flash} current_user={@current_user}>`
- [ ] 1.3 Update `router.ex`: replace `get "/", PageController, :home` with `live "/", HomeLive, :index` inside the `groups_routes` live session
- [ ] 1.4 Delete `lib/tennis_tracker_web/controllers/page_controller.ex`
- [ ] 1.5 Delete `lib/tennis_tracker_web/controllers/page_html/home.html.heex` (dead code — never rendered by the controller)
- [ ] 1.6 Delete `lib/tennis_tracker_web/controllers/page_html.ex` if it exists and is now empty
- [ ] 1.7 Run `mix compile` — no errors

## 2. New page_header Component

- [ ] 2.1 Add a new `page_header/1` function component to `core_components.ex` alongside the existing `header/1` (do NOT remove `header/1` yet)
- [ ] 2.2 Declare `title` as a required string attribute
- [ ] 2.3 Declare `back_href` as an optional string attribute (default nil) and `back_label` as an optional string attribute (default `"Back"`)
- [ ] 2.4 Render a `<.link navigate={@back_href}>← {@back_label}</.link>` above the title when `back_href` is not nil
- [ ] 2.5 Add `<:subtitle>` as an optional slot rendered below the title in a visually subordinate style
- [ ] 2.6 Add `<:actions>` as an optional slot rendered to the right of the title

## 3. New Sidebar Layout

- [ ] 3.1 In `layouts.ex`, define a private `sidebar/1` function component accepting `current_group` (nullable map) and `current_user` (nullable map)
- [ ] 3.2 Sidebar top: app name/logo linking to `/`; current group name when `current_group` is not nil
- [ ] 3.3 Sidebar nav section (only when `current_group` is not nil): Players → `/g/:slug/players`, Teams → `/g/:slug/teams`, Roster Planning → `/g/:slug/roster-planner`
- [ ] 3.4 Sidebar bottom (only when `current_user` is not nil): "Switch Organization" → `/groups`, `<.theme_toggle />`, "Sign out" → `/sign-out`
- [ ] 3.5 Sidebar bottom: "Admin" → `/admin` shown only when `current_user.role == :admin`
- [ ] 3.6 Rework `Layouts.app/1` to use daisyUI `drawer` structure: `<div class="drawer lg:drawer-open">`, hidden checkbox input, `drawer-content` div, `drawer-side` div containing `<.sidebar>`
- [ ] 3.7 In `drawer-content`, add a sticky mobile top bar (hidden at `lg+`) containing: hamburger `<label>` toggle, and either the current group name (when `current_group` is not nil) or "Tennis Tracker" (when nil)
- [ ] 3.8 Place `<.flash_group flash={@flash} />` inside `drawer-content` but outside the scrollable `<main>` element, so flash messages are visible when the drawer is closed
- [ ] 3.9 Make `<main>` `overflow-y-auto` with padding (`px-6 py-8`)
- [ ] 3.10 Ensure outer container is `h-dvh overflow-hidden`
- [ ] 3.11 Declare attrs on `Layouts.app/1`: `flash` (required), `current_user` (optional, default nil), `current_group` (optional, default nil); remove `fluid` and `current_scope`
- [ ] 3.12 Spot-check: light mode and dark mode render sidebar correctly

## 4. Remove Full-Bleed Layout

- [ ] 4.1 Delete `full_bleed/1` from `layouts.ex`
- [ ] 4.2 Confirm the compiler error in the roster planner (expected — surfaces migration)

## 5. Migrate Roster Planner

- [ ] 5.1 Update `roster_planner_live.ex` to use `<Layouts.app flash={@flash} current_user={@current_user} current_group={@current_group}>`
- [ ] 5.2 Adjust the planner's internal wrapper divs so board columns still fill available height and scroll independently within the new `overflow-y-auto` content area
- [ ] 5.3 Leave roster planner heading/nav structure as-is (separate todo item tracks full restructure)

## 6. Migrate LiveViews

Each task: update the layout call to pass `current_group={@current_group}` where the assign exists, and replace the page heading with `<.page_header>`.

Current heading approach per file:
- `<.header>` users: `groups/index_live`, `players/index_live`, `players/form_live`, `players/import_live`, `teams/index_live`
- Bare `<h1>` users: `teams/show_live`, `players/show_live`, `matches/show_live`
- No standard heading: `group_home_live`, `teams/edit_live`, `matches/edit_live`

- [ ] 6.1 `home_live.ex` — already uses `Layouts.app` with no `current_group`; add `<.page_header title="Tennis Tracker" />`
- [ ] 6.2 `group_home_live.ex` — add `current_group={@current_group}`; add `<.page_header title="Home" />`
- [ ] 6.3 `groups/index_live.ex` — `Layouts.app` without `current_group` (no such assign); replace `<.header>` with `<.page_header title="Organizations" />`
- [ ] 6.4 `teams/index_live.ex` — add `current_group={@current_group}`; replace `<.header>` with `<.page_header title="Teams" />`
- [ ] 6.5 `teams/show_live.ex` — add `current_group={@current_group}`; replace bare `<h1>` with `<.page_header back_href={~p"/g/#{@current_group.slug}/teams"} back_label="Teams">` with title from `@team.name`
- [ ] 6.6 `teams/edit_live.ex` — add `current_group={@current_group}`; add `<.page_header>` with back link to team show page
- [ ] 6.7 `players/index_live.ex` — add `current_group={@current_group}`; replace `<.header>` with `<.page_header title="Players" />`
- [ ] 6.8 `players/form_live.ex` (:new) — add `current_group={@current_group}`; replace `<.header>` with `<.page_header title="New Player" back_href={~p"/g/#{@current_group.slug}/players"} back_label="Players" />`
- [ ] 6.9 `players/form_live.ex` (:edit) — replace `<.header>` with `<.page_header title="Edit Player">` with back link to player show page
- [ ] 6.10 `players/show_live.ex` — add `current_group={@current_group}`; replace bare `<h1>` with `<.page_header back_href={~p"/g/#{@current_group.slug}/players"} back_label="Players">` with title from player name
- [ ] 6.11 `players/import_live.ex` — add `current_group={@current_group}`; replace `<.header>` with `<.page_header title="Import Players" back_href={~p"/g/#{@current_group.slug}/players"} back_label="Players" />`
- [ ] 6.12 `matches/show_live.ex` — add `current_group={@current_group}`; replace bare `<h1>` with `<.page_header>` with back link to team show page
- [ ] 6.13 `matches/edit_live.ex` — add `current_group={@current_group}`; add `<.page_header>` with back link to match show page

## 7. Players Table Max-Width

- [ ] 7.1 Apply a `max-w-*` constraint directly to the Players table component (or its wrapper in `players/index_live.ex`), not to the layout or page

## 8. Delete Old header Component

- [ ] 8.1 Search the codebase for `<.header` — list every remaining usage
- [ ] 8.2 Replace each remaining `<.header` usage with `<.page_header` (there should be none after task group 6, but confirm)
- [ ] 8.3 Confirm zero `<.header` results anywhere in the codebase
- [ ] 8.4 Delete the `header/1` function component from `core_components.ex`
- [ ] 8.5 Run `mix compile` — confirm no errors

## 9. Verification

- [ ] 9.1 Run `mix precommit` — all green
- [ ] 9.2 Manually verify sidebar on desktop (`lg+`): group name, nav links, utility links visible
- [ ] 9.3 Manually verify mobile: top bar visible with group name (or app name when no group), drawer opens and closes
- [ ] 9.4 Manually verify dark mode applies correctly to sidebar
- [ ] 9.5 Manually verify roster planner board fits viewport and columns scroll
- [ ] 9.6 Manually verify auth page (sign-in) renders correctly — no sidebar, AshAuthentication layout unchanged
- [ ] 9.7 Verify Admin link hidden for non-admin users; visible for system admins
- [ ] 9.8 Manually verify flash messages are visible when navigating to a page that sets a flash (e.g., after a form save)
