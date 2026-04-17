## Context

`Teams.EditLive` is a single ~1,557-line LiveView handling team settings, match scheduling, lineup column/slot management, and captain management in one flat page. It accumulates a large number of assigns and form-state flags that interact with each other in ways that are hard to reason about.

The personal account settings page (`Account.ProfileLive`, `Account.SecurityLive`, `Account.PreferencesLive`) demonstrates a clean pattern: separate route-backed LiveViews per tab, connected by a shared layout component. This change brings team settings to the same pattern.

## Goals / Non-Goals

**Goals:**
- Replace `Teams.EditLive` with four focused LiveViews under `Teams.Settings.*`
- Add a shared tab nav component (`TeamComponents.settings_layout`)
- Introduce a shared helper for team loading and permission derivation
- Redesign the lineup slot management UI to reflect the category hierarchy (card-per-category, modal add/edit)
- Remove the `/edit` route; the new URL is `/settings`

**Non-Goals:**
- No changes to Ash data model or schema
- No drag-and-drop reordering (up/down buttons retained)
- No changes to match schedule behavior or captain management behavior

**Policy fix included in scope:** The `Team` `:update` action policy currently restricts name and timezone edits to group owners only. The intended behavior is that team captains can also update their own team's name, timezone, and assignment mode. `IsTeamCaptainOfSelf` will be added to the `:update` action policy as part of this change.
- No new authorization rules

## Decisions

### Decision: Separate route-backed LiveViews, not a single LiveView with tab state

**Chosen**: Four LiveViews at distinct routes, mirroring the account settings pattern.

**Alternatives considered**:
- Single LiveView with `?tab=xxx` query param or `live_action` switching. Simpler to scaffold but keeps all event handlers and assigns in one module. The existing module is already too large; this approach wouldn't reduce that.

**Rationale**: Separate LiveViews are independently testable, individually readable, and consistent with the established pattern in the codebase. Team loading and permission derivation are the only shared concerns, easily extracted to a helper.

---

### Decision: Shared helper module for team loading, not a mount hook

**Chosen**: A private helper module `TennisTrackerWeb.Teams.Settings.Helpers` (or similar) with a `load_team_settings/3` function returning `{:ok, assigns_map} | {:error, :not_found | :unauthorized}`. Each LiveView calls it in `handle_params/3`.

**Alternatives considered**:
- A `LiveView.on_mount` hook (like `GroupMountHook`). Hooks run before `handle_params`, so the team ID from params isn't available yet. This would require a two-phase approach.
- Duplicating the loading logic in each LiveView. Clear anti-pattern, ruled out immediately.

**Rationale**: A plain function called in `handle_params/3` has access to the team ID from params and is straightforward to test and reason about.

---

### Decision: `TeamComponents.settings_layout` as a slot-wrapping component

**Chosen**: A function component `settings_layout(assigns)` in `TennisTrackerWeb.TeamComponents` (creating the module if it doesn't exist, or adding to it). It receives `current_page`, `team`, and `current_group` as attrs and renders the four-tab nav followed by `render_slot(@inner_block)`.

**Rationale**: Direct mirror of `AccountComponents.settings_layout`. The tab links need `team.id` and `current_group.slug` to build the paths, so the component accepts those as attrs rather than relying on socket assigns directly.

---

### Decision: Slot modal state model

**Chosen**: A single `slot_modal` assign with shape `nil | {:add, column_id} | {:edit, slot_id}`, plus a `slot_form` assign holding the `AshPhoenix.Form`. Opening any slot modal (add or edit) closes the previous one.

The lineup settings LiveView assigns:
```
:slot_modal          → nil | {:add, col_id} | {:edit, slot_id}
:slot_form           → nil | Phoenix.HTML.Form.t()
:slot_to_delete      → nil | %TeamLineupSlot{}
:lineup_columns      → [%TeamLineupColumn{}, ...]
:lineup_slots        → [%TeamLineupSlot{}, ...]
```

For category column management (modal-based, mirroring the slot modal pattern):
```
:column_modal           → nil | :add | {:edit, column_id}
:column_form            → nil | Phoenix.HTML.Form.t()
:column_to_delete       → nil | %TeamLineupColumn{}
```

The delete button in a category card header is disabled when the category has slots (checked at render time from `@lineup_slots`). No `column_delete_error` assign is needed.

**Rationale**: Using a tagged tuple for `slot_modal` eliminates a proliferation of boolean flags (the current code has `show_add_slot_form`, `editing_slot_id`, `show_add_column_form`, `editing_column_id` as separate concerns). The tuple makes the modal state self-describing.

---

### Decision: Category grouping at render time, not a new data structure

**Chosen**: `lineup_slots` remains a plain list. In the template, group slots by column at render time:
```elixir
slots_by_column = Enum.group_by(@lineup_slots, & &1.team_lineup_column_id)
```

**Rationale**: No new query or data structure needed. The grouping is a pure display concern. Slots are already loaded for the team; grouping in the template is cheap and keeps the data loading simple.

---

### Decision: "Add slot" modal pre-selects the category but shows the dropdown

**Chosen**: When a captain clicks "+ Add slot" within a category card, the modal opens with that column pre-selected in the category dropdown. The dropdown remains visible and changeable, so clicking the wrong card is recoverable without closing and reopening.

**Rationale**: Pre-filling without showing the dropdown would hide information. Showing it editable is more transparent and handles the edge case of clicking the wrong card.

## Risks / Trade-offs

- **Existing test suite**: All tests targeting `Teams.EditLive` (by module name or by `/edit` URL) will break and need to be rewritten against the four new LiveViews. This is expected and acceptable.
- **Cross-tab link references**: Any other LiveView or template that links to `/edit` (e.g., team show page, match edit page back links) must be updated. A grep for `teams.*edit` in the template layer should surface all occurrences.
- **URL change**: The `/edit` route is removed entirely. All links in the codebase are updated to `/settings` as part of this change.

## Migration Plan

1. Add new routes to the router (`/settings`, `/settings/schedule`, etc.)
2. Add `/edit` redirect (either a router-level redirect or a thin LiveView that redirects in `mount`)
3. Implement the four new LiveViews and the shared helper
4. Add `TeamComponents.settings_layout`
5. Update all existing links from `/edit` to `/settings`
6. Delete `Teams.EditLive`
7. Update tests
