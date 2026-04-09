## Why

Group admins currently have no UI for assigning team captains — it requires direct admin panel access. Captains need to be assigned so they can manage lineups and matches for their teams without requiring the group admin to do everything.

## What Changes

- **Optional `name` field on `User`**: Adds a human-readable display name so captains can be identified by name (falling back to email) when listed or selected.
- **TeamRole policy expansion**: Extends read access to all group members (so they can see who captains a team), and extends create/update/destroy to team captains acting on their own team (currently limited to group owners only).
- **Captains section on team edit page**: Inline UI for listing current captains, adding new ones from a group member picker, and removing/converting captains via a three-option confirmation modal.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `user-auth`: Add optional `name` attribute to User (string, nullable, no uniqueness constraint). Display name falls back to email when nil.
- `group-model`: Extend `GroupMembership` read policy to allow any group member to read all membership records for their group (required to populate the captain picker).
- `team-role`: Expand read policy to any group member. Expand create/update/destroy to team captains acting on their own team's TeamRole records.
- `team-edit-page`: Add a Captains section — lists current captains with remove controls, inline select for adding new captains from group members not already :captain on this team, and a three-option confirmation modal on remove (Remove entirely / Convert to Member / Cancel).
- `team-show-page`: Add a read-only Captains section visible to all group members — lists current captains by display name with no add/remove controls.

## Impact

- `TennisTracker.Accounts.User` — new `:name` attribute, migration required
- `TennisTracker.Tennis.TeamRole` — policy changes only, no schema changes
- `TennisTrackerWeb.Teams.EditLive` — new Captains section, new modal, new event handlers
- `TennisTrackerWeb.Teams.ShowLive` — new read-only Captains section
- `TennisTracker.Tennis` domain — may need new `define` entries for TeamRole updates and group member listing
- `TennisTracker.Groups` domain — may need a domain function to list group members (Users) for the picker
