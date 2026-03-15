## 1. Team Resource Changes

- [x] 1.1 Add `team_type_name` expression calculation to `Team`: `calculate(:team_type_name, :string, expr(team_type.name))`
- [x] 1.2 Add `:list_real` read action to `Team`: filter `is_pseudo == false`, apply the same `prepare` sort block as the primary `:read` action (`season_year desc, team_type_age_group asc_nils_last, team_type_ntrp_level desc_nils_last, name asc`)

## 2. Domain Layer

- [x] 2.1 Add `define(:list_real_teams, action: :list_real)` to `TennisTracker.Tennis`, with `load: [:team_type_name, :team_type_age_group, :team_type_ntrp_level]`

## 3. Domain Tests

- [x] 3.1 Test that `:list_real` excludes pseudo-teams
- [x] 3.2 Test that `:list_real` returns teams in correct sort order (season year desc → age group asc → NTRP level desc → name asc), using fixtures that exercise each sort key

## 4. Router

- [x] 4.1 Add `live "/teams", Teams.IndexLive, :index` in the authenticated `ash_authentication_live_session` scope (alongside the existing `/teams/:id` route)

## 5. Teams Index LiveView

- [x] 5.1 Create `lib/tennis_tracker_web/live/teams/index_live.ex` with `mount/3` that initializes an empty `:teams` stream
- [x] 5.2 Add `handle_params/3` that calls `Tennis.list_real_teams!()` and populates the stream with `reset: true`
- [x] 5.3 Create the HEEx template wrapped in `<Layouts.app flash={@flash} current_user={@current_user} fluid={false}>` with page H1 "Teams" and browser title "- Teams"
- [x] 5.4 Render a responsive card grid (`grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4`) iterating the `:teams` stream
- [x] 5.5 Each card: team name as heading, subtitle `{team_type_name} · {age_group} · {ntrp_level} · {season_year}` (omit nil fields), "Next match: TBD" text, wrapped in `<.link navigate={~p"/teams/#{team}"}>`
- [x] 5.6 Add empty state (shown when stream is empty): heading "No teams yet", subtext "Teams will appear here once they've been added."

## 6. Home Page and Show Page Updates

- [x] 6.1 In `lib/tennis_tracker_web/controllers/page_html/home.html.heex`, change the Teams card `href="#"` to `href={~p"/teams"}`
- [x] 6.2 In `lib/tennis_tracker_web/live/teams/show_live.ex`, update the back link from `navigate={~p"/"}` to `navigate={~p"/teams"}` (resolves the existing TODO comment)

## 7. LiveView Tests

- [x] 7.1 Add smoke test: authenticated user visits `/teams` with real teams — each team name is visible on the page
- [x] 7.2 Add smoke test: no real teams exist — "No teams yet" is visible, no team cards rendered
- [x] 7.3 Add smoke test: unauthenticated user visiting `/teams` is redirected
- [x] 7.4 Update the home page test to assert the Teams card links to `/teams`
