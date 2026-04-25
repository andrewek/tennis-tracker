# Todos & Open Questions

## Phase 1: Production Launch

These are the things we need to do to get to a usable, deployable product.

### Deploy
1. Deploy to Fly.io (including CI/CD pipeline, environment config, secrets management).
1. Configure with ngrok or similar for local demos before deployment is ready.

### Group Management
1. Group owners need UI pages to create, edit, and update SeasonRules records
   (currently only accessible via AshAdmin). Build `/:group_slug/seasons`
   index and create/edit forms.
1. Explore adding a group-settings UI entrypoint for seeding a group's preset tag
   taxonomy (currently only accessible via AshAdmin or `iex` shell). See the
   `seed_preset_tags!/1` domain function; consider surfacing it in a "Group Setup"
   or "Tags" settings page so admins don't need shell access for new groups.

### Team Management
1. Make it easier to add a player to a team mid-season. Currently this requires
   going through the roster planner flow; there should be a direct "add player"
   action on the team show page for captains and group owners.
1. There should be an easy way to "copy" a previous year's team into this year's
   team for a given season, so captains don't have to rebuild rosters from scratch.
1. A team can be marked as archived, which would keep it from showing up in the
   `/teams` list by default. There will still be a way to see archived teams.
1. We'll need some way to "finalize" a planning session. Then teams are effectively
   locked in. There will still need to be some mechanism to add a player mid-season,
   but the planning tool is really just meant for easy roster collaboration in the
   pre-season.

### Player Pages
1. On the player show page, show upcoming matches and recorded outs/unavailabilities
   across all teams within the group where that player is a member.

### Group Home Page
1. The `/g/:group_slug` group home page is currently a placeholder. Replace it with
   something more useful — ideas include: active roster planning sessions, the next
   few upcoming matches, and perhaps an activity feed.

### UI Coherence
1. Rework the Roster Planner page structure. Currently it acts as both an index
   (selecting a planning context) and a show/board page in one LiveView. Split
   this into a conventional index page (list/create planning contexts) and a
   separate board/show page, so both conform to the standard page structure used
   by the rest of the app (sidenav layout + `<.page_header>` with back link).
1. When a player is updated (name, age group, NTRP rating), that change should
   propagate across all pages that would have that player visible (e.g., the
   roster planner, team show page, etc.). This might mean a player will appear
   or disappear from dynamically applied filters.
1. Re-architect the PubSub structure into something more elegant. Currently the
   roster planner subscribes to a context-level topic (`roster:team_type_id:season_year`)
   which works for the planner but doesn't extend cleanly to other views (e.g., the
   team show page). We need a design that lets any view subscribe to relevant
   roster/player changes without coupling everything to the planner's topic shape.

### Permissions & Authorization
1. Lineup visibility: lineups should be visible only to captains and `:member`
   TeamRole holders for that specific team. Consider a per-team toggle: "lineups
   visible to all group members" vs. "lineups visible only to team participants."
1. Match scheduling: reconsider the upcoming/past split strategy. Currently we
   compare `match_date` to today-in-the-match's-timezone. A more robust model
   would be an explicit `completed` boolean (or `status` enum) set by the captain,
   since tennis matches don't always end on the scheduled date and implicit
   time-based completion can be surprising.

---

## Phase 2: Player Accounts & Self-Service

These features require connecting Player records to User accounts. Nothing here
should be built until the Player ↔ User link is in place.

1. Connect Player records to User accounts. A Player record should optionally link
   to a User — starting with an "invite to group" button on the player show page if
   the player already has an account.
1. Generate a unique invitation link that prompts a player to set up an account and
   automatically links them to their existing Player record. Ideally handles
   de-duplication and supports "hey, go update your info" emails to existing players
   who don't have accounts yet.
1. Explore merging TeamRole (User → Team) and TeamMembership (Player → Team) once
   Player records can optionally link to User accounts. Today these are parallel
   tracks; eventually a player with an account should derive their team access from
   their TeamMembership rather than needing a separate TeamRole record.
1. Once players have accounts, give them a home screen showing their upcoming
   matches across all teams they're on.
1. Let players proactively mark themselves as unavailable from their own account,
   instead of having to reach out to the captain.
1. Text/email players a link — "You're scheduled to play on 2026-10-01, 6:30p,
   Woods Tennis Center. Click this link to indicate whether you will be there or
   not." This works even without a full account.
1. Build an "Assume User Identity" feature for system admins, allowing them to
   impersonate any user account for debugging and support purposes.

---

## Phase 3: Non-USTA Leagues & Auto-Scheduling

These features are further out but represent the next major product expansion.

1. Support non-USTA league formats. Example: a 24-week winter league where players
   buy in and play in roughly 16 matches. SeasonRules would need to accommodate
   these formats (round-robin, buy-in tracking, etc.).
1. Add Mixed Doubles as a supported league type in SeasonRules (e.g., a
   `league_gender` or `format` field on TeamType or SeasonRules). Once this exists,
   update the "Mixed" seed group with appropriate TeamTypes, teams, and SeasonRules.
1. Player-managed availability: once players have accounts, let them manage their
   own availability calendar rather than relying on captains to track it.
1. Auto-scheduling: given player availability and group/season configuration,
   automatically generate a match schedule. Support placeholders for subs and
   "celebrity guests" in a way that respects availability constraints.
1. I want to be able to scrape the estimated dynamic NTRP from TennisRecord.
   We'll assume `tennis_record_url` is a field we can store, and we'll assume
   it's durable enough to account for things like two players with the same name.
1. I'd also like to get the AshAI plugin working — probably most relevant once
   we have scheduling and availability data to query against.

---

## Someday / Explore

Lower priority improvements worth tracking but not blocking any phase.

1. Build an archive/soft-delete action for SeasonRules records — currently there is
   no delete action on SeasonRules (to avoid cascading data loss); a future "archived"
   flag would let group owners hide stale season rules without destroying them or their
   associated default-tag configuration.
1. Explore custom display ordering for tag categories and tags. Currently categories
   and tags are displayed in alphabetical ascending order by name. A `position` or
   `display_order` field on TagCategory and Tag would let group owners arrange their
   taxonomy in a preferred sequence. Evaluate whether alphabetical descending is
   sufficient or whether a drag-to-reorder UI is warranted.
1. Explore adding free-text Notes to Player records — useful for narrative context
   that tags cannot capture (e.g. "think she'll be a 3.0", "contact info coming soon").
1. CSV import always creates new players — re-importing to the same group will
   produce duplicates. Explore upsert (match by name or email) as a future improvement.
1. Tags auto-created during CSV import are not rolled back if player inserts later
   fail. Explore transactional tag resolution or a cleanup step as a future improvement.
1. Consider adding a "locked" or "read-only" state to a team (separate from archived)
   that prevents future edits without hiding the team. Needs more exploration: which
   edit operations should be blocked, who can lock/unlock (captains vs. group owners),
   and how this interacts with the season finalization flow.
1. Explore whether we need additional FK integrity constraints across the app —
   particularly for join records that reference resources from different relationships
   (e.g., SeasonRulesDefaultTag references both a SeasonRules and a Tag, which must
   belong to the same group, but this is not enforced at the DB level).
1. Figure out how system admins can gracefully pre-seed new organizations with a
   useful starting dataset (e.g., preset tag taxonomy, team types, season rules).
   For now: use `priv/repo/seeds.exs` for local dev, AshAdmin or `iex` against
   production when needed. Future: consider a "group setup wizard."
