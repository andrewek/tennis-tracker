## Why

The default Phoenix layout uses `py-20` on `<main>`, creating excessive space between the navbar and page content across all pages. The roster planner board also lacks height constraints, requiring full-page vertical scrolling when the Unassigned column is long — making drag-and-drop awkward on desktop.

## What Changes

- Reduce `py-20` → `py-6` on `<main>` in `Layouts.app` (affects all pages)
- Add `Layouts.full_bleed`: a new layout variant that fills the viewport height with no padding, for pages that need full-screen board UI
- Update `board_column` component to support internal vertical scrolling
- Update roster planner to use `Layouts.full_bleed` with a compact inline title and a fixed-height column layout (Trello-style)

## Capabilities

### New Capabilities

- `full-bleed-layout`: A viewport-height-filling layout for board-style pages that constrains the board area to the window and allows each column to scroll independently

### Modified Capabilities

_(none — this is a layout and UX change with no domain behavior changes)_

## Impact

- `lib/tennis_tracker_web/components/layouts.ex` — reduce padding, add `full_bleed/1`
- `lib/tennis_tracker_web/components/board_components.ex` — `board_column` flex layout changes
- `lib/tennis_tracker_web/live/roster_planner_live.ex` — switch layout, restructure board wrapper
