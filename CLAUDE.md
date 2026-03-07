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
mix ecto.gen.migration migration_name  # Generate a migration file (always use this, not touch)
mix ecto.migrate   # Run pending migrations
mix ecto.reset     # Drop, recreate, and migrate the DB
```

## Architecture

This is a Phoenix 1.8.5 application with PostgreSQL, LiveView, Tailwind CSS v4, and daisyUI.

**Layer separation:**
- `lib/tennis_tracker/` — business logic, Ecto schemas, context modules, Repo
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

**Ecto:**
- Preload associations before accessing them in templates
- Use `Ecto.Changeset.get_field/2` to read changeset fields (never map access `changeset[:field]`)
- `field :name, :string` even for text columns; `:text` is a migration concern, not a schema type
- Programmatically-set fields (e.g. `user_id`) must not appear in `cast/3` calls

**HTTP:** Use `Req` (already included) — never `:httpoison`, `:tesla`, or `:httpc`.

**Testing:**
- Use `start_supervised!/1` for processes; avoid `Process.sleep/1`
- Use `has_element?/2`, `element/2` — never assert on raw HTML strings
- Use `LazyHTML` to inspect rendered output when debugging selector failures
