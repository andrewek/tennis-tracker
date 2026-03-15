## Context

Every test file currently defines its own local `defp create_player/1`, `defp create_team_type/1`, etc. These are nearly identical across files but drift over time. The test suite already has ExMachina installed but it introduces an impedance mismatch with Ash: `ExMachina.Ecto` calls `Repo.insert!` directly (bypassing Ash actions and validations), while plain `ExMachina` requires a custom `insert/1` dispatcher that ends up being the same code you'd write without ExMachina at all.

## Goals / Non-Goals

**Goals:**
- Single factory module all tests can import
- All inserts go through Ash domain functions so validations always run
- Unique default values (collision-safe, debuggable) via `System.unique_integer([:positive])`
- Trait system for common configurations (e.g. `:unrated`, `:_40_plus_35`)
- Auto-create dependencies with explicit-override escape hatch
- `season_year` defaults to `Date.utc_today().year`, always overridable

**Non-Goals:**
- No `build/2` (non-persisting) variant — pure unit tests use plain maps directly
- No ExMachina — not worth the Ash integration friction
- No property-based / StreamData generation
- No seeding production or dev data

## Decisions

### Plain module over ExMachina

**Decision:** `TennisTracker.Factory` is a plain Elixir module with regular functions.

**Rationale:** ExMachina's value-add (`build/insert`, sequences, traits) requires either `ExMachina.Ecto` (which bypasses Ash) or a custom `insert/1` dispatcher (which is just the factory code we'd write anyway, wrapped in macro machinery). A plain module is fully Ash-native and has no indirection.

**Alternative considered:** Plain ExMachina with custom `insert/1`. Rejected because the calling API (`Factory.player(...)` vs `insert(:player, ...)`) is nearly identical and the ExMachina layer adds complexity without benefit.

### Trait system via `traits:` keyword key

**Decision:** Traits are passed as `traits: [:unrated, :eligible_40_plus]`. Traits are merged first; explicit attrs in the same call override trait values.

```elixir
Factory.player(traits: [:unrated])
Factory.player(traits: [:unrated], name: "Alice")   # name wins over trait
Factory.team_type(traits: [:_40])
```

**Rationale:** Clean separation between "semantic preset" and "specific override". No ambiguity about which wins. No need to distinguish atom-headed lists from keyword lists at the call site.

**Alternative considered:** Traits as first positional arg (`Factory.player([:unrated], name: "Alice")`). Rejected because pattern matching on atom-headed vs keyword lists is fragile and surprising.

### Dependency auto-creation with override

**Decision:** Each factory function auto-creates required dependencies when not provided. Dependencies are passed as special named keys that are extracted before the remaining attrs are forwarded to Ash.

```elixir
Factory.team()                          # auto-creates a TeamType
Factory.team(team_type: my_tt)          # use this TeamType; derive team_type_id from it
Factory.team(team_type: my_tt, name: "X")  # team_type extracted; name forwarded to Ash

Factory.team_membership(player: p, team: t)  # derives team_type_id and season_year from team
```

Special keys per resource:
- `team/1` — `team_type:` (extracts, derives `team_type_id`)
- `season_rules/1` — `team_type:` (extracts, derives `team_type_id`)
- `team_membership/1` — `player:` and `team:` (extracts both; derives `player_id`, `team_id`, `team_type_id`, `season_year` from the team)

**Rationale:** Tests that share a `team_type` across multiple records need explicit control. Tests that only need a record and don't care about its dependencies get the easy path.

### Default values

**Player defaults:** `eligible_18_plus: true`, `ntrp_rating: Decimal.new("3.5")`, plus a unique name, email, and phone number (all incorporating `System.unique_integer([:positive])`).

**TeamType defaults:** equivalent to `:_35` — `age_group: "18_plus"`, `ntrp_level: Decimal.new("3.5")`, `allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]`, plus a unique name.

**SeasonRules defaults:** `min_roster: 8`, `max_roster: 18`, `on_level_min_pct: Decimal.new("0.60")`.

### Traits catalogue

All Decimal values use `Decimal.new/1`, not bare floats, to match the rest of the codebase.

**Player traits:**
- `:unrated` → `ntrp_rating: nil`
- `:eligible_40_plus` → `eligible_40_plus: true`
- `:eligible_55_plus` → `eligible_55_plus: true`
- `:ineligible` → `eligible_18_plus: false, eligible_40_plus: false, eligible_55_plus: false`

**TeamType traits** (encode consistent `age_group + ntrp_level + allowed_ntrp_levels` combos):
- `:_35` → `age_group: "18_plus", ntrp_level: Decimal.new("3.5"), allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]`
- `:_40` → `age_group: "18_plus", ntrp_level: Decimal.new("4.0"), allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]`
- `:_40_plus_35` → `age_group: "40_plus", ntrp_level: Decimal.new("3.5"), allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]`
- `:_40_plus_40` → `age_group: "40_plus", ntrp_level: Decimal.new("4.0"), allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]`

**Team traits:**
- `:pseudo` → `is_pseudo: true`

### season_year default

**Decision:** `Date.utc_today().year` — evaluated at call time, not compile time.

**Rationale:** Tests hardcode `2026` today, but the factory should stay valid as years advance without requiring edits. Always overridable: `Factory.team(season_year: 2025)`.

### TeamMembership creation via assign_player

**Decision:** `Factory.team_membership/1` calls `Tennis.assign_player/4` rather than `Tennis.create_team_membership!/1` directly. All refactored tests that previously called `Tennis.create_team_membership!/1` inline should also switch to `Tennis.assign_player/4`.

**Rationale:** `assign_player` is the domain's intended entry point for placing a player on a team — it handles the upsert case (moving a player from one team to another within the same context) and is the function used in the actual application. Using `create_team_membership!` in tests would diverge from how production code works.

### Alias location

**Decision:** `alias TennisTracker.Factory` added to `TennisTracker.DataCase` and `TennisTrackerWeb.ConnCase` using blocks, so all tests can call `Factory.player()`, `Factory.team()`, etc. without additional setup.

**Rationale:** `import TennisTracker.Factory` would make factory functions available unqualified (`player()`, `team()`), which risks name collisions with test-local functions. `alias` preserves the `Factory.` prefix shown in all usage examples and makes call sites self-documenting.

## Risks / Trade-offs

- **Ash action changes ripple into factory** — if a create action's `accept` list changes, the factory call may break. Mitigation: factory functions are thin wrappers; breakage is immediately visible in tests.
- **Auto-created dependencies are invisible** — a test calling `Factory.team()` creates a TeamType that the test can't reference. Mitigation: documented clearly; tests that need the TeamType should create it explicitly and pass it in.
- **`Date.utc_today().year` crosses midnight** — a test run that straddles midnight Jan 1 could create records with mixed years. Mitigation: essentially theoretical; tests run in isolated transactions.
- **`SeasonRules` uniqueness constraint** — `SeasonRules` has a unique constraint on `[:team_type_id, :season_year]`. Calling `Factory.season_rules(team_type: my_tt)` twice in the same test for the same team type will raise a constraint error. This is intentional: it forces tests to be explicit when they need multiple season rules records (pass a different `season_year` or a different `team_type`).
