---
name: liveview-testing
description: "Best practices for writing LiveView tests in this project. Consult this when writing or reviewing tests for LiveView modules."
---

## Core Rule: Use `has_element?` Instead of `html =~`

**Never** assert on raw HTML strings. Always use `has_element?/2` or `has_element?/3`.

```elixir
# WRONG — do not do this
{:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}")
assert html =~ "Captains"
assert html =~ captain.name

# RIGHT
{:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}")
assert has_element?(view, "h2", "Captains")
assert has_element?(view, "#captains-list", captain.name)
```

The same rule applies after events — do not call `render(view)` and then use `=~` on the result:

```elixir
# WRONG
view |> render_hook("add_captain", %{})
html = render(view)
assert html =~ target.name

# RIGHT
view |> render_hook("add_captain", %{})
assert has_element?(view, "#captains-list", target.name)
```

### Signatures

```elixir
has_element?(view_or_element, selector)               # checks element exists
has_element?(view_or_element, selector, text_filter)  # checks element exists + text matches
```

`text_filter` is matched as a substring of the element's text content.

---

## Always Bind `view`, Not `_view`

Since `has_element?` requires the live view process, always capture `view` even when you don't need the initial HTML:

```elixir
# WRONG — can't use has_element? with _view
{:ok, _view, html} = live(conn, path)
assert html =~ "something"

# RIGHT
{:ok, view, _html} = live(conn, path)
assert has_element?(view, "h2", "something")
```

---

## Selector Strategy

Pick selectors that are stable and meaningful, ordered by preference:

1. **ID selectors for streams** — stream containers have stable IDs:
   ```elixir
   has_element?(view, "#captains-list", "Alice Smith")
   has_element?(view, "#upcoming-matches", "vs. Opponents")
   ```

2. **Semantic element + text** — for headings, paragraphs, buttons:
   ```elixir
   has_element?(view, "h2", "Captains")
   has_element?(view, "p", "No captains assigned")
   has_element?(view, "button", "Add Captain")
   has_element?(view, "button[type='submit']", "Save")
   ```

3. **Form selectors** — use `phx-submit` or `phx-change` attributes to target specific forms:
   ```elixir
   has_element?(view, "form[phx-submit='save_team']")
   ```

4. **Avoid broad selectors** for negative assertions — `refute has_element?(view, "button", "Delete")` can give false confidence if the button text changes slightly. Prefer narrowing with a container:
   ```elixir
   refute has_element?(view, "#remove-captain-modal", "Remove from team entirely")
   ```

---

## Form Interaction

Use `form/3` with `render_submit/1` or `render_change/1` to drive forms:

```elixir
view
|> form("form[phx-submit='save_team']", %{
  "team_form" => %{"name" => "New Name", "default_timezone" => "America/Chicago"}
})
|> render_submit()

assert has_element?(view, ".flash", "Team updated")
```

For hooks/custom events use `render_hook/3`:

```elixir
view |> render_hook("select_captain_candidate", %{"user_id" => user.id})
view |> render_hook("add_captain", %{})
assert has_element?(view, "#captains-list", user.name || to_string(user.email))
```

---

## Redirect Assertions

When a LiveView redirects on mount or handle_params, `live/2` returns `{:error, {:live_redirect, ...}}`. Check the redirect target and flash there — no view is available:

```elixir
{:error, {:live_redirect, %{to: to, flash: flash}}} =
  live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

assert to == ~p"/g/#{grp.slug}/teams/#{team.id}"
assert flash["error"] =~ "not found"
```

`flash["error"] =~ "..."` is acceptable here because there is no live view process to query.

---

## Checking Stream Empty States

Streams render their empty-state element through conditional markup (`:if={@streams.x.inserts == []}`). To assert the empty state is visible, check for the element itself — don't inspect stream internals:

```elixir
# RIGHT — checks what the user actually sees
assert has_element?(view, "p", "No captains assigned")
assert has_element?(view, "p", "No upcoming matches scheduled")

# WRONG — brittle, depends on stream implementation detail
assert view.assigns.streams.captains.inserts == []
```

---

## Exceptions: When `=~` Is Acceptable

- **Flash in redirect tuples** — `assert flash["error"] =~ "some text"` (no view available)
- **Database-level assertions** — checking returned Ash records after an action:
  ```elixir
  roles = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)
  assert Enum.any?(roles, &(&1.user_id == user.id))
  ```
