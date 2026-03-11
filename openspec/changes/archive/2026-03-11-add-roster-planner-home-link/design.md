## Context

The home page (`/`) renders a card grid defined in `lib/tennis_tracker_web/controllers/page_html/home.html.heex`. Currently it shows three cards: Players (active, links to `/players`), Teams (inactive), and Winter Tennis (inactive). The Roster Planner LiveView exists at `/roster-planner` but has no entry point from the home page.

## Goals / Non-Goals

**Goals:**
- Add a "Roster Planner" card to the home page grid that links to `/roster-planner`
- Match the visual style of the existing active Players card

**Non-Goals:**
- Changing the layout or styling of the grid
- Any changes to the Roster Planner LiveView itself

## Decisions

**Add directly to the existing home template** — The card grid lives in `home.html.heex`. Adding a fourth card there is the minimal change. No new components, controllers, or routes needed.

**Card is an active link** — Unlike Teams and Winter Tennis (which are placeholders), the Roster Planner route already exists, so the card should be a real navigable link.

## Risks / Trade-offs

- None significant. This is a one-line template addition.
