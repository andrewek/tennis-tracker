# Todos & Open Questions

In no particular order. Crossed out when done.

1. Configure with ngrok so we can demonstrate locally without needing to deploy
1. When I update a player (name, age group, NTRP rating), that change should
   propagate across all pages that would have that player visible (e.g., the
   roster planner, team show page, etc.). This might mean that a player will
   appear or disappear from dynamically applied filters.
1. Figure out how to actually use Tidewave; what's the point of entry? What
   tasks can it do? Do I need to install an MCP/ACP for my Claude Code session
   to be able to interact with it, or do I have to _just_ interact with it in the
   browser?
1. A corresponding auth story is something like "Only members of the team can
   see the lineups"
1. I'd also like to get the AshAI plugin working
1. It's likely that we'll need some notion of "Organization"
1. Re-architect the PubSub structure into something more elegant. Currently the
   roster planner subscribes to a context-level topic (`roster:team_type_id:season_year`)
   which works for the planner but doesn't extend cleanly to other views (e.g., the
   team show page). We need a design that lets any view subscribe to relevant
   roster/player changes without coupling everything to the planner's topic shape.
1. ~We should start thinking about team match schedules.~
1. Match scheduling: reconsider the upcoming/past split strategy. Currently we
   compare `match_date` to today-in-the-match's-timezone. A more robust model
   would be an explicit `completed` boolean (or `status` enum) set by the captain,
   since tennis matches don't always end on the scheduled date and implicit
   time-based completion can be surprising.
1. Allow "archiving" a Location rather than deleting it, so historical matches
   that reference it remain valid. Deleting a location with associated matches
   should be prevented at the DB level.
1. There should be an easy way to "copy" a previous year's team into this
   year's team for a given season.
1. What makes sense in terms of lineup scheduling? We have slightly different
   use cases for various USTA matches, and a different use case for something
   like Winter Tennis.
1. Team update page: update the team name, update the team's default timezone,
   and delete the team. (Currently deletion is only possible via the roster
   planner board; name editing also only lives there.)
1. A team can be marked as archived, which would keep it from showing up in
   the /teams list by default. There will still be a way to see archived teams.
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

## Done

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
