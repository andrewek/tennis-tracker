## Requirements

### Requirement: Match resource stores team schedule entries

The system SHALL provide a `Match` Ash resource with the following attributes:
- `match_date` (`:date`, non-nullable) — the calendar date of the match
- `match_time` (`:time`, non-nullable) — the local start time of the match
- `timezone` (`:string`, non-nullable, default `"America/Chicago"`) — IANA timezone for the match
- `duration_minutes` (`:integer`, non-nullable, default `90`) — expected duration; used for calendar export. SHALL be editable by users in a future scope.
- `opponent` (`:string`, non-nullable) — name of the opposing team
- `home_or_away` (`HomeOrAway` Ash enum, non-nullable, values `[:home, :away]`) — whether the team plays at home or away
- `location_id` (belongs_to `Location`, nullable) — nil when the venue is not yet known or is a non-standard location

A `Match` SHALL belong to exactly one `Team`. A `Team` SHALL have many `Match` records.

#### Scenario: Match has all required fields
- **WHEN** a match is created with date, time, timezone, opponent, home_or_away, and team
- **THEN** the match is saved successfully

#### Scenario: Match can be created without a location
- **WHEN** a match is created without a location
- **THEN** the match is saved successfully with a nil `location_id`

#### Scenario: Match with missing required field is rejected
- **WHEN** a match is created without an opponent
- **THEN** an error is returned and the match is not saved

### Requirement: Matches can be created for a team
The system SHALL expose a `create_match/1` domain function (via `AshPhoenix.Form`) that creates a match associated with a team. Only users with a `TeamRole.role == :captain` for the team, a `GroupMembership.role == :owner` for the group, or system admin role SHALL be permitted to create matches.

#### Scenario: Team captain creates a match for their team
- **WHEN** a user with TeamRole :captain for Team A submits a valid match creation form for Team A
- **THEN** a new Match record is created associated with Team A

#### Scenario: Group member without captain role cannot create a match
- **WHEN** a user with GroupMembership :member and no TeamRole :captain attempts to create a match
- **THEN** the action is denied

#### Scenario: Group owner can create a match for any team
- **WHEN** a user with GroupMembership :owner creates a match for any team in the group
- **THEN** the match is created successfully

#### Scenario: Invalid match creation is rejected
- **WHEN** an authorized user submits a match creation form with missing required fields
- **THEN** form errors are displayed and no match is created

### Requirement: Matches can be updated and deleted only by authorized users
Updating or deleting a `Match` record SHALL require the acting user to hold a `TeamRole.role == :captain` for the match's team, or a `GroupMembership.role == :owner`, or system admin role.

#### Scenario: Captain can update a match for their team
- **WHEN** a user with TeamRole :captain for Team A updates a match belonging to Team A
- **THEN** the match is updated successfully

#### Scenario: Captain cannot update a match for another team
- **WHEN** a user with TeamRole :captain only for Team A attempts to update a match belonging to Team B
- **THEN** the action is denied

### Requirement: Matches are retrievable split into upcoming and past

The system SHALL expose domain functions that return a team's matches split into:
- Upcoming: `match_date >= today in the match's local timezone`, sorted ascending by date then time
- Past: `match_date < today in the match's local timezone`, sorted descending by date then time (most recent first)

Both queries SHALL be performed at the database level. "Today" SHALL be computed in the match's stored IANA timezone.

#### Scenario: Upcoming matches query returns only future matches sorted ascending
- **WHEN** a team has matches on multiple dates including dates before and after today (in the match timezone)
- **THEN** `Tennis.list_upcoming_matches_for_team!/1` returns only matches with `match_date >= today`, ordered earliest first

#### Scenario: Past matches query returns only past matches sorted descending
- **WHEN** a team has matches on multiple dates including dates before today (in the match timezone)
- **THEN** `Tennis.list_past_matches_for_team!/1` returns only matches with `match_date < today`, ordered most-recent first

### Requirement: Match show page displays full match details
The system SHALL provide a page at `/g/:group_slug/matches/:id` that displays all details for a single match: team name, date, time (formatted in the match's local timezone), opponent, home/away status, location name, and location address. If a `google_maps_url` is present on the location, it SHALL be rendered as a clickable link. If no location is set, the location section SHALL show a placeholder (e.g. "Location TBD").

#### Scenario: User views match detail page
- **WHEN** an authenticated user navigates to `/g/:group_slug/matches/:id`
- **THEN** the page displays the match date, time, opponent, home/away status, location name, and address

#### Scenario: Location has a Google Maps URL
- **WHEN** the match's location has a `google_maps_url`
- **THEN** the page displays a clickable link to that URL

#### Scenario: Location has no Google Maps URL
- **WHEN** the match's location has no `google_maps_url`
- **THEN** no map link is displayed (no broken link, no error)

#### Scenario: Match has no location
- **WHEN** the match has no associated location
- **THEN** the location section displays a placeholder (e.g. "Location TBD")

#### Scenario: Non-existent match ID is requested
- **WHEN** a user navigates to `/matches/:id` where no match with that ID exists
- **THEN** the user is redirected to `/`
- **THEN** a flash error message is displayed

### Requirement: Match show page is accessible at a group-scoped URL
The match show page SHALL be accessible at `/g/:group_slug/matches/:id`. The back-link to the team SHALL navigate to `/g/:group_slug/teams/:team_id`.

#### Scenario: User views match detail at group-scoped URL
- **WHEN** an authenticated group member navigates to `/g/:group_slug/matches/:id`
- **THEN** the match detail page is displayed

#### Scenario: Back-link navigates to group-scoped team page
- **WHEN** a user is on the match show page
- **THEN** the team back-link points to `/g/:group_slug/teams/:team_id`
