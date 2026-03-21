## Context

The `Location` resource exists and is already used by the match form dropdown, but it is only manageable via the admin panel or seed scripts. Group owners need a self-service UI.

The resource currently has a `create` action with upsert behavior and no `update` or `destroy` action. Soft-delete (`archived_at`) is flagged as future scope in the existing locations spec. `AshArchival` is not yet a dependency.

The sidebar nav is a flat daisyUI `<ul class="menu">` with no concept of grouped/collapsible sections. The "Group Settings" section will be the first such grouping.

## Goals / Non-Goals

**Goals:**
- Group owners can create, edit, archive, and restore locations without admin access
- Archived locations are automatically excluded from the match form dropdown
- "Group Settings" nav section provides a home for future owner-only configuration
- Soft-delete pattern is established via `AshArchival` for reuse by future resources

**Non-Goals:**
- Default match location per team (deferred)
- Managing group members or other group settings (future settings items)
- Hard-delete of locations

## Decisions

### Decision: AshArchival over manual archived_at

**Chosen**: Add `ash_archival` to `mix.exs` and use the `AshArchival.Resource` extension.

**Why over manual**: AshArchival automatically filters archived records from all read actions, generates `:archive` and `:unarchive` actions, and is idiomatic Ash. Manual implementation would duplicate this logic and diverge from the pattern as other resources adopt soft-delete.

**Trade-off**: New dependency. Acceptable given stated intent to use it for future resources.

### Decision: Remove upsert from Location create

**Chosen**: Plain `create :create` with no `upsert?`, `upsert_identity`, or `upsert_fields`.

**Why**: The upsert silently overwrites `address` and `google_maps_url` when a duplicate name is submitted. A management UI should give the user a validation error instead. The seeds.exs already uses its own check-before-insert helper and does not rely on the resource's upsert behavior — confirmed by reading the file.

### Decision: Confirmation modal for archive and restore

**Chosen**: Inline modal in `Settings.Locations.IndexLive`, toggled via LiveView assigns (`@confirm_action`, `@confirm_location`). No separate LiveView or JS hook needed.

**Why**: Both operations affect what group members see on the match form, so a confirmation step prevents accidental changes. Keeping the modal state in socket assigns is idiomatic LiveView and avoids JS complexity.

### Decision: Archived locations shown in separate tab

**Chosen**: Two tabs on the index page — "Active" and "Archived". Active tab shows locations with Edit/Archive controls. Archived tab shows archived locations with a Restore control.

**Why**: AshArchival requires a different query mechanism to include archived records (setting query context vs. the default filtered read). Having separate tabs maps cleanly to separate queries and separate streams, rather than combining two fundamentally different fetch operations into one view. It also scales better as the archived list grows.

### Decision: Policy coverage for :archive and :unarchive

AshArchival's `:archive` and `:unarchive` actions are update-type actions. The existing `policy action_type([:update, :destroy])` policy on `Location` will cover them automatically. No new policy blocks needed.

### Decision: Group Settings nav — owner and system admin visibility

The "Group Settings" collapsible section is rendered when `current_group_role in [:owner, :admin]`. System admins get `current_group_role: :admin` from `GroupMountHook`, so the check must include both values.

`GroupMountHook` already assigns `current_group_role` to the socket. However, `Layouts.app` currently has no `current_group_role` attr — it only receives `current_user` and `current_group`. To make the role available in the sidebar, `Layouts.app` needs a new `attr :current_group_role, :atom, default: nil`, and all ~10 group-scoped LiveView templates must pass `current_group_role={@current_group_role}`.

Non-owners/non-admins who navigate directly to `/g/:slug/settings/*` are redirected to the group home page in `mount/3`.

### Decision: URL structure

`/g/:group_slug/settings/locations` — nested under `/settings/` to establish a namespace for future group settings pages. All settings routes share the existing `:group_scoped_routes` `ash_authentication_live_session` block.

## Risks / Trade-offs

**AshArchival filters all reads — relationship load behavior unverified** → It is not confirmed whether AshArchival's filter applies when Ash loads a `belongs_to` relationship (e.g., loading `match.location` where the location is archived). If it does apply, matches would silently appear to have no location. This must be verified with an explicit test early in implementation (task 7.3). If AshArchival does filter relationship loads, a mitigation will be needed (e.g., a bypass read action on Location used only for relationship loading, or AshArchival config to exclude relationship loads).

**Seeds rely on create action** → Confirmed the seeds.exs `upsert_location` helper does its own check-before-insert query and does not rely on `upsert?` in the resource. No seeds change needed.

**list_locations action used by match form** → AshArchival wraps all read actions. `list_locations` will automatically exclude archived locations. No changes needed to the match form.

## Migration Plan

1. Add `{:ash_archival, "~> 1.0"}` to `mix.exs` and run `mix deps.get`
2. Update `Location` resource (extension, actions)
3. Run `mix ash_postgres.generate_migrations --name add_location_archived_at`
4. Run `mix ecto.migrate`
5. Deploy web layer changes (nav, router, LiveViews)

Rollback: The `archived_at` column is nullable; removing the extension and migrating the column back is safe. No data loss risk.

## Open Questions

None — all decisions resolved during exploration.
