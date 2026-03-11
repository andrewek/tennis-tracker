## Context

The `Player` resource has a `has_many :team_memberships` relationship. `TeamMembership` already denormalizes `team_type_id` and `season_year` from `Team`. `Team` has expression calculations `team_type_age_group` and `team_type_ntrp_level` that pull from the related `TeamType`. The player show LiveView currently loads the player with no relationship preloading.

Pseudo teams (used to track "not participating" players in the roster planner) must be excluded from the display. Sorting must be deterministic: newest season first, then age group, then NTRP level.

## Goals / Non-Goals

**Goals:**
- Show all non-pseudo team memberships on the player detail page
- Sort at the database level via Ash (not in Elixir after the fact)
- Filter pseudo teams at the relationship level so callers don't have to think about it

**Non-Goals:**
- Linking memberships to team show pages (future work)
- Pagination or limiting to recent seasons
- Editing memberships from this page

## Decisions

### Sorting strategy: try relationship calcs, fallback to denormalization

**Decision**: Attempt to sort the `has_many :team_memberships` relationship using `team.team_type_age_group` and `team.team_type_ntrp_level` (expression calcs on the related `Team`). If Ash rejects sorting on a `belongs_to`'s calculated fields inside a `has_many` sort block, denormalize `age_group` (string) and `ntrp_level` (decimal) onto `TeamMembership` — mirroring how `team_type_id` and `season_year` are already denormalized — and sort on those instead.

**Rationale**: Expression-calc sorting keeps the schema leaner and avoids a migration. Denormalization is the reliable fallback since it mirrors an established pattern in this codebase.

**Alternatives considered**:
- Sort in Elixir after loading: rejected because sorting should be a data-layer concern and this would break if pagination is added later.
- Add expression calcs to `TeamMembership` (e.g., `expr(team.team_type_age_group)`): this is essentially the "try first" path above — it depends on whether Ash allows sorting on such calcs in a relationship sort block.

### Filter pseudo teams on the relationship

**Decision**: Add `filter expr(team.is_pseudo == false)` directly to the `has_many :team_memberships` relationship on `Player`.

**Rationale**: This makes the relationship semantically correct — callers loading `:team_memberships` on a player should never see pseudo-team entries. It avoids littering filter logic across every call site.

### Display format

**Decision**: Render each membership as `"#{season_year} #{team_type.name} - #{team.name}"`.

**Rationale**: `team_type.name` is already formatted as "40+ 4.0", so composing the string from `season_year`, `team_type.name`, and `team.name` produces the desired "2026 40+ 4.0 - Team Alpha" format with no custom formatting logic.

### Loading strategy

**Decision**: In the show LiveView, load the player with:
```
Ash.Query.load([:team_memberships, team_memberships: [:team, team: [:team_type]]])
```

**Rationale**: Nested load ensures team and team_type data are available for display without N+1 queries.

## Risks / Trade-offs

- **Ash relationship filter on belongs_to field** → If `filter expr(team.is_pseudo == false)` is not supported in a `has_many` definition, the filter must move to a named read action on `TeamMembership` or be applied at the call site.
- **Denormalization drift** → If denormalized fields (`age_group`, `ntrp_level`) are added to `TeamMembership`, they must be kept in sync when `TeamType` changes. The existing denormalized fields (`team_type_id`, `season_year`) are set at membership creation and never updated, so this is an accepted pattern — but worth noting.

## Open Questions

- Does Ash 3.x support `filter expr(belongs_to_field == value)` in a `has_many` relationship definition? → Resolve at implementation time; fall back to a read action if not.
- Does `sort [team.team_type_age_group: :asc]` work in a `has_many` sort block? → Resolve at implementation time; fall back to denormalization if not.
