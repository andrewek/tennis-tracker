## 1. Location Resource

- [x] 1.1 Create `TennisTracker.Tennis.Location` Ash resource with `name`, `address`, and `google_maps_url` attributes; add to `Tennis` domain
- [x] 1.2 Add `list_locations` read action (sorted A→Z by name) and `create_location` action to `Location`; expose via `define` in the domain
- [x] 1.3 Generate and run migration: `mix ash_postgres.generate_migrations --name add_locations && mix ecto.migrate`
- [x] 1.4 Add known venue seed data to `priv/repo/seeds.exs` with idempotent upsert (at least 3 real local venues with addresses and Google Maps URLs)

## 2. Match Resource

- [x] 2.1 Create `TennisTracker.Tennis.Match` Ash resource with `match_date`, `match_time`, `timezone` (default `"America/Chicago"`), `duration_minutes` (default `90`), `opponent`, and `home_or_away` (Ash enum: `:home`/`:away`) attributes; belongs_to `Team` (required) and `Location` (nullable); add to `Tennis` domain
- [x] 2.2 Add `create` action to `Match`
- [x] 2.3 Add `list_upcoming_matches_for_team` read action (filter `match_date >= today in match timezone`, sort asc by date then time, takes `team_id` arg)
- [x] 2.4 Add `list_past_matches_for_team` read action (filter `match_date < today in match timezone`, sort desc by date then time, takes `team_id` arg)
- [x] 2.5 Expose all three match domain functions via `define` in the `Tennis` domain
- [x] 2.6 Generate and run migration: `mix ash_postgres.generate_migrations --name add_matches && mix ecto.migrate`

## 3. Team Show Page — Schedule Section

- [x] 3.1 Update team show LiveView to load upcoming and past matches into two separate streams on mount/handle_params
- [x] 3.2 Replace placeholder schedule HTML with real upcoming matches stream; add empty state message when no upcoming matches
- [x] 3.3 Add past matches section with real past matches stream; add empty state message when no past matches
- [x] 3.4 Each match row links to `/matches/:id`

## 4. Match Creation on Team Show Page

- [x] 4.1 Add match creation form (modal or inline) to team show LiveView using `AshPhoenix.Form.for_create/3`; location field uses a `<select>` populated from `Tennis.list_locations!/0` with a blank/TBD option
- [x] 4.2 Handle `validate` and `save` events; on success, re-stream upcoming/past matches with `reset: true`
- [x] 4.3 Add "Add Match" button/link to schedule section that opens the form

## 5. Match Show Page

- [x] 5.1 Create `TennisTracker.Web.MatchLive.Show` LiveView at `/matches/:id` route in router
- [x] 5.2 Implement mount: load match with team and location preloaded; redirect with flash on not-found
- [x] 5.3 Render match details: date, time (formatted in match timezone), opponent, home/away, location name and address (or "Location TBD" if nil), Google Maps link (if present)
- [x] 5.4 Render team name as a link back to `/teams/:id`

## 6. Tests

- [x] 6.1 Unit tests for `Location` resource: create, list (sort order), seed idempotency
- [x] 6.2 Unit tests for `Match` resource: create with valid data, create without location succeeds, create with missing required field returns error, upcoming/past query filters and sort order
- [x] 6.3 LiveView integration test for team show page: team with upcoming and past matches renders both sections correctly
- [x] 6.4 LiveView integration test for team show page: team with no matches shows empty state in both sections
- [x] 6.5 LiveView integration test for match show page: renders details, shows map link when present, shows "TBD" when no location, redirects on not-found
- [x] 6.6 LiveView integration test for match creation: submitting valid form adds match to schedule; invalid form shows errors
