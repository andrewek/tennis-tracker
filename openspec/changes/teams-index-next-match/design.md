## Context

The teams index LiveView currently loads teams via `Tennis.list_real_teams!` and streams them. Each card has a hardcoded "Next match: TBD" line. The `Match` resource and `list_upcoming_matches_for_team` action now exist. The goal is to show the actual next match date/time on each card with minimal overhead.

## Goals / Non-Goals

**Goals:**
- Show the earliest upcoming match date and time on each team card
- Fall back to "Next match: TBD" when a team has no upcoming matches
- Keep the index page load performant

**Non-Goals:**
- Linking from the card directly to the match show page (the card already links to the team)
- Showing opponent or location on the index card (too much detail for a card)
- Real-time updates when a new match is created

## Decisions

### 1. Load next match via a new `next_upcoming_match_for_team` read action that returns at most one record

**Rationale:** We only need the single earliest upcoming match per team. A dedicated read action with `limit: 1` sorted ascending is efficient. Alternatively, we could add a calculation on Team that computes this via an aggregation, but a simple query per team is straightforward and avoids complexity.

**Approach:** Add a `next_upcoming_match_for_team` read action on `Match` (same filter as `list_upcoming_matches_for_team` but with `limit(1)`) and expose it as `get_next_upcoming_match_for_team` in the domain. In the LiveView, load it for each team after fetching the team list.

### 2. Load next matches in the LiveView, stored as a map keyed by team ID

**Rationale:** Streams are not enumerable, so we can't join data after the fact. Instead, before streaming teams, we load the next match for each team and store them in a plain `%{team_id => match_or_nil}` assign. The template looks up `@next_matches[team.id]` per card.

**Alternatives considered:**
- Ash aggregate / calculation on Team: would require a new calculation and possibly a subquery; more complexity than warranted for a simple card field.
- Load inside stream: streams don't support per-item enrichment at render time.

### 3. Date/time format: "Mon, Apr 7 · 10:00 AM"

**Rationale:** Matches the format already used on the team show page, keeping display consistent. Concise enough for a card.
