## 1. Ash Relationship — Sort and Filter

- [x] 1.1 Attempt to add `sort [season_year: :desc, ...]` using `team.team_type_age_group` and `team.team_type_ntrp_level` in the `has_many :team_memberships` block on `Player` — verify it compiles and queries correctly
- [x] 1.2 If sorting on related calc fields is not supported: add `age_group` (string, nullable) and `ntrp_level` (decimal, nullable) as denormalized attributes to `TeamMembership`, and set them on membership create/update
- [x] 1.3 If denormalization path taken: generate and run the migration (`mix ash_postgres.generate_migrations --name add_age_group_ntrp_to_team_memberships && mix ecto.migrate`)
- [x] 1.4 Add `filter expr(team.is_pseudo == false)` to the `has_many :team_memberships` relationship on `Player` — verify pseudo memberships are excluded

## 2. Player Show LiveView

- [x] 2.1 Update `Tennis.get_player!/1` call (or the load) in `show_live.ex` to preload `[:team_memberships, team_memberships: [:team, team: [:team_type]]]`
- [x] 2.2 Assign loaded memberships to the socket (they come nested on `@player.team_memberships`)

## 3. Player Show Template

- [x] 3.1 Add a "Team Memberships" section to the player show template
- [x] 3.2 Render each membership as `"#{membership.season_year} #{membership.team.team_type.name} - #{membership.team.name}"`
- [x] 3.3 Render an empty-state message when the player has no memberships

## 4. Verification

- [x] 4.1 Manually verify the page renders correctly for a player with memberships in multiple seasons/team types
- [x] 4.2 Manually verify the page renders the empty state for a player with no memberships
- [x] 4.3 Verify pseudo-team memberships do not appear
- [x] 4.4 Run `mix precommit` and confirm all tests pass
