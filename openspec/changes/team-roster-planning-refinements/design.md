## Context

The `team-roster-planning` spike is implemented on the `team-roster-planning-spike` branch. It introduced `Team`, `TeamType`, `SeasonRules`, `TeamMembership` Ash resources and `RosterPlannerLive`. Several areas were left rough: PubSub is wired manually, schema constraints are too strict or duplicated, the board loads all players into memory, and the team edit/create/delete UI is inline and scattered across multiple assigns.

These refinements do not add new user-facing features — they harden the existing implementation.

## Goals / Non-Goals

**Goals:**
- Replace manual Phoenix.PubSub calls with `Ash.Notifier.PubSub` on the affected resources
- Relax schema constraints on `SeasonRules` and `TeamType` with appropriate conditional validations
- Remove the unused `captain` attribute from `Team`
- Consolidate duplicated NTRP level constants into a single shared module
- Push board filtering to the database via Ash.Query
- Consolidate team create/edit/delete into a single modal with AshPhoenix.Form-driven validation

**Non-Goals:**
- No new user-facing roster planning features
- No changes to the `RosterHealth` logic
- No changes to the drag-and-drop or mobile tap-to-assign interactions
- No change to the seeding strategy or seed content beyond removing `captain` references

## Decisions

### 1. Ash.Notifier.PubSub with dynamic topics

**Decision:** Configure `Ash.Notifier.PubSub` on `Team` and `TeamMembership` with a custom topic function that produces `roster:{team_type_id}:{season_year}`. Remove `broadcast_update/1` from `RosterPlannerLive` and the manual `Phoenix.PubSub.subscribe/broadcast` calls.

**Rationale:** Ash.Notifier.PubSub integrates with the Ash notification pipeline, enabling future plugins (e.g., audit trail, events) to hook into the same lifecycle. Dynamic topics preserve the existing per-context fan-out pattern without subscribing to all resource events.

**Handle_info shape:** `%Ash.Notifier.Notification{resource: ..., action: ..., data: ...}` — the LiveView will pattern-match on this struct and reload the board, same as before.

**Alternative considered:** Broad subscribe (subscribe to all team/membership events, filter in handle_info by team_type_id/season_year on the notification data). Rejected because it requires the LiveView to know about and filter all notifications, adding fragility.

### 2. Shared NTRP constants module

**Decision:** Create `TennisTracker.Tennis.NtrpLevels` with:
- `team_levels/0` → `[Decimal.new("3.0"), Decimal.new("3.5"), Decimal.new("4.0"), Decimal.new("4.5")]`
- `player_levels/0` → `[Decimal.new("2.5") | team_levels()] ++ [Decimal.new("5.0")]`

Both `Player` and `TeamType` validations reference these functions. The relationship (player levels are a superset of team levels) is made explicit.

**Alternative considered:** A custom Ash type. Rejected as overly complex for what is essentially a list of constants.

### 3. Team resource-level default sort

**Decision:** Define the default sort on the primary `:read` action of `Team` using a `prepare` block with `Ash.Query.sort`. Sort order: `season_year: :desc`, then `team_type.age_group: :asc_nils_last`, then `team_type.ntrp_level: :desc_nils_last`, then `name: :asc`.

AshPostgres supports relationship-path sorting (pushing ORDER BY with a JOIN to SQL). If relationship-path sort is insufficient for nil handling across a join, introduce two `calculate` attributes on `Team` (`team_type_age_group`, `team_type_ntrp_level`) using `expr(team_type.age_group)` and sort on those instead. Verify during implementation — prefer the simpler relationship-path approach first.

**Why resource-level:** The sort reflects the natural ordering for any Team read; it should not need to be re-stated at each call site.

### 4. SeasonRules conditional validations

**Decision:** Set `allow_nil?(true)` on `min_roster`, `max_roster`, `on_level_min_pct`. Add Ash `validate numericality` with `greater_than: 0` for roster fields (guarded `where([present(:min_roster)])`) and a range check (0.0–100.0) for `on_level_min_pct` (guarded `where([present(:on_level_min_pct)])`). Apply these validations on both `:create` and `:update` actions.

### 5. TeamType conditional validations

**Decision:** Set `allow_nil?(true)` on `ntrp_level` and `age_group`. Add `where([present(:ntrp_level)])` and `where([present(:age_group)])` guards to the existing `attribute_in` validations, following the same pattern already used by `Player`'s NTRP validation.

### 6. Single @team_modal assign

**Decision:** Replace `@renaming_team_id`, `@rename_value`, `@deleting_team_id`, `@show_new_team_form`, `@new_team_name` with a single `@team_modal` assign of shape:

```elixir
nil
# or
%{mode: :create | :edit | :delete, form: %AshPhoenix.Form{} | nil, team: team | nil}
```

- `:create` — `AshPhoenix.Form.for_create(Team, :create, ...)`, `team: nil`
- `:edit` — `AshPhoenix.Form.for_update(team, :update, ...)`, `team: team`
- `:delete` — `form: nil`, `team: team` (confirmation UI, no form)

The modal is rendered in the top-level `render/1` and overlays the board. Events `open_team_modal`, `close_team_modal`, `validate_team_form`, `submit_team_form`, `confirm_delete_team` replace the current scattered inline events.

The `board_column` component emits `open_team_modal` events (with `mode` and `team_id` params) rather than managing inline state.

### 7. DB-level board filtering

**Decision:** Replace `Tennis.list_players!()` + in-memory filtering in `load_board` with a targeted Ash.Query for unassigned eligible players:

```elixir
Player
|> Ash.Query.filter(
  ^age_field == true and
  (is_nil(ntrp_rating) or ntrp_rating in ^allowed_levels) and
  not exists(team_memberships,
    team_type_id == ^team_type_id and season_year == ^season_year
  )
)
|> Ash.Query.sort(ntrp_rating: :desc_nils_last, name: :asc)
```

Where `age_field` is `:eligible_18_plus` or `:eligible_40_plus` dynamically from the `TeamType.age_group`. This removes the `eligible_for_team_type?/2` helper and the in-memory assigned-player MapSet check entirely.

Expose this as a domain function `Tennis.list_eligible_unassigned_players/3` (takes `team_type`, `team_type_id`, `season_year`).

## Risks / Trade-offs

- **Relationship-path sort in AshPostgres** → May not fully support nil handling across a join for the Team default sort. Mitigation: fall back to `calculate` attributes (`expr(team_type.age_group)`) if needed. Verify early in implementation.
- **Ash.Notifier.PubSub topic function API** → The exact DSL for dynamic topics (custom topic function vs. attribute interpolation) needs verification against the installed Ash version. Mitigation: check Ash changelog/docs during task 1.
- **Migration for nullable fields** → Any existing seed data or test fixtures that assume non-null `min_roster`/`max_roster`/`on_level_min_pct` will need review. Mitigation: scan seeds and tests before generating migrations.
- **Modal replaces inline state** → LiveView tests for rename/delete will break and need rewriting against new modal events. Mitigation: update tests as part of the modal task.
