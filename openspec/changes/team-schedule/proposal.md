## Why

Team captains need to manage their match schedule and players need to see upcoming and past matches. Currently the team show page has a schedule placeholder with no actual functionality.

## What Changes

- Introduce a `Location` resource for known match venues (shared across teams, stable year to year)
- Introduce a `Match` resource with date, time, opponent name, home/away designation, and location
- Display matches on the team show page in chronological order, with upcoming and past matches separated
- Add a match show page with full match details
- Support pre-seeded known locations so captains select from a list rather than typing free-form addresses
- Include a Google Maps link on locations to allow easy navigation

## Capabilities

### New Capabilities
- `locations`: Manage known match venues with name, address, and map link; shared across teams
- `matches`: Create and display team matches with date, time, opponent, home/away, and location
- `team-schedule`: Show a team's full schedule (upcoming + past) on the team show page and a match detail page

### Modified Capabilities
- `team-show`: Schedule section is no longer a placeholder — now renders real match data

## Impact

- New Ash resources: `Location`, `Match` under the `Tennis` domain
- New DB tables and migrations via `mix ash_postgres.generate_migrations`
- New LiveViews: match show page; team show page updated
- Router gains a `/matches/:id` route (and possibly nested under teams)
- Seed data for known locations
- Data model designed to support future iCal/CSV calendar export (date + time stored separately or as a DateTime in UTC with timezone info, location address available)
