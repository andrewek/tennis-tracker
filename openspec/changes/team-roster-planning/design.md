## Context

The app currently manages a flat list of players with NTRP ratings and age-group eligibility flags. There is no concept of teams, seasons, or roster assignments. Captains currently plan rosters outside the app (spreadsheets, paper lists) and want a collaborative, real-time tool to replace that workflow.

The primary use case is synchronous collaboration: multiple captains sitting together (or on their own devices) working through a shared pool of players, assigning them to teams within a given planning context (a season + team type).

The app uses the Ash framework for its domain layer and Phoenix LiveView for its UI.

## Goals / Non-Goals

**Goals:**
- Model USTA league team structure (team types, season rules, teams, memberships)
- Persist roster plans across sessions
- Support a planning board UI with real-time sync via PubSub
- Show non-blocking health indicators for rule violations
- Support mobile-friendly interaction (tap-to-assign, not just drag-and-drop)

**Non-Goals:**
- Gender tracking (deferred)
- Single team view (lineups, schedules, match stats)
- My Teams list / home screen
- Draft vs. finalized roster states
- UI for creating/editing TeamTypes or SeasonRules
- Tri-level, mixed, and 55+ formats

## Decisions

### 1. TeamType as seeded Ash resource, not an enum

**Decision**: Model TeamType as a full Ash resource with database rows, seeded at deploy time. Do not use an Elixir enum or hardcoded list.

**Rationale**: Future flexibility — we will eventually want UI to create new team types (mixed, tri-level, custom). A database-backed resource makes that natural. Seeding handles the immediate need without building CRUD UI.

**Alternative considered**: Hardcode team types as Elixir module constants. Rejected because it makes future extensibility harder and doesn't integrate cleanly with Ash relationships.

---

### 2. allowed_ntrp_levels stored as an array on TeamType

**Decision**: Store the list of permitted NTRP ratings for a team type as a `{:array, :decimal}` attribute on `TeamType`.

**Rationale**: The allowed levels are a fixed property of the team type definition (e.g. a 3.5 team allows `[3.0, 3.5]`). Storing them inline avoids a separate join table for a simple list.

**Alternative considered**: A separate `TeamTypeLevel` join table. Rejected as over-engineered for a list that changes only when team types are redefined.

---

### 3. SeasonRules as a separate resource, not embedded on Team

**Decision**: `SeasonRules` is its own resource with `(team_type_id, season_year)` uniqueness, not duplicated onto each `Team`.

**Rationale**: Rules apply to all teams of a given type in a season — they are shared configuration, not per-team state. Keeping them separate avoids drift and simplifies validation.

---

### 4. "Not Participating" as a pseudo-team, not a player flag

**Decision**: Model "Not Participating" as a `Team` record with `is_pseudo: true` scoped to a `(team_type_id, season_year)` planning context. Player membership in this pseudo-team is a real `TeamMembership` record.

**Rationale**:
- Persists across sessions without extra nullable fields on players
- Keeps the membership model uniform — every player in a planning context has exactly zero or one membership record
- Easy to query: "who is not participating in 18+ 3.5 this year?"

**Alternative considered**: A boolean/status flag on a player or a separate `PlayerSeasonStatus` table. Rejected — more tables for the same concept, less uniform query model.

---

### 5. Uniqueness constraint on TeamMembership

**Decision**: Enforce that a player can belong to at most one team of a given team type per season. Implemented as a unique index on `(player_id, team_type_id, season_year)` on the `team_memberships` table, where `team_type_id` and `season_year` are denormalized from the team onto the membership at insert time.

**Rationale**: This constraint must be enforced at the DB level to be reliable across concurrent collaborative sessions. Denormalizing avoids a join in the constraint check.

**Alternative considered**: Enforce only in application logic. Rejected — concurrent PubSub sessions make race conditions possible.

---

### 6. Real-time sync via Phoenix PubSub, not Presence

**Decision**: Use `Phoenix.PubSub` to broadcast membership change events to all subscribers of a planning context topic. Do not use `Phoenix.Presence` for tracking who is in the session.

**Rationale**: The primary need is data sync (player moved to team), not user presence (who is currently viewing). PubSub is sufficient and simpler. Presence can be layered on later.

**Topic format**: `roster_planner:{team_type_id}:{season_year}`

---

### 7. Health indicators computed in LiveView, not persisted

**Decision**: Roster health (rule violations) is computed on-the-fly in the LiveView from current membership state and SeasonRules. Not stored in the database.

**Rationale**: Health state is fully derivable from memberships + rules. Persisting it adds write complexity and cache invalidation risk. With LiveView, recomputing on each change is cheap.

---

### 8. Mobile interaction: tap-to-assign via modal/bottom sheet

**Decision**: On mobile, tapping a player card opens a bottom sheet listing available destinations (teams + Not Participating). On desktop, drag-and-drop is the primary interaction.

**Rationale**: Drag-and-drop is unusable on mobile when the board requires scrolling. The tap pattern is standard mobile UX and works well with LiveView's event model.

**Detection**: Use a CSS media query + LiveView assigns to conditionally render drag handles vs. tap targets. No JS framework needed — Phoenix LiveView JS hooks handle drag.

## Risks / Trade-offs

**Race condition on membership uniqueness** → Mitigated by DB-level unique constraint with denormalized `(player_id, team_type_id, season_year)`. LiveView optimistic updates should handle the UX for constraint violations gracefully.

**SeasonRules not seeded = no health indicators** → If no SeasonRules exist for a given (team_type, season_year), health checks silently pass. Mitigation: seed default SeasonRules alongside TeamTypes, or show a clear "no rules configured" indicator on the board.

**Drag-and-drop library choice** → Phoenix LiveView has limited native drag-and-drop. We'll use the browser's native HTML5 drag API with a colocated JS hook rather than pulling in a JS library. This keeps the bundle small but limits visual polish.

**PubSub message volume** → In a large planning session with many simultaneous moves, PubSub could produce rapid re-renders. Mitigation: debounce or batch updates if this becomes a problem in practice. Not expected to be an issue at realistic team sizes (10-20 players per board).

## Open Questions

- Should SeasonRules be seeded with default values for 2026, or left for the user to configure manually (e.g. via `iex`)? Suggest seeding reasonable defaults.
- When a player's NTRP rating is nil (unrated), health indicators should show a warning rather than an error — capture this in the roster-planner spec.
