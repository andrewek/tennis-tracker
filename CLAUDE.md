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

<!-- usage-rules-start -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
