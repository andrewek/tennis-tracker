## Why

Group owners currently have no way to manage the list of match venues — locations can only be created via the admin panel or seeds. This change gives group owners a self-service UI to add, edit, and archive locations, and introduces a "Group Settings" navigation section that will grow to house other admin-only configuration in the future.

## What Changes

- Add `ash_archival` as a new dependency; extend the `Location` resource with soft-delete (archive/restore) support
- Remove the upsert behavior from `Location` create — duplicate name within a group should be a validation error, not a silent overwrite
- Add a missing `update` action to the `Location` resource
- Expose `update_location/2`, `archive_location/2`, and `unarchive_location/2` via the Tennis domain
- Generate a migration adding `archived_at` to the `locations` table
- Add a "Group Settings" collapsible nav section to the sidebar, visible only to group owners
- Add `/g/:group_slug/settings/locations` routes (index, new, edit)
- Implement `Settings.Locations.IndexLive` — lists active locations (with Edit/Archive) and archived locations (dimmed, with Restore); archive and restore both require confirmation modal
- Implement `Settings.Locations.FormLive` — shared create/edit form for name, address, google_maps_url

## Capabilities

### New Capabilities

- `location-management`: Group-owner UI to create, edit, archive, and restore locations; includes the "Group Settings" nav section

### Modified Capabilities

- `locations`: Adding archive/restore behavior (soft-delete via AshArchival) and removing upsert from create; duplicate names now surface as validation errors

## Impact

- `mix.exs`: new `:ash_archival` dependency
- `lib/tennis_tracker/tennis/location.ex`: add `AshArchival.Resource` extension, `update` action, revised `create` (no upsert)
- `lib/tennis_tracker/tennis.ex`: expose `update_location`, `archive_location`, `unarchive_location`
- New migration: `archived_at :utc_datetime` on `locations`
- `lib/tennis_tracker_web/components/layouts.ex`: "Group Settings" collapsible nav section
- `lib/tennis_tracker_web/router.ex`: new settings routes
- New LiveViews: `Settings.Locations.IndexLive`, `Settings.Locations.FormLive`
- Existing match form dropdowns automatically exclude archived locations (AshArchival filters all reads by default — no changes needed)
