## Context

The app already has a Team show page at `/teams/:id`. The home page has a "Teams" card that currently links to `#` (no active destination). The Team Ash resource has a primary `:read` action that sorts by `season_year desc → team_type_age_group asc → team_type_ntrp_level desc → name asc`.

The team show page's back link navigates to `/` with a TODO comment to update it to `/teams` once the index exists.

## Goals / Non-Goals

**Goals:**
- Provide a `/teams` route with a LiveView listing all non-pseudo teams as cards
- Update the home page "Teams" card to link to `/teams`
- Update the team show page back link to navigate to `/teams`
- Show placeholder next-match data on each card (real match data doesn't exist yet)

**Non-Goals:**
- Creating or editing teams from this page
- Filtering or searching teams
- Real match data (schema doesn't exist yet)
- Pagination (team count is small)

## Decisions

**Pseudo-team filter belongs in the resource, not the domain function**
A new `:list_real` read action on the Team resource will carry the `is_pseudo == false` filter. This makes the constraint canonical and reusable rather than scattered across domain functions.

**`:list_real` inherits the primary sort**
The `:list_real` action applies the same `prepare` sort block as the primary `:read` action — `season_year desc, team_type_age_group asc_nils_last, team_type_ntrp_level desc_nils_last, name asc`. Sort logic lives in one place in the resource.

**Use `define` macro for the domain function**
`define(:list_real_teams, action: :list_real)` follows the same pattern as other domain functions (`list_players`, etc.) and keeps the domain module thin.

**Load calculations, not the relationship**
The card needs team type name, age group, and NTRP level. Add a `team_type_name` expression calculation (`expr(team_type.name)`) alongside the existing `team_type_age_group` and `team_type_ntrp_level` calcs. Load all three in the domain call. This avoids a separate relationship preload and runs entirely in SQL.

**Card subtitle matches the show page format**
The show page renders: `{team_type.name} · {age_group} · {ntrp_level} · {season_year}`. The index card subtitle SHALL use the same format, pulling from the loaded calculations.

**Page heading and layout**
The page H1 is "Teams". The browser tab title is "- Teams". Use `fluid={false}` on `<Layouts.app>` for a constrained-width layout (same as the players index).

**LiveView mount/handle_params stream pattern**
Initialize an empty stream in `mount/3`. Populate via `stream(socket, :teams, Tennis.list_real_teams!(), reset: true)` in `handle_params/3`. Consistent with the players index pattern.

**Sort/filter correctness is a domain-layer concern**
The `:list_real` action filter and sort are tested via domain unit tests against real DB data. The LiveView smoke test verifies rendering only — it does not assert ordering.

**Card layout matches home page cards**
Re-use the same daisyUI card style from the home page for visual consistency.

**Placeholder next match**
Hard-code "Next match: TBD" inside each card. No real match data model exists yet.

**Empty state: text only**
Display a heading "No teams yet" and subtext "Teams will appear here once they've been added." No icon.

## Risks / Trade-offs

- [Placeholder match data] Static text is acceptable short-term; future work will replace it with real data.
- [team_type_name calc] Adding a third expression calc is a minor schema change. No migration needed — expression calcs are not persisted.
