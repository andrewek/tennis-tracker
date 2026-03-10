## Why

The current UI lacks polish and navigational clarity — the navbar is cluttered, player data is presented in a dense table format, and the home page is a generic placeholder. These improvements make the app more usable and visually cohesive as we grow it into a full-featured tennis management tool.

## What Changes

- Simplify the navbar to show only "Tennis Tracker" (home link) and "Players", plus the light/dark mode toggle
- Replace the three-column (18+/40+/55+) layout on the Players index with inline chip-style age bracket badges next to each player's name
- Sort the players list by NTRP rating (ascending) then by name (ascending) by default
- Rework the player show page so the player's name and NTRP rating are displayed prominently (H1-level), with age bracket chips as a sub-header
- Replace the home page with a responsive card grid linking to Players, Teams, and Winter Tennis sections, with a subtle abstract background and hover effects that work in both light and dark mode

## Capabilities

### New Capabilities

- `player-list-view`: Players index page with inline age bracket chips and default NTRP/name sort order
- `player-detail-view`: Player show page with prominent name/NTRP header and chip-style age bracket sub-header
- `home-page`: Landing page with responsive card grid (Players, Teams, Winter Tennis) and styled background
- `navbar`: Simplified navigation with Home link, Players link, and light/dark mode toggle

### Modified Capabilities

## Impact

- `lib/tennis_tracker_web/components/layouts.ex` — navbar markup
- `lib/tennis_tracker_web/live/player_live/index.ex` and `index.html.heex` — list query order, chip rendering
- `lib/tennis_tracker_web/live/player_live/show.ex` and `show.html.heex` — header layout
- `lib/tennis_tracker_web/live/home_live.ex` (or equivalent home page LiveView/controller) — full replacement
- `assets/css/app.css` — any custom Tailwind utilities or overrides if needed
