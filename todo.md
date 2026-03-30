# Todos & Open Questions

In no particular order. Crossed out when done.

1. Build an archive/soft-delete action for SeasonRules records — currently there is
   no delete action on SeasonRules (to avoid cascading data loss); a future "archived"
   flag would let group owners hide stale season rules without destroying them or their
   associated default-tag configuration.
1. Explore adding a group-settings UI entrypoint for seeding a group's preset tag
   taxonomy (currently only accessible via AshAdmin or `iex` shell). See the
   `seed_preset_tags!/1` domain function; consider surfacing it in a "Group Setup"
   or "Tags" settings page so admins don't need shell access for new groups.
1. Explore custom display ordering for tag categories and tags. Currently categories
   and tags are displayed in alphabetical ascending (A → Z) order by name. A
   `position` or `display_order` field on TagCategory and Tag would let group owners
   arrange their taxonomy in a preferred sequence (e.g., Age Group before Availability,
   "18+" before "40+"). Evaluate whether alphabetical descending is sufficient or
   whether a drag-to-reorder UI is warranted.
1. Add Mixed Doubles as a supported league type in SeasonRules (e.g., a `league_gender`
   or `format` field on TeamType or SeasonRules). Once this exists, update the "Mixed"
   seed group with appropriate TeamTypes, teams, and SeasonRules so it demonstrates
   mixed doubles roster planning alongside the men's and women's league players already
   seeded there.
1. Explore adding free-text Notes to Player records — useful for narrative context
   tags cannot capture (e.g. "think she'll be a 3.0", "contact info coming soon").
1. ~Revisit tags in CSV import/export — tags are currently excluded from CSV; decide
   on format (e.g. pipe-separated values in a single column) and implement.~
1. CSV import always creates new players — re-importing to the same group will
   produce duplicates. Explore upsert (match by name or email) as a future improvement.
1. Tags auto-created during CSV import are not rolled back if player inserts later
   fail. Explore transactional tag resolution or a cleanup step as a future improvement.
1. Configure with ngrok so we can demonstrate locally without needing to deploy
1. When I update a player (name, age group, NTRP rating), that change should
   propagate across all pages that would have that player visible (e.g., the
   roster planner, team show page, etc.). This might mean that a player will
   appear or disappear from dynamically applied filters.
1. A corresponding auth story is something like "Only members of the team can
   see the lineups"
1. I'd also like to get the AshAI plugin working
1. Re-architect the PubSub structure into something more elegant. Currently the
   roster planner subscribes to a context-level topic (`roster:team_type_id:season_year`)
   which works for the planner but doesn't extend cleanly to other views (e.g., the
   team show page). We need a design that lets any view subscribe to relevant
   roster/player changes without coupling everything to the planner's topic shape.
1. Match scheduling: reconsider the upcoming/past split strategy. Currently we
   compare `match_date` to today-in-the-match's-timezone. A more robust model
   would be an explicit `completed` boolean (or `status` enum) set by the captain,
   since tennis matches don't always end on the scheduled date and implicit
   time-based completion can be surprising.
1. Group owners need UI pages to create, edit, and update SeasonRules records
   (currently only accessible via AshAdmin). Build `/:group_slug/seasons`
   index and create/edit forms.
1. There should be an easy way to "copy" a previous year's team into this
   year's team for a given season.
1. What makes sense in terms of lineup scheduling? We have slightly different
   use cases for various USTA matches, and a different use case for something
   like Winter Tennis.
1. A team can be marked as archived, which would keep it from showing up in
   the /teams list by default. There will still be a way to see archived teams.
1. Explore merging TeamRole (User → Team) and TeamMembership (Player → Team)
   once Player records can optionally link to User accounts. Today these are
   parallel tracks; eventually a player with an account should be able to derive
   their team access from their TeamMembership rather than needing a separate
   TeamRole record. Consider what "merge" actually means: a unified participation
   record, or just an authorization policy that checks both paths.
1. Consider adding a "locked" or "read-only" state to a team (separate from
   archived) that prevents future edits without hiding the team. Needs more
   exploration: which edit operations should be blocked, who can lock/unlock
   (captains vs. group owners), and how this interacts with the season
   finalization flow.
1. Consider team-level settings for lineup visibility. Current plan: lineups
   are visible only to captains and :member TeamRole holders for that specific
   team. A future option would be a per-team toggle: "lineups visible to all
   group members" vs. "lineups visible only to team participants."
1. Build an "Assume User Identity" feature for system admins, allowing them
   to impersonate any user account for debugging and support purposes.
1. At some point we need to figure out how to deploy. We also probably need a
   CI/CD pipeline. At this time I am leaning toward Fly.io.
1. We'll need some way to basically "finalize" a planning session. Then teams
   are effectively locked in. There will still need to be some mechanism to add
   a player mid-season, but the planning tool is really just meant for easy roster
   collaboration in the pre-season.
1. I want to be able to scrape the estimated dynamic NTRP from TennisRecord.
   We'll assume here that "tennis_record_url` is a field we can store, and
   we'll also assume that it's durable enough to account for things like two
   players with the same name.
1. Assuming we have a notion of an `Organization`, I would like there to be an
   easy link that I (as a group administrator) could send to new players so
   they can easily fill in their information and get added to the player pool for
   that organization. It'd be even better if it handled de-duplication, and if it
   let us also send "Hey, go update your stuff!" emails (without needing to create
   an account) to existing players.
1. The `/g/:group_slug` group home page is currently a placeholder. Replace it
   with something more useful — ideas include: active roster planning sessions,
   the next few upcoming matches, and perhaps an activity feed.
1. Explore whether we need additional FK integrity constraints across the app —
   particularly for join records that reference resources from different
   relationships (e.g., SeasonRulesDefaultTag references both a SeasonRules and
   a Tag, which must belong to the same group, but this is not enforced at the
   DB level). Audit foreign keys broadly and decide where cross-group or
   cross-resource integrity constraints are actually needed.
1. Figure out how system admins can gracefully pre-seed new organizations with a
   useful starting dataset (e.g., preset tag taxonomy, team types, season rules).
   For now: use `priv/repo/seeds.exs` for local dev, AshAdmin dashboard or an
   `iex` shell against production when needed. Future: consider a "group setup
   wizard" or an admin-triggered seed action so this doesn't require shell access.
1. Rework the Roster Planner page structure. Currently it acts as both an index
   (selecting a planning context) and a show/board page in one LiveView. Split
   this into a conventional index page (list/create planning contexts) and a
   separate board/show page, so both conform to the standard page structure used
   by the rest of the app (sidenav layout + `<.page_header>` with back link).

## Done

1. ~It's likely that we'll need some notion of "Organization" / Groups — implemented
   as the Group model with slug-based routing and full multitenancy via group_id
   tenant scoping across all Tennis domain resources.~
1. ~It's hard to drag/drop when the available players list is very long. Let's
   make the team lists capped to screen height and scrollable.~
1. ~On the player show page, show all team memberships for that player~
1. ~On the roster planner page, when clicking a player, provide a link (that
   opens in a new tab) to that player's show page.~
1. ~Install the Usage Rules package and configure it properly~
1. ~Build out the Teams index and show pages. We'll use Ash calculations and
   aggregates to display data.~
1. ~I'd like to get AshAdmin working~
1. ~We need user accounts and some basic authentication / authorization. Along
   with this, we'll need to add an email client of some sort for things like
   password resets.~
1. ~Introduce a test factory (e.g. ExMachina) to replace the repetitive inline
   fixture helpers (`create_team_type`, `create_team`, `create_player`, etc.)
   that are duplicated across test files.~
1. ~We should start thinking about team match schedules.~
1. ~It's likely that we'll need some notion of "Organization"~
1. ~Team update page: update the team name, update the team's default timezone,
   and delete the team. (Currently deletion is only possible via the roster
   planner board; name editing also only lives there.)~
1. ~Rework the site layout from the current top-nav to a sidenav. As part of
   this, extract common layout pieces (group nav links, back-links, page header
   wrapper) into reusable components so individual LiveViews stay thin.~
1. ~Figure out how to actually use Tidewave; what's the point of entry? What
   tasks can it do? Do I need to install an MCP/ACP for my Claude Code session
   to be able to interact with it, or do I have to _just_ interact with it in the
   browser?~
1. ~Group owners need UI pages to create, edit, and update Location records
   (currently only accessible via AshAdmin). Build `/:group_slug/locations`
   index and `/:group_slug/locations/new` / `/:group_slug/locations/:id/edit`
   pages.~
1. ~Build better seed data given the new multi-tenancy setup: create at least one
   Group with realistic team types, teams, players, and matches so the app is
   immediately explorable after `mix ecto.reset`.~
