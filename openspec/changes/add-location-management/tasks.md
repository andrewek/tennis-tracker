## 1. Dependency and Data Layer

- [ ] 1.1 Add `{:ash_archival, "~> 1.0"}` to `mix.exs` and run `mix deps.get`
- [ ] 1.2 Add `AshArchival.Resource` extension to `TennisTracker.Tennis.Location`; add `archive_related []` configuration if needed
- [ ] 1.3 Remove `upsert?`, `upsert_identity`, and `upsert_fields` from the `create` action on `Location`
- [ ] 1.4 Add `update :update` action to `Location` accepting `[:name, :address, :google_maps_url]`
- [ ] 1.5 Run `mix ash_postgres.generate_migrations --name add_location_archived_at` and verify the generated migration adds `archived_at` to `locations`
- [ ] 1.6 Run `mix ecto.migrate`

## 2. Tennis Domain Functions

- [ ] 2.1 Add `define :get_location, action: :read, get_by: [:id]` to the Location resource block in `TennisTracker.Tennis` domain
- [ ] 2.2 Add `define :update_location, action: :update` to `TennisTracker.Tennis` domain
- [ ] 2.3 Add `define :archive_location, action: :archive` to `TennisTracker.Tennis` domain
- [ ] 2.4 Add `define :unarchive_location, action: :unarchive` to `TennisTracker.Tennis` domain
- [ ] 2.5 Add a `list_archived_locations` read action to the `Location` resource that uses AshArchival's query context (`Ash.Query.set_context(query, %{ash_archival: %{include_archived: true}})`) combined with `filter(not is_nil(archived_at))` and sorts by name; expose it via `define :list_archived_locations, action: :list_archived_locations` in the domain

## 3. Router

- [ ] 3.1 Add settings routes inside the existing `:group_scoped_routes` `ash_authentication_live_session` block:
  - `live "/g/:group_slug/settings/locations", Settings.Locations.IndexLive, :index`
  - `live "/g/:group_slug/settings/locations/new", Settings.Locations.FormLive, :new`
  - `live "/g/:group_slug/settings/locations/:id/edit", Settings.Locations.FormLive, :edit`

## 4. Sidebar Nav

- [ ] 4.1 Add `attr :current_group_role, :atom, default: nil` to the `Layouts.app` component
- [ ] 4.2 Update all group-scoped LiveView templates (~10 files) to pass `current_group_role={@current_group_role}` to `<Layouts.app ...>`
- [ ] 4.3 In `TennisTrackerWeb.Layouts`, add a "Group Settings" collapsible `<details>` section to the sidebar nav, rendered only when `current_group_role in [:owner, :admin]`
- [ ] 4.4 Add a "Locations" link inside the collapsible section pointing to `/g/:group_slug/settings/locations`

## 5. Locations Index LiveView

- [ ] 5.1 Create `lib/tennis_tracker_web/live/settings/locations/index_live.ex`
- [ ] 5.2 In `mount/3`, verify `current_group_role in [:owner, :admin]`; redirect to group home if not
- [ ] 5.3 In `mount/3`, load active locations via `Tennis.list_locations!` into stream `:active_locations` and archived locations via `Tennis.list_archived_locations!` into stream `:archived_locations`
- [ ] 5.4 Track the selected tab via a `@tab` assign (`:active` | `:archived`); default to `:active`
- [ ] 5.5 Handle `"switch_tab"` event to update `@tab`
- [ ] 5.6 Render Active tab: locations list with Edit and Archive buttons; empty state with create prompt when list is empty
- [ ] 5.7 Render Archived tab: locations list with Restore button; empty state when list is empty
- [ ] 5.8 Add confirmation modal inline in the template; track pending action with `@confirm_action` and `@confirm_location_id` assigns
- [ ] 5.9 Handle `"request_archive"` event: set `@confirm_action` and `@confirm_location_id`, show modal
- [ ] 5.10 Handle `"request_restore"` event: set `@confirm_action` and `@confirm_location_id`, show modal
- [ ] 5.11 Handle `"confirm_action"` event: call `Tennis.archive_location!` or `Tennis.unarchive_location!`; update both streams (remove from one, add to other); clear modal state
- [ ] 5.12 Handle `"cancel_action"` event: clear `@confirm_action` and `@confirm_location_id`

## 6. Locations Form LiveView

- [ ] 6.1 Create `lib/tennis_tracker_web/live/settings/locations/form_live.ex`
- [ ] 6.2 In `mount/3`, verify `current_group_role in [:owner, :admin]`; redirect to group home if not
- [ ] 6.3 For `:new` live action, initialize form with `AshPhoenix.Form.for_create(Location, :create, ...)`
- [ ] 6.4 For `:edit` live action, load the location via `Tennis.get_location!(id, tenant: ..., actor: ...)` and initialize form with `AshPhoenix.Form.for_update(location, :update, ...)`
- [ ] 6.5 Render form with fields: name (required), address (required), google_maps_url (optional)
- [ ] 6.6 Handle `"validate"` event: call `AshPhoenix.Form.validate/2` and assign updated form
- [ ] 6.7 Handle `"save"` event: call `AshPhoenix.Form.submit/2`; on success redirect to index with flash; on error re-render form with errors

## 7. Testing

- [ ] 7.1 Add tests for `Location` archive/unarchive actions (unit-level resource tests)
- [ ] 7.2 Add tests verifying `list_locations!` excludes archived locations
- [ ] 7.3 **VERIFY FIRST**: Write a test that archives a location, then loads a match whose `location_id` points to that archived location, and asserts the location relationship is populated. If this test fails, AshArchival is filtering relationship loads and a mitigation is needed before proceeding with the rest of the implementation.
- [ ] 7.4 Add LiveView tests for `Settings.Locations.IndexLive`: list rendering, archive confirmation flow, restore confirmation flow
- [ ] 7.5 Add LiveView tests for `Settings.Locations.FormLive`: create success, create duplicate error, edit success
- [ ] 7.6 Add LiveView tests verifying non-owners are redirected from settings routes

## 8. Verification

- [ ] 8.1 Run `mix precommit` (compile with warnings-as-errors, format, full test suite)
- [ ] 8.2 Manually verify archived locations no longer appear in the match create/edit location dropdown
- [ ] 8.3 Manually verify the "Group Settings" nav section appears for owners and is absent for members
