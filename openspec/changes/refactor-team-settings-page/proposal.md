## Why

The team settings page is a single overloaded LiveView that mixes team configuration, match scheduling, lineup structure, and captain management into one wall of cards. This makes navigation confusing and the codebase difficult to maintain. A tabbed layout — consistent with the existing personal account settings pattern — separates concerns, reduces cognitive load, and makes the lineup slot UI extensible for future improvements.

## What Changes

- The team settings URL changes from `/g/:slug/teams/:id/edit` to `/g/:slug/teams/:id/settings`. The old `/edit` route is removed.
- `Teams.EditLive` is replaced by four focused LiveViews under a `Teams.Settings.*` namespace.
- A new `TeamComponents.settings_layout` component renders the four-tab nav bar shared across all settings LiveViews.
- A shared helper extracts the team-loading and permission-derivation logic common to all four LiveViews.
- The **General** tab consolidates team name, timezone, and lineup assignment mode into a single form.
- The **Match Schedule** tab isolates match listing and management (no behavior change).
- The **Lineup Settings** tab replaces the flat column + slot lists with a **card-per-category** layout: slots are nested inside their category card, and add/edit slot actions use a modal rather than inline forms. In both the add and edit modals, the category dropdown is shown and editable; the add modal pre-selects the category of the card that was clicked.
- The **Members** tab isolates captain management (no behavior change).
- All four tabs are visible to both team captains and group owners.

## Capabilities

### New Capabilities
- None — this change reorganizes existing capabilities, it does not introduce new ones.

### Modified Capabilities
- `team-edit-page`: URL changes to `/settings` with redirect from `/edit`; page splits into four tabs (General, Match Schedule, Lineup Settings, Members); slot management UI changes from flat inline forms to card-per-category with modal add/edit.

## Impact

- `lib/tennis_tracker_web/live/teams/edit_live.ex` — deleted
- `lib/tennis_tracker_web/live/teams/settings/` — new directory with four LiveView modules
- `lib/tennis_tracker_web/components/team_components.ex` — new or extended with `settings_layout/1`
- `lib/tennis_tracker_web/router.ex` — route changes
- Any hardcoded `/edit` links in other LiveViews or templates (team show page, elsewhere) need updating
- Existing tests for `Teams.EditLive` will need to be updated or replaced
