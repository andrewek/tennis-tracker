## Context

TeamMembership records are currently created and updated exclusively via the roster planner tool, which is designed for season-wide drag-and-drop planning by group owners. Captains who need to make mid-season adjustments (adding a late-joining player, removing someone who can no longer play) have no self-service path without involving an owner. The team settings page already has a tabbed layout (General, Match Schedule, Lineup Settings, Members); this change adds a Roster tab as the fifth tab.

All TeamMemberships represent playing members — captains are tracked via User Accounts, not Player records, so there is no need for a "non-playing" membership concept.

## Goals / Non-Goals

**Goals:**
- Allow team captains (and group owners) to add and remove players from a team's roster from the team settings page.
- Surface eligibility (allowed NTRP levels) and on-level percentage health information inline when adding a player, as non-blocking warnings.

**Non-Goals:**
- Changing how the roster planner assigns players (it continues to upsert via the existing `:create` / `:update` actions with owner-only authorization).
- Building a search/filter UI for the player selection list (all group players are shown; filtering is out of scope for v1).
- Enforcing eligibility at the data layer (warnings are UI-only, as in the roster planner).
- Showing the Roster tab to users who are neither a team captain nor a group owner.

## Decisions

### 1. New focused actions rather than broadening existing policies

Introduce two new scoped actions on TeamMembership: `:add_to_roster` (create-type) and `:remove_from_roster` (destroy-type). This keeps the existing `:create` and `:destroy` actions' owner-only policies intact (used by the roster planner and admin panel), while giving the new actions their own policy: `IsTeamCaptain OR IsGroupOwner`.

**Alternative considered:** Widen the existing create/destroy policy to include captains. Rejected because the roster planner and admin panel create/destroy paths carry different intent and we want to keep authorization granular per CLAUDE.md convention.

### 2. Roster tab uses the existing `list_memberships_for_team` / `:for_team` action

The Roster tab LiveView loads members via the existing `Tennis.list_memberships_for_team!/2` domain function. No new read action is needed — `:for_team` already returns the full member list for a team.

### 3. Eligibility and on-level percentage as informational UI, not data-layer constraints

Eligibility checks (player's NTRP level is not in the team type's `allowed_ntrp_levels`) and on-level percentage impact are computed in the LiveView at add-time and rendered as inline warnings. No Ash validation prevents the add. This mirrors the roster planner's approach to health indicators.

The Roster tab LiveView will load `team.team_type.allowed_ntrp_levels`, `team.team_type.ntrp_level`, and the current membership list (with player NTRP levels) to compute:
- Whether the candidate player's NTRP level is in `allowed_ntrp_levels`
- Current on-level percentage and projected on-level percentage after adding the candidate

### 4. Remove-player guard at the action level

The `:remove_from_roster` action on TeamMembership validates that the player is not assigned to any match lineup for this team before destroying. This check is an Ash action-level validation (not just UI), so the data layer also enforces it.

**Alternative considered:** UI-only guard (disable the button). Rejected: the data layer guard prevents race conditions and provides a true constraint regardless of how the action is called.

### 5. Roster tab authorization: captain or owner

Authorization for the Roster tab LiveView mirrors the existing Members tab pattern: `mount/3` loads team and checks `Ash.can?`. Users who are neither a team captain nor a group owner are redirected to the team show page with a flash error.

## Risks / Trade-offs

- **Eligibility logic duplication**: The roster planner health-check logic (NTRP level validation against `allowed_ntrp_levels`) is duplicated in the new Roster tab LiveView. This is acceptable for v1 but should be consolidated into a shared module if a third caller appears.

- **Uniqueness identity**: TeamMembership has a unique identity on `(player_id, team_type_id, season_year)`. If a player is already on the pseudo-team ("Not Participating") for this context, an attempt to add them to a real team from the Roster tab will fail with a uniqueness error. The UI must handle this gracefully with an inline error message.
