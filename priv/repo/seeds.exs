# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Safe to run multiple times — uses upsert patterns.
# All Ash calls use authorize?: false (seeds run outside request context).

require Ash.Query

alias TennisTracker.{Accounts, Groups, Tennis}
alias TennisTracker.Accounts.User
alias TennisTracker.Groups.{Group, GroupMembership}

alias TennisTracker.Tennis.{
  Player,
  Team,
  TeamType,
  SeasonRules,
  Location,
  TeamMembership,
  TeamRole,
  Match
}

# ==============================================================================
# 10.1 Users
# ==============================================================================

dev_users = [
  %{email: "admin@example.com", password: "Password1!", role: :admin},
  %{email: "smallgroup@example.com", password: "Password1!", role: :member},
  %{email: "bigowner1@example.com", password: "Password1!", role: :member},
  %{email: "captain@example.com", password: "Password1!", role: :member},
  %{email: "member@example.com", password: "Password1!", role: :member}
]

existing_users =
  User
  |> Ash.Query.new()
  |> Ash.read!(domain: Accounts, authorize?: false)

existing_emails = existing_users |> Enum.map(&to_string(&1.email)) |> MapSet.new()
users_by_email = Map.new(existing_users, &{to_string(&1.email), &1})

users =
  Enum.map(dev_users, fn %{email: email, password: password, role: role} ->
    user =
      if MapSet.member?(existing_emails, email) do
        Map.fetch!(users_by_email, email)
      else
        {:ok, created} =
          Ash.create(
            User,
            %{email: email, password: password, password_confirmation: password},
            action: :register_with_password,
            domain: Accounts,
            authorize?: false
          )

        created
      end

    if user.role != role do
      {:ok, updated} =
        Ash.update(user, %{role: role}, action: :update_role, domain: Accounts, authorize?: false)

      updated
    else
      user
    end
  end)

users_map = Map.new(users, &{to_string(&1.email), &1})
admin_user = Map.fetch!(users_map, "admin@example.com")
smallgroup_user = Map.fetch!(users_map, "smallgroup@example.com")
bigowner1_user = Map.fetch!(users_map, "bigowner1@example.com")
captain_user = Map.fetch!(users_map, "captain@example.com")
member_user = Map.fetch!(users_map, "member@example.com")

IO.puts("Seeded #{length(users)} users.")

# ==============================================================================
# Helper: upsert group by slug
# ==============================================================================

upsert_group = fn name, slug ->
  case Ash.get(Group, %{slug: slug}, domain: Groups, authorize?: false) do
    {:ok, existing} when not is_nil(existing) ->
      existing

    _ ->
      Group
      |> Ash.Changeset.for_create(:create, %{name: name, slug: slug},
        domain: Groups,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

upsert_group_membership = fn group, user, role ->
  existing =
    GroupMembership
    |> Ash.Query.filter(group_id == ^group.id and user_id == ^user.id)
    |> Ash.read_one(domain: Groups, authorize?: false)

  case existing do
    {:ok, %GroupMembership{} = m} ->
      m

    _ ->
      GroupMembership
      |> Ash.Changeset.for_create(:create, %{group_id: group.id, user_id: user.id, role: role},
        domain: Groups,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

# ==============================================================================
# 10.2 Small Group
# ==============================================================================

small_group = upsert_group.("Small Group", "small-group")
upsert_group_membership.(small_group, smallgroup_user, :owner)
IO.puts("Small Group ready (id: #{small_group.id})")

small_tenant = small_group.id

# ==============================================================================
# 10.3 Small Group: TeamTypes & SeasonRules
# ==============================================================================

upsert_team_type = fn attrs, tenant ->
  existing =
    TeamType
    |> Ash.Query.filter(name == ^attrs.name)
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %TeamType{} = tt} ->
      tt

    _ ->
      TeamType
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :group_id, tenant),
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

upsert_season_rules = fn team_type, year, attrs, tenant ->
  existing =
    SeasonRules
    |> Ash.Query.filter(team_type_id == ^team_type.id and season_year == ^year)
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %SeasonRules{}} ->
      :skipped

    _ ->
      SeasonRules
      |> Ash.Changeset.for_create(
        :create,
        Map.merge(attrs, %{team_type_id: team_type.id, season_year: year, group_id: tenant}),
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

small_tt_18_35 =
  upsert_team_type.(
    %{
      name: "18+ 3.5",
      age_group: "18_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    },
    small_tenant
  )

small_tt_40_35 =
  upsert_team_type.(
    %{
      name: "40+ 3.5",
      age_group: "40_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    },
    small_tenant
  )

current_year = Date.utc_today().year
season_rules_defaults = %{min_roster: 10, max_roster: 18, on_level_min_pct: Decimal.new("0.60")}

upsert_season_rules.(small_tt_18_35, current_year, season_rules_defaults, small_tenant)
upsert_season_rules.(small_tt_40_35, current_year, season_rules_defaults, small_tenant)

IO.puts("Small Group: team types and season rules seeded.")

# ==============================================================================
# Helper: upsert location per tenant
# ==============================================================================

upsert_location = fn attrs, tenant ->
  existing =
    Location
    |> Ash.Query.filter(name == ^attrs.name)
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %Location{} = l} ->
      l

    _ ->
      Location
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :group_id, tenant),
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

# ==============================================================================
# Small Group: Locations
# ==============================================================================

small_loc_1 =
  upsert_location.(
    %{
      name: "Elmwood Park Tennis Courts",
      street_address: "602 S 60th St",
      city: "Omaha",
      state: "NE",
      postal_code: "68106",
      google_maps_url: "https://maps.google.com/?q=Elmwood+Park+Tennis+Courts"
    },
    small_tenant
  )

small_loc_2 =
  upsert_location.(
    %{
      name: "Benson Park Tennis Courts",
      street_address: "5625 Maple St",
      city: "Omaha",
      state: "NE",
      postal_code: "68104",
      google_maps_url: nil
    },
    small_tenant
  )

# ==============================================================================
# 10.4 Small Group: ~20 players
# ==============================================================================

small_group_players = [
  # 5 at 3.0 (eligible 18+ and 40+)
  %{
    name: "Alice Hoffman",
    ntrp_rating: "3.0",
    eligible_18_plus: true,
    eligible_40_plus: true,
    eligible_55_plus: false
  },
  %{
    name: "Barbara Klein",
    ntrp_rating: "3.0",
    eligible_18_plus: true,
    eligible_40_plus: true,
    eligible_55_plus: false
  },
  %{
    name: "Carol Manning",
    ntrp_rating: "3.0",
    eligible_18_plus: true,
    eligible_40_plus: true,
    eligible_55_plus: true
  },
  %{
    name: "Diana Nors",
    ntrp_rating: "3.0",
    eligible_18_plus: true,
    eligible_40_plus: true,
    eligible_55_plus: false
  },
  %{
    name: "Ellen Preston",
    ntrp_rating: "3.0",
    eligible_18_plus: false,
    eligible_40_plus: true,
    eligible_55_plus: true
  },
  # 15 at 3.5
  %{
    name: "Faye Quincy",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Grace Randall",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Helen Sutton",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Iris Turner",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: true,
    eligible_55_plus: false
  },
  %{
    name: "Jane Upton",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: true,
    eligible_55_plus: false
  },
  %{
    name: "Karen Vance",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Laura Walsh",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Mary Xander",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Nancy Young",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: true,
    eligible_55_plus: false
  },
  %{
    name: "Olivia Zane",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Paula Abbot",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Quinn Briggs",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: true,
    eligible_55_plus: false
  },
  %{
    name: "Rachel Cole",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Sara Duff",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  },
  %{
    name: "Tina Earl",
    ntrp_rating: "3.5",
    eligible_18_plus: true,
    eligible_40_plus: false,
    eligible_55_plus: false
  }
]

upsert_player = fn attrs, tenant ->
  existing =
    Player
    |> Ash.Query.filter(name == ^attrs.name)
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %Player{} = p} ->
      p

    _ ->
      ntrp = if attrs[:ntrp_rating], do: Decimal.new(attrs.ntrp_rating), else: nil

      Player
      |> Ash.Changeset.for_create(
        :create,
        %{
          name: attrs.name,
          ntrp_rating: ntrp,
          eligible_18_plus: attrs.eligible_18_plus,
          eligible_40_plus: attrs.eligible_40_plus,
          eligible_55_plus: attrs.eligible_55_plus,
          group_id: tenant
        },
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

small_players = Enum.map(small_group_players, &upsert_player.(&1, small_tenant))
IO.puts("Small Group: #{length(small_players)} players seeded.")

# ==============================================================================
# 10.5 Small Group: Teams + TeamRoles
# ==============================================================================

upsert_team = fn attrs, tenant ->
  existing =
    Team
    |> Ash.Query.filter(
      name == ^attrs.name and team_type_id == ^attrs.team_type_id and
        season_year == ^attrs.season_year
    )
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %Team{} = t} ->
      t

    _ ->
      Team
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :group_id, tenant),
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

upsert_team_role = fn user, team, role, tenant ->
  existing =
    TeamRole
    |> Ash.Query.filter(user_id == ^user.id and team_id == ^team.id)
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %TeamRole{}} ->
      :skipped

    _ ->
      TeamRole
      |> Ash.Changeset.for_create(
        :create,
        %{user_id: user.id, team_id: team.id, role: role, group_id: tenant},
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

small_team_18 =
  upsert_team.(
    %{
      name: "Small Group 18+ 3.5",
      team_type_id: small_tt_18_35.id,
      season_year: current_year,
      is_pseudo: false
    },
    small_tenant
  )

small_team_40 =
  upsert_team.(
    %{
      name: "Small Group 40+ 3.5",
      team_type_id: small_tt_40_35.id,
      season_year: current_year,
      is_pseudo: false
    },
    small_tenant
  )

upsert_team_role.(smallgroup_user, small_team_18, :captain, small_tenant)
upsert_team_role.(smallgroup_user, small_team_40, :captain, small_tenant)

IO.puts("Small Group: teams and team roles seeded.")

# ==============================================================================
# 10.6 Small Group: TeamMemberships
# ==============================================================================

upsert_membership = fn player, team, tenant ->
  existing =
    TeamMembership
    |> Ash.Query.filter(player_id == ^player.id and team_id == ^team.id)
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %TeamMembership{}} ->
      :skipped

    _ ->
      TeamMembership
      |> Ash.Changeset.for_create(
        :create,
        %{
          player_id: player.id,
          team_id: team.id,
          team_type_id: team.team_type_id,
          season_year: team.season_year,
          group_id: tenant
        },
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

# Assign 18+ eligible players to the 18+ 3.5 team
eligible_18 = Enum.filter(small_players, & &1.eligible_18_plus)
Enum.take(eligible_18, 12) |> Enum.each(&upsert_membership.(&1, small_team_18, small_tenant))

# Assign 40+ eligible players to the 40+ 3.5 team
eligible_40 = Enum.filter(small_players, & &1.eligible_40_plus)
Enum.take(eligible_40, 10) |> Enum.each(&upsert_membership.(&1, small_team_40, small_tenant))

IO.puts("Small Group: team memberships seeded.")

# ==============================================================================
# 10.7 Small Group: Matches (8–12 per team, spanning -2 weeks to +3 months)
# ==============================================================================

today = Date.utc_today()

upsert_match = fn attrs, tenant ->
  existing =
    Match
    |> Ash.Query.filter(
      team_id == ^attrs.team_id and match_start_datetime == ^attrs.match_start_datetime
    )
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %Match{}} ->
      :skipped

    _ ->
      Match
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :group_id, tenant),
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

build_match_dt = fn days_offset ->
  date = Date.add(today, days_offset)
  {:ok, dt} = DateTime.new(date, ~T[18:00:00], "America/Chicago")
  DateTime.shift_zone!(dt, "Etc/UTC")
end

small_match_offsets = [-12, -5, 2, 9, 16, 23, 30, 37, 44, 51]

opponents = [
  "Lincoln TC",
  "Bellevue RC",
  "Elkhorn TC",
  "Papillion RC",
  "Council Bluffs TC",
  "Fremont TC",
  "Norfolk RC",
  "Kearney TC",
  "Grand Island TC",
  "Norfolk TC"
]

small_match_offsets
|> Enum.zip(opponents)
|> Enum.each(fn {offset, opponent} ->
  dt = build_match_dt.(offset)
  home_or_away = if rem(offset, 2) == 0, do: :home, else: :away
  loc = if offset < 0, do: small_loc_1, else: small_loc_2

  upsert_match.(
    %{
      team_id: small_team_18.id,
      opponent: opponent,
      home_or_away: home_or_away,
      match_start_datetime: dt,
      timezone: "America/Chicago",
      location_id: loc.id
    },
    small_tenant
  )
end)

small_match_offsets
|> Enum.zip(Enum.reverse(opponents))
|> Enum.each(fn {offset, opponent} ->
  dt = build_match_dt.(offset + 1)
  home_or_away = if rem(offset, 2) == 0, do: :away, else: :home
  loc = if offset < 0, do: small_loc_2, else: small_loc_1

  upsert_match.(
    %{
      team_id: small_team_40.id,
      opponent: opponent,
      home_or_away: home_or_away,
      match_start_datetime: dt,
      timezone: "America/Chicago",
      location_id: loc.id
    },
    small_tenant
  )
end)

IO.puts("Small Group: matches seeded.")

# ==============================================================================
# 10.8 Large Group
# ==============================================================================

large_group = upsert_group.("Large Group", "large-group")
upsert_group_membership.(large_group, admin_user, :owner)
upsert_group_membership.(large_group, bigowner1_user, :owner)
upsert_group_membership.(large_group, captain_user, :member)
upsert_group_membership.(large_group, member_user, :member)
IO.puts("Large Group ready (id: #{large_group.id})")

large_tenant = large_group.id

# ==============================================================================
# 10.9 Large Group: TeamTypes & SeasonRules
# ==============================================================================

large_tt_18_35 =
  upsert_team_type.(
    %{
      name: "18+ 3.5",
      age_group: "18_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    },
    large_tenant
  )

large_tt_40_35 =
  upsert_team_type.(
    %{
      name: "40+ 3.5",
      age_group: "40_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    },
    large_tenant
  )

large_tt_18_40 =
  upsert_team_type.(
    %{
      name: "18+ 4.0",
      age_group: "18_plus",
      ntrp_level: Decimal.new("4.0"),
      allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]
    },
    large_tenant
  )

large_tt_18_45 =
  upsert_team_type.(
    %{
      name: "18+ 4.5",
      age_group: "18_plus",
      ntrp_level: Decimal.new("4.5"),
      allowed_ntrp_levels: [Decimal.new("4.0"), Decimal.new("4.5")]
    },
    large_tenant
  )

Enum.each([large_tt_18_35, large_tt_40_35, large_tt_18_40, large_tt_18_45], fn tt ->
  upsert_season_rules.(tt, current_year, season_rules_defaults, large_tenant)
end)

IO.puts("Large Group: team types and season rules seeded.")

# ==============================================================================
# Large Group: Locations
# ==============================================================================

large_loc_1 =
  upsert_location.(
    %{
      name: "Woods Tennis Center",
      street_address: "4701 Happy Hollow Blvd",
      city: "Omaha",
      state: "NE",
      postal_code: "68132",
      google_maps_url: "https://maps.google.com/?q=Woods+Tennis+Center"
    },
    large_tenant
  )

large_loc_2 =
  upsert_location.(
    %{
      name: "Lifetime Fitness - West Omaha",
      street_address: "17802 Burke St",
      city: "Omaha",
      state: "NE",
      postal_code: "68118",
      google_maps_url: "https://maps.google.com/?q=Lifetime+Fitness+West+Omaha"
    },
    large_tenant
  )

large_loc_3 =
  upsert_location.(
    %{
      name: "Genesis Health Club - Westroads",
      street_address: "10831 Old Mill Rd",
      city: "Omaha",
      state: "NE",
      postal_code: "68154",
      google_maps_url: "https://maps.google.com/?q=Genesis+Health+Club+Westroads"
    },
    large_tenant
  )

# ==============================================================================
# 10.10 Large Group: ~80 players
# ==============================================================================

large_player_defs = [
  # 3.0 players — 40+ eligible
  %{name: "Aaron Brooks", ntrp: "3.0", e18: true, e40: true, e55: false},
  %{name: "Bernard Clark", ntrp: "3.0", e18: true, e40: true, e55: true},
  %{name: "Carl Davis", ntrp: "3.0", e18: true, e40: true, e55: false},
  %{name: "David Evans", ntrp: "3.0", e18: false, e40: true, e55: true},
  %{name: "Eric Foster", ntrp: "3.0", e18: true, e40: true, e55: false},
  %{name: "Frank Garcia", ntrp: "3.0", e18: true, e40: true, e55: false},
  %{name: "George Hill", ntrp: "3.0", e18: false, e40: true, e55: true},
  %{name: "Harold Irving", ntrp: "3.0", e18: true, e40: true, e55: false},
  %{name: "Ivan Jones", ntrp: "3.0", e18: true, e40: true, e55: false},
  %{name: "James King", ntrp: "3.0", e18: true, e40: true, e55: false},
  # 3.5 players — mix of age eligibility
  %{name: "Kevin Lewis", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Liam Martin", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Michael Nelson", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Nathan Owen", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Oliver Parker", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Patrick Quinn", ntrp: "3.5", e18: true, e40: true, e55: false},
  %{name: "Quinn Reed", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Robert Scott", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Samuel Turner", ntrp: "3.5", e18: true, e40: true, e55: false},
  %{name: "Thomas Underwood", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Ulric Vance", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Victor Walsh", ntrp: "3.5", e18: true, e40: true, e55: false},
  %{name: "William Xavier", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Xavier Young", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Yusuf Zane", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Zack Abbott", ntrp: "3.5", e18: true, e40: true, e55: false},
  %{name: "Adam Bates", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Brian Cole", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Chris Dean", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Daniel Edge", ntrp: "3.5", e18: true, e40: true, e55: false},
  # 4.0 players
  %{name: "Edward Flynn", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Francis Grant", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Gary Holt", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Henry Inman", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Ian James", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "John Kent", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Karl Lane", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Leo Moore", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Mark Nash", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Neil Oakes", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Oscar Penn", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Paul Quinn", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Roger Reed", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Steve Saul", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Tim Todd", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Umar Upton", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Vince Vale", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Walter Webb", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Xander Wren", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Yancy York", ntrp: "4.0", e18: true, e40: false, e55: false},
  # 4.5 players
  %{name: "Zane Acres", ntrp: "4.5", e18: true, e40: false, e55: false},
  %{name: "Alan Barry", ntrp: "4.5", e18: true, e40: false, e55: false},
  %{name: "Ben Cain", ntrp: "4.5", e18: true, e40: false, e55: false},
  %{name: "Chad Dale", ntrp: "4.5", e18: true, e40: false, e55: false},
  %{name: "Dan Earl", ntrp: "4.5", e18: true, e40: false, e55: false},
  %{name: "Evan Ford", ntrp: "4.5", e18: true, e40: false, e55: false},
  %{name: "Fred Gale", ntrp: "4.5", e18: true, e40: false, e55: false},
  %{name: "Glen Hart", ntrp: "4.5", e18: true, e40: false, e55: false},
  %{name: "Hal Irvine", ntrp: "4.5", e18: true, e40: false, e55: false},
  %{name: "Ian Jay", ntrp: "4.5", e18: true, e40: false, e55: false},
  # Mixed 3.5/4.0 for flexibility
  %{name: "Jake Kerr", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Kyle Lane", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Luke Marsh", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Matt Norris", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Nick Owen", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Otto Park", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Pete Rowe", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Ray Sage", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Sam Tate", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Tom Urry", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Udo Vale", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Van West", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Wade Xero", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Xavi York", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Yoel Zack", ntrp: "3.5", e18: true, e40: false, e55: false},
  %{name: "Zeke Adam", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Abe Buck", ntrp: "3.5", e18: true, e40: true, e55: false},
  %{name: "Ben Cord", ntrp: "4.0", e18: true, e40: false, e55: false},
  %{name: "Cal Dunn", ntrp: "3.5", e18: true, e40: true, e55: false},
  %{name: "Dex Eads", ntrp: "4.0", e18: true, e40: false, e55: false}
]

large_players =
  Enum.map(large_player_defs, fn p ->
    upsert_player.(
      %{
        name: p.name,
        ntrp_rating: p.ntrp,
        eligible_18_plus: p.e18,
        eligible_40_plus: p.e40,
        eligible_55_plus: p.e55
      },
      large_tenant
    )
  end)

IO.puts("Large Group: #{length(large_players)} players seeded.")

# ==============================================================================
# 10.11 Large Group: Teams (7 total) + TeamRoles
# ==============================================================================

large_team_18_35_a =
  upsert_team.(
    %{
      name: "LG 18+ 3.5 Team A",
      team_type_id: large_tt_18_35.id,
      season_year: current_year,
      is_pseudo: false
    },
    large_tenant
  )

large_team_18_35_b =
  upsert_team.(
    %{
      name: "LG 18+ 3.5 Team B",
      team_type_id: large_tt_18_35.id,
      season_year: current_year,
      is_pseudo: false
    },
    large_tenant
  )

large_team_40_35_a =
  upsert_team.(
    %{
      name: "LG 40+ 3.5 Team A",
      team_type_id: large_tt_40_35.id,
      season_year: current_year,
      is_pseudo: false
    },
    large_tenant
  )

large_team_40_35_b =
  upsert_team.(
    %{
      name: "LG 40+ 3.5 Team B",
      team_type_id: large_tt_40_35.id,
      season_year: current_year,
      is_pseudo: false
    },
    large_tenant
  )

large_team_18_40_a =
  upsert_team.(
    %{
      name: "LG 18+ 4.0 Team A",
      team_type_id: large_tt_18_40.id,
      season_year: current_year,
      is_pseudo: false
    },
    large_tenant
  )

large_team_18_40_b =
  upsert_team.(
    %{
      name: "LG 18+ 4.0 Team B",
      team_type_id: large_tt_18_40.id,
      season_year: current_year,
      is_pseudo: false
    },
    large_tenant
  )

large_team_18_45 =
  upsert_team.(
    %{
      name: "LG 18+ 4.5",
      team_type_id: large_tt_18_45.id,
      season_year: current_year,
      is_pseudo: false
    },
    large_tenant
  )

# bigowner1 = captain of 18+ 3.5 A and 18+ 4.0 A
# captain_user = captain of 18+ 3.5 B and 18+ 4.0 B
upsert_team_role.(bigowner1_user, large_team_18_35_a, :captain, large_tenant)
upsert_team_role.(bigowner1_user, large_team_18_40_a, :captain, large_tenant)
upsert_team_role.(captain_user, large_team_18_35_b, :captain, large_tenant)
upsert_team_role.(captain_user, large_team_18_40_b, :captain, large_tenant)

IO.puts("Large Group: teams and team roles seeded.")

# ==============================================================================
# 10.12 Large Group: TeamMemberships
# ==============================================================================

large_players_by_ntrp =
  Enum.group_by(large_players, fn p ->
    if p.ntrp_rating, do: Decimal.to_string(p.ntrp_rating), else: "none"
  end)

players_18_35 =
  Enum.filter(large_players, fn p ->
    p.eligible_18_plus and p.ntrp_rating in [Decimal.new("3.0"), Decimal.new("3.5")]
  end)

players_40_35 =
  Enum.filter(large_players, fn p ->
    p.eligible_40_plus and p.ntrp_rating in [Decimal.new("3.0"), Decimal.new("3.5")]
  end)

players_18_40 =
  Enum.filter(large_players, fn p ->
    p.eligible_18_plus and p.ntrp_rating in [Decimal.new("3.5"), Decimal.new("4.0")]
  end)

players_18_45 =
  Enum.filter(large_players, fn p ->
    p.eligible_18_plus and p.ntrp_rating in [Decimal.new("4.0"), Decimal.new("4.5")]
  end)

# Assign ~12 players per team
{team_a_18_35, team_b_18_35} = Enum.split(Enum.take(players_18_35, 24), 12)
Enum.each(team_a_18_35, &upsert_membership.(&1, large_team_18_35_a, large_tenant))
Enum.each(team_b_18_35, &upsert_membership.(&1, large_team_18_35_b, large_tenant))

{team_a_40_35, team_b_40_35} = Enum.split(Enum.take(players_40_35, 20), 10)
Enum.each(team_a_40_35, &upsert_membership.(&1, large_team_40_35_a, large_tenant))
Enum.each(team_b_40_35, &upsert_membership.(&1, large_team_40_35_b, large_tenant))

{team_a_18_40, team_b_18_40} = Enum.split(Enum.take(players_18_40, 24), 12)
Enum.each(team_a_18_40, &upsert_membership.(&1, large_team_18_40_a, large_tenant))
Enum.each(team_b_18_40, &upsert_membership.(&1, large_team_18_40_b, large_tenant))

Enum.take(players_18_45, 12) |> Enum.each(&upsert_membership.(&1, large_team_18_45, large_tenant))

IO.puts("Large Group: team memberships seeded.")

# ==============================================================================
# 10.13 Large Group: Matches
# ==============================================================================

large_teams = [
  {large_team_18_35_a, large_loc_1},
  {large_team_18_35_b, large_loc_2},
  {large_team_40_35_a, large_loc_3},
  {large_team_40_35_b, large_loc_1},
  {large_team_18_40_a, large_loc_2},
  {large_team_18_40_b, large_loc_3},
  {large_team_18_45, large_loc_1}
]

large_opponents = [
  "Sioux City TC",
  "Des Moines RC",
  "Ames TC",
  "Cedar Rapids RC",
  "Iowa City TC",
  "Davenport TC",
  "Dubuque RC",
  "Waterloo TC",
  "Lincoln TC",
  "Bellevue RC"
]

large_offsets = [-14, -7, 0, 7, 14, 21, 28, 35, 42, 49]

large_teams
|> Enum.with_index()
|> Enum.each(fn {{team, loc}, team_idx} ->
  large_offsets
  |> Enum.zip(large_opponents)
  |> Enum.each(fn {offset, opponent} ->
    dt = build_match_dt.(offset + team_idx)
    home_or_away = if rem(offset + team_idx, 2) == 0, do: :home, else: :away

    upsert_match.(
      %{
        team_id: team.id,
        opponent: opponent,
        home_or_away: home_or_away,
        match_start_datetime: dt,
        timezone: "America/Chicago",
        location_id: loc.id
      },
      large_tenant
    )
  end)
end)

IO.puts("Large Group: matches seeded.")
IO.puts("Seeds complete!")
