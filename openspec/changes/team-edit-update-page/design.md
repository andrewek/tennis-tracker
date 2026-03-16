## Context

The team show page (`/teams/:id`) currently handles both display and mutation: it renders roster and match schedule, and also owns the "Add Match" modal, form validation, and save logic. Team name editing lives only in the roster planner modal. There is no way to edit or delete a match once created.

The `Match` resource has `create` but no `update` or `destroy` actions. The `format_match_datetime/2` helper is copy-pasted into `Teams.ShowLive` and `Matches.ShowLive`.

## Goals / Non-Goals

**Goals:**
- Provide a dedicated `/teams/:id/edit` page for team settings (name, timezone) and match schedule management (add, edit, delete)
- Provide a dedicated `/matches/:id/edit` page for editing and deleting a match
- Make `/teams/:id` fully read-only
- Eliminate helper duplication via a shared `TennisTrackerWeb.MatchHelpers` module

**Non-Goals:**
- Match lineup management (future capability)
- Player availability on the match edit page
- Archiving/soft-deleting matches
- Timezone validation on the server side (UI constrains choices to a known-good list)
- Removing team name editing from the roster planner

## Decisions

### 1. Separate LiveView modules (not live actions on a single module)

The show and edit pages have different mount state, event handlers, and template structure. Sharing a module via live actions would add conditional branches throughout without meaningful code reuse. Two focused modules are easier to test and reason about.

### 2. `format_match_datetime/2` extracted to `TennisTrackerWeb.MatchHelpers`

Three LiveViews will need this function (`Teams.ShowLive`, `Teams.EditLive`, `Matches.ShowLive`, `Matches.EditLive`). A dedicated module avoids further copy-paste and gives a clear home for any future match display helpers. It is `import`ed in each LiveView that needs it, consistent with how `BoardComponents` is handled.

### 3. Timezone picker is a curated `<select>`, not free text

Seven US IANA zones cover all realistic team locations. A constrained select prevents invalid values and avoids needing server-side IANA validation. The stored value remains a valid IANA string.

Zones included:
| Label | IANA key |
|---|---|
| Eastern | America/New_York |
| Central | America/Chicago |
| Mountain | America/Denver |
| Mountain (no DST) | America/Phoenix |
| Pacific | America/Los_Angeles |
| Alaska | America/Anchorage |
| Hawaii | Pacific/Honolulu |

### 4. Team settings and match management on a single edit page

Keeping both concerns on one page avoids a fragmented editing experience (separate "settings" and "schedule" pages). The page has two clear visual sections. If the page grows unwieldy later, splitting is straightforward.

### 5. Match deletion redirects to `/teams/:id/edit`

After deleting a match (from either the team edit page or the match edit page), the user is redirected to `/teams/:id/edit` with a flash message. This keeps the user in "management mode" rather than dropping them to the read-only show page.

### 6. No new migrations required

`Match.update` accepts the same fields as `Match.create` (minus `team_id`). `Match.destroy` is a standard primary destroy. No schema changes needed.

## Risks / Trade-offs

- **Risk**: The team edit page streams matches from the same queries as show. If a user has the show page open in another tab and deletes a match on the edit page, the show page will be stale until reload. → **Mitigation**: Acceptable for now; PubSub-based refresh is a separate concern tracked in the todo.

- **Trade-off**: Duplicating team name editing in both the roster planner modal and the new edit page means two places to keep in sync if validation rules change. → Accepted deliberately; the roster planner workflow is fast/inline while the edit page is for more deliberate changes.

## Open Questions

None — all decisions were made during exploration.
