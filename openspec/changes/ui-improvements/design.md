## Context

The app is a Phoenix 1.8 LiveView application using daisyUI + Tailwind v4. The current UI ships with the default Phoenix placeholder home page, a boilerplate navbar, and a players list that exposes age brackets as three separate boolean columns. The show page uses the standard `<.list>` component with no visual hierarchy. None of this reflects Tennis Tracker's identity.

Key files:
- `lib/tennis_tracker_web/components/layouts.ex` — app layout and navbar
- `lib/tennis_tracker_web/controllers/page_html/home.html.heex` — static home page
- `lib/tennis_tracker_web/controllers/page_controller.ex` — home page controller
- `lib/tennis_tracker_web/live/players/index_live.ex` — player list LiveView
- `lib/tennis_tracker_web/live/players/show_live.ex` — player detail LiveView

The `PlayerFilters.fetch_players/3` helper currently handles all query logic; we'll extend its sort order there.

## Goals / Non-Goals

**Goals:**
- Replace the boilerplate navbar with a Tennis Tracker-branded nav (Home + Players + theme toggle)
- Remove age bracket columns from the players table; render them as inline badge chips
- Add default sort (NTRP ascending, then name ascending) to the player list query
- Rework the player show page header: name + NTRP as H1-level hero, age bracket chips as sub-header
- Replace the default Phoenix home page with a branded card grid (Players, Teams, Winter Tennis) with abstract background and hover effects

**Non-Goals:**
- Dynamic/user-driven sort on the players list
- Functional Teams or Winter Tennis pages (links go nowhere for now)
- Any backend data changes or new resources

## Decisions

### Navbar markup lives in `layouts.ex`
The `app/1` component in `layouts.ex` contains the entire nav bar. We replace its contents directly — no new component file needed.

**Alternative**: Extract a `<.nav>` component. Rejected — one call site, unnecessary indirection.

### Age bracket chips: inline HEEx, no new component
The chip pattern (`badge badge-sm` daisyUI class) is simple enough to render inline in the table cell. A shared `<.age_bracket_chips player={@player} />` component would be reusable across list and show pages, keeping both DRY. We'll extract this as a small function component in `core_components.ex` since it's needed in two places.

### Sort order added to `PlayerFilters.fetch_players/3`
`PlayerFilters.fetch_players/3` calls `Ash.Query` to build the player query. We'll add an `Ash.Query.sort/2` call there (sort by `ntrp_rating asc`, then `name asc`). This keeps all query logic in one place.

**Alternative**: Sort in the LiveView `handle_params`. Rejected — query concerns belong with the query helper.

### Home page stays as a static controller template (not LiveView)
The home page has no dynamic data needs right now. Keeping it as a `page_controller` + `page_html/home.html.heex` is simpler and avoids adding a new LiveView route.

### Abstract background: reuse existing SVG approach
The existing home page uses an inline SVG with layered paths for the abstract background. We'll keep this pattern but restyle with tennis-appropriate colors (greens, earth tones) and make it work in both light and dark themes using Tailwind's `dark:` variant or daisyUI theme variables.

**Alternative**: CSS gradient background. Simpler, but the SVG gives more visual richness consistent with the current design language.

### Player show page hero: custom markup, not `<.header>`
The current show page uses `<.header>` which renders a standard title bar. We'll keep `<.header>` for actions (Edit/Delete buttons) but add a dedicated hero section above the `<.list>` that displays name as `<h1>`, NTRP as large text, and age bracket chips below.

## Risks / Trade-offs

- **Sort on NTRP string**: NTRP ratings are stored as strings ("2.5", "3.0", etc.). Alphabetical sort happens to match numeric order for these values, so string sort is acceptable. If non-standard values are ever introduced this could break. → Mitigation: document the assumption; revisit if NTRP becomes a numeric field.
- **Abstract SVG background in dark mode**: Hard-coded SVG fill colors won't automatically adapt to dark mode. → Mitigation: use `currentColor` where possible and daisyUI's `base-200`/`base-300` fills, or apply `opacity` variants to soften the background in dark mode.
- **Home page is a controller, not LiveView**: Flash messages won't work via LiveView channels on this page (already the case). Not a concern for this static landing page.
