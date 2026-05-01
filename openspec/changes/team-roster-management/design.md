## Context

TeamMembership records are currently created and updated exclusively via the roster planner tool, which is designed for season-wide drag-and-drop planning by group owners. Captains who need to make mid-season adjustments (adding a late-joining player, removing someone who can no longer play) have no self-service path without involving an owner. The team settings page already has a tabbed layout (General, Match Schedule, Lineup Settings, Members); this change adds a Roster tab as the fifth tab.

Currently, all TeamMembership records are implicitly "playing" — there is no way to mark a member as non-playing (e.g., an over-rated captain who registers the team but does not participate in matches). The lineup's available-player pool comes directly from `list_memberships_for_team`, which today returns all members.

## Goals / Non-Goals

**Goals:**
- Allow team captains (and group owners) to add and remove players from a team's roster from the team settings page.
- Add a `membership_type` attribute to TeamMembership (`:playing` | `:non_playing`) so non-registering captains can be tracked on the roster without polluting the lineup pool.
- Surface eligibility (allowed NTRP levels) and on-level percentage health information inline when adding a player, as non-blocking warnings.
- Exclude non-playing members from lineup available-player pools and on-level percentage calculations.

**Non-Goals:**
- Changing how the roster planner assigns players (it continues to upsert via the existing `:create` / `:update` actions with owner-only authorization).
- Building a search/filter UI for the player selection list (all group players are shown; filtering is out of scope for v1).
- Enforcing eligibility at the data layer (warnings are UI-only, as in the roster planner).
- Showing the Roster tab to users who are neither a team captain nor a group owner.

## Decisions

### 1. New focused actions rather than broadening existing policies

Introduce two new scoped actions on TeamMembership: `:add_to_roster` (create-type) and `:remove_from_roster` (destroy-type). This keeps the existing `:create` and `:destroy` actions' owner-only policies intact (used by the roster planner and admin panel), while giving the new actions their own policy: `IsTeamCaptain OR IsGroupOwner`.

**Alternative considered:** Widen the existing create/destroy policy to include captains. Rejected because the roster planner and admin panel create/destroy paths carry different intent and we want to keep authorization granular per CLAUDE.md convention.

### 2. `membership_type` as an attribute on TeamMembership, not a separate record

Add a `:membership_type` attribute (Ash atom enum: `:playing` | `:non_playing`, default `:playing`) directly to the TeamMembership resource. All existing records are `:playing` by default; the migration is safe with a non-null default.

**Alternative considered:** A separate `NonPlayingMembership` resource or a boolean `is_non_playing` flag. Rejected: the enum is more expressive and leaves room for future types (e.g., `:pending`) without schema changes. An attribute on the existing table keeps queries simple.

### 3. Lineup available-player filter change

The `list_memberships_for_team` / `:for_team` read action in TeamMembership must be updated to filter `membership_type == :playing`. The lineup edit LiveView (`lineup_edit_live.ex:200`) calls `Tennis.list_memberships_for_team!` to build its available-player pool — after this filter, non-playing members will not appear as available.

All existing records will have `membership_type: :playing` due to the migration default, so existing lineups are unaffected.

### 4. Eligibility and on-level percentage as informational UI, not data-layer constraints

Eligibility checks (player's NTRP level is not in the team type's `allowed_ntrp_levels`) and on-level percentage impact are computed in the LiveView at add-time and rendered as inline warnings. No Ash validation prevents the add. This mirrors the roster planner's approach to health indicators.

The Roster tab LiveView will load `team.team_type.allowed_ntrp_levels`, `team.team_type.ntrp_level`, and the current membership list (with player NTRP levels) to compute:
- Whether the candidate player's NTRP level is in `allowed_ntrp_levels`
- Current on-level percentage and projected on-level percentage after adding the candidate (playing members only)

### 5. Remove-player guard at the action level

The `:remove_from_roster` action on TeamMembership validates that the player is not assigned to any match lineup for this team before destroying. This check is an Ash action-level validation (not just UI), so the data layer also enforces it.

**Alternative considered:** UI-only guard (disable the button). Rejected: the data layer guard prevents race conditions and provides a true constraint regardless of how the action is called.

### 6. Roster tab authorization: captain or owner

Authorization for the Roster tab LiveView mirrors the existing Members tab pattern: `mount/3` loads team and checks `Ash.can?`. Users who are neither a team captain nor a group owner are redirected to the team show page with a flash error.

## Risks / Trade-offs

- **`for_team` filter change affects lineup**: Updating `:for_team` to filter out non-playing members is a behavior change in a read action used by the lineup editor. Thorough regression testing on the lineup flow is needed. If a non-playing member was somehow added via the old path (currently not possible), their player card would disappear from the lineup's available pool after the migration.

- **Eligibility logic duplication**: The roster planner health-check logic (NTRP level validation against `allowed_ntrp_levels`) is duplicated in the new Roster tab LiveView. This is acceptable for v1 but should be consolidated into a shared module if a third caller appears.

- **Uniqueness identity**: TeamMembership has a unique identity on `(player_id, team_type_id, season_year)`. If a player is already on the pseudo-team ("Not Participating") for this context, an attempt to add them to a real team from the Roster tab will fail with a uniqueness error. The UI must handle this gracefully with an inline error message.

## Migration Plan

1. Generate a migration to add `membership_type` (atom, not-null, default `:playing`) to `team_memberships`.
2. Run `mix ecto.migrate` in development; include in the deployment migration run.
3. No data backfill needed — the default covers all existing rows.
4. Rollback: remove the column (no data loss because it was additive).
