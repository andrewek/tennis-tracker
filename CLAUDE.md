# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
mix setup          # Install deps, create/migrate DB, build assets (run once after clone)
mix phx.server     # Start dev server at http://localhost:4000
mix test           # Run all tests
mix test test/path/to/my_test.exs  # Run a single test file
mix test --failed  # Re-run only previously failed tests
mix precommit      # Run before committing: compile (warnings-as-errors), format, test
mix ash_postgres.generate_migrations --name migration_name  # Generate Ash migrations (always use this, not mix ecto.gen.migration)
mix ecto.migrate   # Run pending migrations
mix ecto.reset     # Drop, recreate, and migrate the DB
```

## Architecture

This is a Phoenix 1.8.5 application with PostgreSQL, LiveView, Tailwind CSS v4, daisyUI, and Ash framework (ash ~> 3.0, ash_postgres ~> 2.0, ash_phoenix ~> 2.0).

**Layer separation:**
- `lib/tennis_tracker/` — Ash domains, Ash resources, Repo
- `lib/tennis_tracker_web/` — Phoenix endpoint, router, controllers, LiveViews, components
- `lib/tennis_tracker_web/components/core_components.ex` — shared UI components (`<.button>`, `<.input>`, `<.icon>`, `<.flash>`, etc.)
- `lib/tennis_tracker_web/components/layouts.ex` — app layout (`<Layouts.app>`) and theme toggle

**Supervision tree** (`lib/tennis_tracker/application.ex`):
`Telemetry → Repo → DNSCluster → PubSub → Endpoint`

**Request flow:** `Endpoint → Router → Controller/LiveView → HEEx template`

**Frontend:** Tailwind v4 (no `tailwind.config.js`; configured via `@import` directives in `assets/css/app.css`), esbuild for JS. Only `app.js` and `app.css` bundles are supported — all vendor deps must be imported into these files.

## Key Conventions

> **Full guidelines are in `AGENTS.md`** — read it for detailed rules on LiveView, Ecto, HEEx, forms, hooks, and testing. The summary below highlights the most error-prone areas.

**LiveView:**
- Always wrap LiveView templates with `<Layouts.app flash={@flash} ...>`
- Use `<.link navigate={}>` / `push_navigate` (not deprecated `live_redirect`)
- Use streams (`stream/3`, `stream_delete/3`) for collections — never assign plain lists
- Streams are not enumerable; to filter, refetch and re-stream with `reset: true`
- Colocated JS hooks use `:type={Phoenix.LiveView.ColocatedHook}` and names **must** start with `.`

**Forms:**
- Always drive forms via `to_form/2` assigned in the LiveView, accessed as `@form[:field]` in templates
- Never pass a changeset directly to `<.form>` or access `@changeset` in templates

**HEEx:**
- Use `{...}` for attribute interpolation; use `<%= ... %>` for block constructs (`if`, `case`, `for`) in tag bodies
- Conditional classes: use list syntax `class={["base-class", @flag && "conditional-class"]}`
- Comments: `<%!-- comment --%>`
- No `else if` / `elsif` — use `cond` or `case`

**Ash:**
- Define data in Ash resources (`use Ash.Resource`) grouped under Ash domains (`use Ash.Domain`)
- Call domain functions (e.g. `Tennis.list_players/1`, `Tennis.create_player/1`) rather than writing raw Ecto queries
- Use `AshPhoenix.Form.for_create/3` and `AshPhoenix.Form.for_update/3` for forms; submit with `AshPhoenix.Form.submit/2`
- Use `Ash.Query` macros for filtering: `require Ash.Query` then `Ash.Query.filter(query, ...)`
- Generate migrations with `mix ash_postgres.generate_migrations --name name` — **never** use `mix ecto.gen.migration`
- Resource snapshots live in `priv/resource_snapshots/`; do not edit them manually

**HTTP:** Use `Req` (already included) — never `:httpoison`, `:tesla`, or `:httpc`.

**Adding new resource fields:**
- Before adding a new field, ask: Can this field be nil? What validations apply (allowed values, numeric bounds, format, length)? Does it need a unique constraint or index?
- Do not assume non-nullable or pick validation rules without explicit confirmation.

**Testing:**
- Use `start_supervised!/1` for processes; avoid `Process.sleep/1`
- Use `has_element?/2`, `element/2` — never assert on raw HTML strings
- Use `LazyHTML` to inspect rendered output when debugging selector failures
