## Context

The app currently has two layouts: `Layouts.app` (standard pages) and `Layouts.full_bleed` (roster planner). Neither includes navigation links — users navigate entirely through contextual links on each page. The navbar contains only a logo and a sign-out button. There is no persistent display of the active group.

This change replaces both layouts with a single sidebar-based layout using daisyUI's `drawer` component, and introduces a consistent `<.page_header>` component to replace the ad-hoc heading markup used across LiveViews.

## Goals / Non-Goals

**Goals:**
- Single unified layout that works for all pages including the roster planner
- Persistent sidebar with group context and navigation links
- Responsive: sidebar always visible on `lg+` screens, drawer overlay on smaller screens
- Consistent `<.page_header>` component across all LiveViews
- Remove `Layouts.full_bleed`
- Remove dead `current_scope` attr from layout
- Keep auth pages on a separate simple layout (no sidebar)

**Non-Goals:**
- Active nav link highlighting
- Collapsible/icon-only desktop sidebar rail
- Group home page content improvements (separate work item)
- Conditional group switcher based on group count (always show link to `/groups`)
- Reworking roster planner page structure (separate work item in todo.md)

## Decisions

### Decision: daisyUI `drawer` for sidebar/mobile

daisyUI's drawer uses a hidden checkbox + label toggle — no JS required. `lg:drawer-open` keeps the sidebar permanently expanded at `lg` breakpoint and above. Below `lg`, a hamburger button in a sticky mobile top bar opens the drawer as an overlay.

**Alternative considered:** Custom CSS slide-in drawer with Phoenix LiveView JS commands. Rejected: more code to maintain, daisyUI drawer is already in the dependency and purpose-built for this.

### Decision: Single layout replaces both `app` and `full_bleed`

The new layout is structurally "full bleed" — `h-dvh` outer container (`100dvh`, accounts for mobile browser chrome), sidebar and content area as flex children, content area with `overflow-y-auto`. This satisfies both the roster planner (which needs full viewport height) and standard pages (which just scroll naturally). `h-dvh` is used rather than `h-screen` (`100vh`) because mobile browsers subtract the address bar from `dvh`, preventing content from being hidden behind browser UI.

`Layouts.full_bleed` is removed. The roster planner is updated to use `Layouts.app` and manages its own internal `overflow-x-auto` for the board columns.

**Alternative considered:** Keep two layouts, add sidebar to both. Rejected: duplicated sidebar markup, two codepaths to maintain.

### Decision: Full-width content area; max-width applied at the component level where needed

The new layout content area is full-width (no `max-w-*` wrapper). The `fluid` attribute on the old `Layouts.app` is removed. Where a max-width constraint makes sense, it is applied to the specific component (e.g., the Players table component gets a `max-w-*` class directly), not to the page layout. This keeps the layout simple and pushes width decisions to the content level where they belong.

### Decision: Auth pages use AshAuthentication's own layout — no `Layouts.simple` needed

The `sign_in_route` renders via `AshAuthentication.Phoenix.Overrides.DaisyUI`, which provides its own self-contained component tree. It does not call `Layouts.app` or any of our layout functions (only the root HTML shell `root.html.heex` is shared). No separate `Layouts.simple` is needed. Verification that auth pages render correctly is a manual check only.

### Decision: `<.page_header>` is a new component; old `<.header>` is deleted only after full migration

Rather than renaming `<.header>` to `<.page_header>` in one step (which would cause compile errors across all LiveViews simultaneously), a new `<.page_header>` component is added alongside the existing `<.header>`. LiveViews are migrated one at a time — search for each `<.header` usage, replace it, confirm it compiles. Once all call sites are confirmed gone (`<.header` returns zero results in the codebase), the `header/1` component definition is deleted.

This means there is a transitional period where both components exist. That is intentional and safe.

### Decision: `<.page_header>` replaces all page heading approaches

Some pages use `<.header>`, others use bare `<h1 class="...">` markup. Both are replaced by `<.page_header>`. The migration task list explicitly identifies which pages use which approach.

The component accepts:
- `title` (required attribute)
- `back_href` (optional attribute) — renders a `<.link navigate>` above the title
- `back_label` (optional attribute, defaults to `"Back"`)
- `<:subtitle>` slot (optional)
- `<:actions>` slot (optional)

**Alternative considered:** Separate `<.back_link>` component alongside `<.header>`. Rejected: the back link is always semantically paired with the page title; combining them reduces composition burden at the call site.

### Decision: Sidebar receives `current_group` and `current_user` as optional assigns

`current_group` defaults to nil. When nil, the sidebar omits group-specific nav links (Players, Teams, Roster Planning) and the group name display. `current_user` defaults to nil; when nil, the Admin link and Sign Out are omitted. Both attrs are declared with `default: nil` so LiveViews that lack these assigns can omit them from the layout call.

### Decision: Remove `current_scope` attr from `Layouts.app`

`current_scope` is a Phoenix scopes scaffold remnant. No LiveView passes it. It is removed.

### Decision: Home page migrated from PageController to HomeLive

`/` is currently handled by `PageController`, which is pure redirect logic (single group → that group's teams; multiple groups → `/groups`; not authenticated → `/sign-in`). `home.html.heex` exists but is dead code — `home/2` never calls `render/2`.

The controller is replaced by a `HomeLive` LiveView that performs the same redirect logic in `mount`. `HomeLive` uses `Layouts.app` with `current_user` and no `current_group`, making it consistent with the rest of the authenticated layout system. `PageController` and `home.html.heex` are deleted. The route changes from `get "/" → PageController` to `live "/" → HomeLive` within the `groups_routes` live session (which already enforces `live_user_required`).

**Alternative considered:** Keep `PageController` with no layout. Rejected: inconsistent with the goal of all authenticated pages using the unified layout; also leaves a redirect-only controller in place for "revisit home page" future work that expects a LiveView.

### Decision: No active nav detection

With a consistent `<.page_header>` title on every page, users always know where they are. Highlighting active nav links would add complexity (passing an `active_nav` atom through every LiveView) for marginal UX gain given the small number of nav items.

### Decision: Roster planner headers left as-is

The roster planner's internal header/navigation structure is left unchanged in this change. A separate todo item tracks reworking the planner into a conventional index/show split. Once that work happens, the planner will adopt `<.page_header>` naturally.

## Risks / Trade-offs

- **Roster planner migration** → The planner's internal layout must be adjusted to work within the new `h-full overflow-y-auto` content area. The planner currently relies on `full_bleed`'s `overflow-hidden` main element. Careful wrapper div adjustment is needed.
- **LiveView migration surface** → Every page needs updating. High breadth but low risk per file. The task list enumerates every file and identifies which heading approach each currently uses.
- **Non-group pages and nil current_group** → `groups/index_live` and `HomeLive` have no `current_group`. Both use `Layouts.app` without passing `current_group` (defaults to nil). Auth pages use AshAuthentication's own layout — no action needed.
- **Transitional period with both components** → `<.header>` and `<.page_header>` coexist during migration. This is safe as long as no new code uses `<.header>`.

## Migration Plan

1. Migrate `PageController` → `HomeLive`; delete `PageController` and `home.html.heex`
2. Add `<.page_header>` to `core_components.ex` (alongside existing `<.header>`)
3. Rework `Layouts.app` with daisyUI drawer sidebar; remove `fluid` and `current_scope` attrs
4. Remove `Layouts.full_bleed` (compile error on roster planner surfaces migration)
5. Migrate roster planner to `Layouts.app`; adjust internal layout
6. Migrate each LiveView one at a time: update layout call, replace heading approach with `<.page_header>`
7. Apply max-width to the Players table component
8. Search for all `<.header` usages, confirm zero, then delete `header/1` from `core_components.ex`
9. `mix precommit` — all green

No database migrations. The router changes only for the home route (`get` → `live`). Rollback is a git revert.

## Open Questions

None — all design decisions resolved.
