## Why

The teams index page shows "Next match: TBD" for every team card regardless of whether matches exist. Now that the Match resource and schedule queries are in place, each card should show real data so users can quickly see when a team's next match is without navigating to the team show page.

## What Changes

- Load the next upcoming match for each team when rendering the teams index
- Display the match date and time on each team card
- Continue showing "Next match: TBD" when no upcoming match exists

## Capabilities

### Modified Capabilities
- `teams-index`: Team cards show the real next upcoming match date and time instead of a hardcoded placeholder
