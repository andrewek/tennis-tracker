## Why

The current layout is a minimal top-nav with no navigation links, no group context, and no consistent page structure — it requires users to navigate entirely through contextual links on each page. A sidebar-based layout provides persistent, predictable navigation and makes the active group immediately visible at all times.

## What Changes

- **BREAKING**: Remove `Layouts.full_bleed` — replaced by a single unified layout
- Replace `Layouts.app` with a new sidebar-based layout using daisyUI `drawer`
- Add a persistent sidebar with group name, nav links (Players, Teams, Roster Planning), and utility links (Switch Organization, Admin, Theme Toggle, Sign Out)
- Sidebar is always visible on large screens (`lg:drawer-open`); collapses to a slide-in overlay with hamburger toggle on mobile
- Replace the existing `<.header>` component with a consistent `<.page_header>` component that supports a back link, subtitle, and actions slot
- Migrate all LiveViews from `Layouts.full_bleed` / `Layouts.app` to the new layout
- Migrate all LiveViews from `<.header>` to `<.page_header>`

## Capabilities

### New Capabilities

- `sidenav-layout`: The unified application layout — daisyUI drawer, sidebar with nav + utility links, scrollable content area, mobile top bar with hamburger
- `page-header`: Consistent page header component with title, optional back link (attributes), optional subtitle slot, and optional actions slot

### Modified Capabilities

- `navbar`: The existing navbar spec covers the old top-nav. This change replaces that entirely — the new nav lives in the sidebar.
- `full-bleed-layout`: The full-bleed layout is removed and absorbed into the new unified layout.

## Impact

- `lib/tennis_tracker_web/components/layouts.ex` — `app/1` reworked, `full_bleed/1` removed
- `lib/tennis_tracker_web/components/core_components.ex` — `<.header>` renamed/replaced with `<.page_header>`
- All group-scoped LiveViews — layout call updated, `<.header>` → `<.page_header>` with back links added where missing
- `lib/tennis_tracker_web/live/roster_planner_live.ex` — migrated from `full_bleed` to new layout
- No router changes required
- No Ash domain or database changes
