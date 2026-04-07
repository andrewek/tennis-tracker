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
  TeamLineupColumn,
  TeamLineupSlot,
  SeasonRules,
  Location,
  TeamMembership,
  TeamRole,
  Match,
  PlayerTag,
  Tag,
  TagCategory
}

# ==============================================================================
# Users
# ==============================================================================

dev_users = [
  %{email: "admin@example.com", password: "Password1!", role: :admin},
  %{email: "mainowner@example.com", password: "Password1!", role: :member},
  %{email: "mixedowner@example.com", password: "Password1!", role: :member},
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
mainowner_user = Map.fetch!(users_map, "mainowner@example.com")
mixedowner_user = Map.fetch!(users_map, "mixedowner@example.com")
captain_user = Map.fetch!(users_map, "captain@example.com")
member_user = Map.fetch!(users_map, "member@example.com")

IO.puts("Seeded #{length(users)} users.")

# ==============================================================================
# Helper functions
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
    {:ok, %SeasonRules{} = sr} ->
      sr

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

upsert_player = fn attrs, tenant ->
  existing =
    Player
    |> Ash.Query.filter(name == ^attrs.name)
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %Player{} = p} ->
      p

    _ ->
      ntrp = if attrs[:ntrp], do: Decimal.new(attrs.ntrp), else: nil

      Player
      |> Ash.Changeset.for_create(
        :create,
        %{
          name: attrs.name,
          ntrp_rating: ntrp,
          group_id: tenant
        },
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

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

upsert_player_tag = fn player, tag, tenant ->
  existing =
    PlayerTag
    |> Ash.Query.filter(player_id == ^player.id and tag_id == ^tag.id)
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %PlayerTag{}} ->
      :skipped

    _ ->
      PlayerTag
      |> Ash.Changeset.for_create(
        :create,
        %{player_id: player.id, tag_id: tag.id, group_id: tenant},
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)
  end
end

upsert_lineup_column = fn attrs, tenant ->
  existing =
    TeamLineupColumn
    |> Ash.Query.filter(team_id == ^attrs.team_id and name == ^attrs.name)
    |> Ash.read_one!(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    nil ->
      TeamLineupColumn
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :group_id, tenant),
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    col ->
      col
  end
end

upsert_lineup_slot = fn attrs, tenant ->
  existing =
    TeamLineupSlot
    |> Ash.Query.filter(team_id == ^attrs.team_id and name == ^attrs.name)
    |> Ash.read_one!(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    nil ->
      TeamLineupSlot
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :group_id, tenant),
        domain: Tennis,
        tenant: tenant,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

    slot ->
      slot
  end
end

seed_40_lineup = fn team, tenant ->
  singles_col = upsert_lineup_column.(%{name: "Singles", team_id: team.id}, tenant)

  upsert_lineup_slot.(
    %{
      name: "#1 Singles",
      team_id: team.id,
      expected_count: 1,
      team_lineup_column_id: singles_col.id
    },
    tenant
  )

  doubles_col = upsert_lineup_column.(%{name: "Doubles", team_id: team.id}, tenant)

  upsert_lineup_slot.(
    %{
      name: "#1 Doubles",
      team_id: team.id,
      expected_count: 2,
      team_lineup_column_id: doubles_col.id
    },
    tenant
  )

  upsert_lineup_slot.(
    %{
      name: "#2 Doubles",
      team_id: team.id,
      expected_count: 2,
      team_lineup_column_id: doubles_col.id
    },
    tenant
  )

  upsert_lineup_slot.(
    %{
      name: "#3 Doubles",
      team_id: team.id,
      expected_count: 2,
      team_lineup_column_id: doubles_col.id
    },
    tenant
  )

  reserve_col = upsert_lineup_column.(%{name: "Reserve", team_id: team.id}, tenant)

  upsert_lineup_slot.(
    %{
      name: "Sub",
      team_id: team.id,
      team_lineup_column_id: reserve_col.id,
      is_exclusion_slot: false
    },
    tenant
  )
end

seed_18_lineup = fn team, tenant ->
  singles_col = upsert_lineup_column.(%{name: "Singles", team_id: team.id}, tenant)

  upsert_lineup_slot.(
    %{
      name: "#1 Singles",
      team_id: team.id,
      expected_count: 1,
      team_lineup_column_id: singles_col.id
    },
    tenant
  )

  upsert_lineup_slot.(
    %{
      name: "#2 Singles",
      team_id: team.id,
      expected_count: 1,
      team_lineup_column_id: singles_col.id
    },
    tenant
  )

  doubles_col = upsert_lineup_column.(%{name: "Doubles", team_id: team.id}, tenant)

  upsert_lineup_slot.(
    %{
      name: "#1 Doubles",
      team_id: team.id,
      expected_count: 2,
      team_lineup_column_id: doubles_col.id
    },
    tenant
  )

  upsert_lineup_slot.(
    %{
      name: "#2 Doubles",
      team_id: team.id,
      expected_count: 2,
      team_lineup_column_id: doubles_col.id
    },
    tenant
  )

  upsert_lineup_slot.(
    %{
      name: "#3 Doubles",
      team_id: team.id,
      expected_count: 2,
      team_lineup_column_id: doubles_col.id
    },
    tenant
  )

  reserve_col = upsert_lineup_column.(%{name: "Reserve", team_id: team.id}, tenant)

  upsert_lineup_slot.(
    %{
      name: "Sub",
      team_id: team.id,
      team_lineup_column_id: reserve_col.id,
      is_exclusion_slot: false
    },
    tenant
  )
end

preset_taxonomy = [
  {"Age Group", ["18+", "40+", "55+", "65+", "70+"]},
  {"League Gender", ["Men's Leagues", "Women's Leagues", "Mixed Leagues"]},
  {"Availability", ["Limited Availability", "Medical Hold", "Inactive"]},
  {"Role", ["Willing to Captain", "Sub Only", "Roster Fill Only", "Can Play Up", "Prospect"]}
]

seed_preset_tags = fn tenant ->
  Enum.each(preset_taxonomy, fn {category_name, tag_names} ->
    category =
      case TagCategory
           |> Ash.Query.filter(name == ^category_name)
           |> Ash.read_one!(domain: Tennis, tenant: tenant, authorize?: false) do
        nil ->
          TagCategory
          |> Ash.Changeset.for_create(
            :create,
            %{name: category_name, group_id: tenant},
            domain: Tennis,
            tenant: tenant,
            authorize?: false
          )
          |> Ash.create!(authorize?: false)

        existing ->
          existing
      end

    Enum.each(tag_names, fn tag_name ->
      existing =
        Tag
        |> Ash.Query.filter(
          tag_category_id == ^category.id and
            fragment("lower(?)", name) == ^String.downcase(tag_name)
        )
        |> Ash.read_one!(domain: Tennis, tenant: tenant, authorize?: false)

      if is_nil(existing) do
        Tag
        |> Ash.Changeset.for_create(
          :create,
          %{name: tag_name, tag_category_id: category.id, group_id: tenant},
          domain: Tennis,
          tenant: tenant,
          authorize?: false
        )
        |> Ash.create!(authorize?: false)
      end
    end)
  end)
end

# Look up a tag by category name and tag name within a tenant
find_tag = fn tenant, category_name, tag_name ->
  category =
    TagCategory
    |> Ash.Query.filter(name == ^category_name)
    |> Ash.read_one!(domain: Tennis, tenant: tenant, authorize?: false)

  tag =
    Tag
    |> Ash.Query.filter(
      tag_category_id == ^category.id and fragment("lower(?)", name) == ^String.downcase(tag_name)
    )
    |> Ash.read_one!(domain: Tennis, tenant: tenant, authorize?: false)

  tag
end

current_year = Date.utc_today().year
season_rules_defaults = %{min_roster: 10, max_roster: 18, on_level_min_pct: Decimal.new("0.60")}

# ==============================================================================
# Group 1: "Main" (slug: "main")
# ==============================================================================

main_group = upsert_group.("Main", "main")
upsert_group_membership.(main_group, admin_user, :owner)
upsert_group_membership.(main_group, mainowner_user, :owner)
upsert_group_membership.(main_group, captain_user, :member)
upsert_group_membership.(main_group, member_user, :member)
IO.puts("Main group ready (id: #{main_group.id})")

main_tenant = main_group.id

# Seed preset tags for Main group
seed_preset_tags.(main_tenant)
IO.puts("Main group: preset tags seeded.")

# ==============================================================================
# Main Group: TeamTypes & SeasonRules
# ==============================================================================

main_tt_18_45 =
  upsert_team_type.(
    %{
      name: "18+ 4.5",
      age_group: "18_plus",
      ntrp_level: Decimal.new("4.5"),
      allowed_ntrp_levels: [Decimal.new("4.0"), Decimal.new("4.5")]
    },
    main_tenant
  )

main_tt_18_40 =
  upsert_team_type.(
    %{
      name: "18+ 4.0",
      age_group: "18_plus",
      ntrp_level: Decimal.new("4.0"),
      allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]
    },
    main_tenant
  )

main_tt_18_35 =
  upsert_team_type.(
    %{
      name: "18+ 3.5",
      age_group: "18_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    },
    main_tenant
  )

main_tt_40_35 =
  upsert_team_type.(
    %{
      name: "40+ 3.5",
      age_group: "40_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    },
    main_tenant
  )

main_sr_18_45 =
  upsert_season_rules.(main_tt_18_45, current_year, season_rules_defaults, main_tenant)

main_sr_18_40 =
  upsert_season_rules.(main_tt_18_40, current_year, season_rules_defaults, main_tenant)

main_sr_18_35 =
  upsert_season_rules.(main_tt_18_35, current_year, season_rules_defaults, main_tenant)

main_sr_40_35 =
  upsert_season_rules.(main_tt_40_35, current_year, season_rules_defaults, main_tenant)

IO.puts("Main group: team types and season rules seeded.")

# ==============================================================================
# Main Group: Locations
# ==============================================================================

main_loc_1 =
  upsert_location.(
    %{
      name: "Elmwood Park Tennis Courts",
      street_address: "602 S 60th St",
      city: "Omaha",
      state: "NE",
      postal_code: "68106",
      google_maps_url: "https://maps.google.com/?q=Elmwood+Park+Tennis+Courts"
    },
    main_tenant
  )

main_loc_2 =
  upsert_location.(
    %{
      name: "Woods Tennis Center",
      street_address: "4701 Happy Hollow Blvd",
      city: "Omaha",
      state: "NE",
      postal_code: "68132",
      google_maps_url: "https://maps.google.com/?q=Woods+Tennis+Center"
    },
    main_tenant
  )

# ==============================================================================
# Main Group: Players
# 12 x 4.5, 25 x 4.0, 25 x 3.5
# Tags: :tags key is list of {category_name, tag_name} pairs
# ==============================================================================

main_player_defs = [
  # ---- 4.5 players (12 total) ----
  # 1: 18+, 40+, 55+ | Willing to Captain
  %{
    name: "Aaron Blake",
    ntrp: "4.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 2: 18+, 40+, 55+
  %{
    name: "Brian Cole",
    ntrp: "4.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"}
    ]
  },
  # 3: 18+, 40+, 55+
  %{
    name: "Carl Dean",
    ntrp: "4.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"}
    ]
  },
  # 4: 18+, 40+ | Sub Only
  %{
    name: "David Earl",
    ntrp: "4.5",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}, {"Role", "Sub Only"}]
  },
  # 5: 18+, 40+
  %{
    name: "Ethan Ford",
    ntrp: "4.5",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  # 6: 18+, 40+
  %{
    name: "Frank Grant",
    ntrp: "4.5",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  # 7–12: 18+ only
  %{name: "George Holt", ntrp: "4.5", tags: [{"Age Group", "18+"}]},
  %{name: "Harold Irwin", ntrp: "4.5", tags: [{"Age Group", "18+"}]},
  %{name: "Ivan James", ntrp: "4.5", tags: [{"Age Group", "18+"}]},
  %{name: "Jake Kent", ntrp: "4.5", tags: [{"Age Group", "18+"}]},
  %{name: "Kevin Lane", ntrp: "4.5", tags: [{"Age Group", "18+"}]},
  %{name: "Liam Moore", ntrp: "4.5", tags: [{"Age Group", "18+"}]},

  # ---- 4.0 players (25 total) ----
  # 1: 18+, 40+, 55+ | Willing to Captain
  %{
    name: "Mark Nash",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 2: 18+, 40+, 55+ | Willing to Captain
  %{
    name: "Neil Oakes",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 3: 18+, 40+ | Willing to Captain
  %{
    name: "Oscar Penn",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 4: 18+, 40+, 55+ | Can Play Up
  %{
    name: "Paul Quinn",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"},
      {"Role", "Can Play Up"}
    ]
  },
  # 5: 18+, 40+ | Can Play Up
  %{
    name: "Roger Reed",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}, {"Role", "Can Play Up"}]
  },
  # 6: 18+ | Can Play Up
  %{
    name: "Steve Saul",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"Role", "Can Play Up"}]
  },
  # 7: 18+ | Can Play Up
  %{
    name: "Tim Todd",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"Role", "Can Play Up"}]
  },
  # 8: 18+, 40+, 55+ | Medical Hold, Roster Fill Only
  %{
    name: "Umar Upton",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"},
      {"Availability", "Medical Hold"},
      {"Role", "Roster Fill Only"}
    ]
  },
  # 9: 18+, 40+ | Medical Hold, Roster Fill Only
  %{
    name: "Vince Vale",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Availability", "Medical Hold"},
      {"Role", "Roster Fill Only"}
    ]
  },
  # 10: 18+, 40+, 55+
  %{
    name: "Walter Webb",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"}
    ]
  },
  # 11: 18+ | Limited Availability
  %{
    name: "Xander Wren",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"Availability", "Limited Availability"}]
  },
  # 12: 18+ | Prospective
  %{
    name: "Yancy York",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"Role", "Prospect"}]
  },
  # 13–18: 40+ (players 13-18); 16-18 also 55+
  %{
    name: "Zeke Adam",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  %{
    name: "Abe Bates",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  %{
    name: "Ben Cole",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  %{
    name: "Cal Dunn",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"}
    ]
  },
  %{
    name: "Dan Edge",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"}
    ]
  },
  %{
    name: "Ed Ford",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"}
    ]
  },
  # 19–25: 18+ only
  %{name: "Gus Hart", ntrp: "4.0", tags: [{"Age Group", "18+"}]},
  %{name: "Hal Irby", ntrp: "4.0", tags: [{"Age Group", "18+"}]},
  %{name: "Ian Jay", ntrp: "4.0", tags: [{"Age Group", "18+"}]},
  %{name: "Jon Kirk", ntrp: "4.0", tags: [{"Age Group", "18+"}]},
  %{name: "Ken Lee", ntrp: "4.0", tags: [{"Age Group", "18+"}]},
  %{name: "Leo Marsh", ntrp: "4.0", tags: [{"Age Group", "18+"}]},
  %{name: "Moe Nash", ntrp: "4.0", tags: [{"Age Group", "18+"}]},

  # ---- 3.5 players (25 total) ----
  # 1: 18+, 40+, 55+ | Willing to Captain
  %{
    name: "Nick Owen",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 2: 18+, 40+, 55+ | Willing to Captain
  %{
    name: "Otto Park",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 3: 18+, 40+ | Willing to Captain
  %{
    name: "Pete Rowe",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 4: 18+, 40+, 55+ | Can Play Up
  %{
    name: "Ray Sage",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"},
      {"Role", "Can Play Up"}
    ]
  },
  # 5: 18+, 40+ | Can Play Up
  %{
    name: "Sam Tate",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}, {"Role", "Can Play Up"}]
  },
  # 6: 18+ | Can Play Up
  %{
    name: "Tom Urry",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"Role", "Can Play Up"}]
  },
  # 7: 18+ | Can Play Up
  %{
    name: "Udo Vale",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"Role", "Can Play Up"}]
  },
  # 8: 18+, 40+, 55+ | Medical Hold, Roster Fill Only
  %{
    name: "Van West",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"},
      {"Availability", "Medical Hold"},
      {"Role", "Roster Fill Only"}
    ]
  },
  # 9: 18+, 40+ | Medical Hold, Roster Fill Only
  %{
    name: "Wade Xero",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Availability", "Medical Hold"},
      {"Role", "Roster Fill Only"}
    ]
  },
  # 10: 18+, 40+, 55+
  %{
    name: "Xavi York",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"}
    ]
  },
  # 11: 18+ | Limited Availability
  %{
    name: "Yoel Zack",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"Availability", "Limited Availability"}]
  },
  # 12: 18+ | Prospective
  %{
    name: "Zach Able",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"Role", "Prospect"}]
  },
  # 13–18: 40+ (16-18 also 55+)
  %{
    name: "Al Burns",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  %{
    name: "Bob Crane",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  %{
    name: "Curt Drew",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  %{
    name: "Doug Egan",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"}
    ]
  },
  %{
    name: "Eli Falk",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"}
    ]
  },
  %{
    name: "Finn Gray",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"Age Group", "40+"},
      {"Age Group", "55+"}
    ]
  },
  # 19–25: 18+ only
  %{name: "Glen Hale", ntrp: "3.5", tags: [{"Age Group", "18+"}]},
  %{name: "Hank Ibis", ntrp: "3.5", tags: [{"Age Group", "18+"}]},
  %{name: "Ike Jones", ntrp: "3.5", tags: [{"Age Group", "18+"}]},
  %{name: "Jim Kale", ntrp: "3.5", tags: [{"Age Group", "18+"}]},
  %{name: "Kurt Lode", ntrp: "3.5", tags: [{"Age Group", "18+"}]},
  %{name: "Lars Mace", ntrp: "3.5", tags: [{"Age Group", "18+"}]},
  %{name: "Matt Nord", ntrp: "3.5", tags: [{"Age Group", "18+"}]}
]

main_players = Enum.map(main_player_defs, &upsert_player.(&1, main_tenant))
main_players_by_name = Map.new(Enum.zip(Enum.map(main_player_defs, & &1.name), main_players))

IO.puts("Main group: #{length(main_players)} players seeded.")

# Assign tags to Main players
Enum.zip(main_player_defs, main_players)
|> Enum.each(fn {def, player} ->
  Enum.each(def.tags, fn {category_name, tag_name} ->
    tag = find_tag.(main_tenant, category_name, tag_name)
    if tag, do: upsert_player_tag.(player, tag, main_tenant)
  end)
end)

IO.puts("Main group: player tags assigned.")

# ==============================================================================
# Main Group: Teams + TeamRoles + TeamMemberships
# ==============================================================================

# Look up tags needed for membership filtering
tag_18_eligible = find_tag.(main_tenant, "Age Group", "18+")
tag_40_eligible = find_tag.(main_tenant, "Age Group", "40+")
tag_medical_hold = find_tag.(main_tenant, "Availability", "Medical Hold")
tag_can_play_up = find_tag.(main_tenant, "Role", "Can Play Up")

# Helper: does player have a tag?
has_tag? = fn player, tag ->
  PlayerTag
  |> Ash.Query.filter(player_id == ^player.id and tag_id == ^tag.id)
  |> Ash.read_one!(domain: Tennis, tenant: main_tenant, authorize?: false)
  |> then(&(not is_nil(&1)))
end

# Helper: build player index with tag info for filtering
enrich_player = fn player ->
  %{
    player: player,
    ntrp: player.ntrp_rating,
    is_18: has_tag?.(player, tag_18_eligible),
    is_40: has_tag?.(player, tag_40_eligible),
    is_medical: has_tag?.(player, tag_medical_hold),
    is_play_up: has_tag?.(player, tag_can_play_up)
  }
end

enriched_players = Enum.map(main_players, enrich_player)

# Separate by NTRP
players_45 = Enum.filter(enriched_players, &(&1.ntrp == Decimal.new("4.5")))
players_40 = Enum.filter(enriched_players, &(&1.ntrp == Decimal.new("4.0")))
players_35 = Enum.filter(enriched_players, &(&1.ntrp == Decimal.new("3.5")))

# Team: "Main 18+ 4.5" — ~10 from 4.5 pool, skip Medical Hold
main_team_18_45 =
  upsert_team.(
    %{
      name: "Main 18+ 4.5",
      team_type_id: main_tt_18_45.id,
      season_year: current_year,
      is_pseudo: false
    },
    main_tenant
  )

upsert_team_role.(captain_user, main_team_18_45, :captain, main_tenant)

players_45
|> Enum.filter(&(!&1.is_medical))
|> Enum.take(10)
|> Enum.each(&upsert_membership.(&1.player, main_team_18_45, main_tenant))

# Teams: "Main 18+ 4.0 A" and "Main 18+ 4.0 B" — ~12+11 from 4.0 pool, skip Medical Hold
main_team_18_40_a =
  upsert_team.(
    %{
      name: "Main 18+ 4.0 A",
      team_type_id: main_tt_18_40.id,
      season_year: current_year,
      is_pseudo: false
    },
    main_tenant
  )

main_team_18_40_b =
  upsert_team.(
    %{
      name: "Main 18+ 4.0 B",
      team_type_id: main_tt_18_40.id,
      season_year: current_year,
      is_pseudo: false
    },
    main_tenant
  )

upsert_team_role.(mainowner_user, main_team_18_40_a, :captain, main_tenant)
upsert_team_role.(captain_user, main_team_18_40_b, :captain, main_tenant)

# For 4.0: put "Can Play Up" players first (spread across both teams), skip Medical Hold
players_40_available = Enum.filter(players_40, &(!&1.is_medical))
{play_up_40, regular_40} = Enum.split_with(players_40_available, & &1.is_play_up)

# Distribute Can Play Up: one per team then fill up
team_a_40_pool = play_up_40 |> Enum.take_every(2) |> Enum.concat(regular_40)
team_b_40_pool = play_up_40 |> Enum.drop_every(2) |> Enum.concat(regular_40)

Enum.take(team_a_40_pool, 12)
|> Enum.each(&upsert_membership.(&1.player, main_team_18_40_a, main_tenant))

used_in_a = MapSet.new(Enum.take(team_a_40_pool, 12), & &1.player.id)

players_40_available
|> Enum.reject(&MapSet.member?(used_in_a, &1.player.id))
|> Enum.take(11)
|> Enum.each(&upsert_membership.(&1.player, main_team_18_40_b, main_tenant))

# Teams: "Main 18+ 3.5 A" and "Main 18+ 3.5 B"
main_team_18_35_a =
  upsert_team.(
    %{
      name: "Main 18+ 3.5 A",
      team_type_id: main_tt_18_35.id,
      season_year: current_year,
      is_pseudo: false
    },
    main_tenant
  )

main_team_18_35_b =
  upsert_team.(
    %{
      name: "Main 18+ 3.5 B",
      team_type_id: main_tt_18_35.id,
      season_year: current_year,
      is_pseudo: false
    },
    main_tenant
  )

players_35_available = Enum.filter(players_35, &(!&1.is_medical))
{play_up_35, regular_35} = Enum.split_with(players_35_available, & &1.is_play_up)

team_a_35_pool = play_up_35 |> Enum.take_every(2) |> Enum.concat(regular_35)

Enum.take(team_a_35_pool, 12)
|> Enum.each(&upsert_membership.(&1.player, main_team_18_35_a, main_tenant))

used_in_35a = MapSet.new(Enum.take(team_a_35_pool, 12), & &1.player.id)

players_35_available
|> Enum.reject(&MapSet.member?(used_in_35a, &1.player.id))
|> Enum.take(11)
|> Enum.each(&upsert_membership.(&1.player, main_team_18_35_b, main_tenant))

# Team: "Main 40+ 3.5" — ~10 players with 40+ tag and NTRP 3.5, skip Medical Hold
main_team_40_35 =
  upsert_team.(
    %{
      name: "Main 40+ 3.5",
      team_type_id: main_tt_40_35.id,
      season_year: current_year,
      is_pseudo: false
    },
    main_tenant
  )

players_35
|> Enum.filter(&(&1.is_40 && !&1.is_medical))
|> Enum.take(10)
|> Enum.each(&upsert_membership.(&1.player, main_team_40_35, main_tenant))

IO.puts("Main group: teams and memberships seeded.")

# ==============================================================================
# Main Group: Lineup columns and slots (18+ teams only)
# ==============================================================================

Enum.each(
  [main_team_18_45, main_team_18_40_a, main_team_18_40_b, main_team_18_35_a, main_team_18_35_b],
  &seed_18_lineup.(&1, main_tenant)
)

seed_40_lineup.(main_team_40_35, main_tenant)

IO.puts("Main group: lineup columns and slots seeded.")

# ==============================================================================
# Main Group: SeasonRules default tags
# ==============================================================================

Tennis.sync_season_rules_default_tags(
  main_sr_18_45.id,
  [tag_18_eligible.id],
  tenant: main_tenant,
  actor: admin_user
)

Tennis.sync_season_rules_default_tags(
  main_sr_18_40.id,
  [tag_18_eligible.id],
  tenant: main_tenant,
  actor: admin_user
)

Tennis.sync_season_rules_default_tags(
  main_sr_18_35.id,
  [tag_18_eligible.id],
  tenant: main_tenant,
  actor: admin_user
)

Tennis.sync_season_rules_default_tags(
  main_sr_40_35.id,
  [tag_40_eligible.id],
  tenant: main_tenant,
  actor: admin_user
)

IO.puts("Main group: season rules default tags set.")

# ==============================================================================
# Group 2: "Mixed" (slug: "mixed")
# 12 men + 12 women, no teams seeded
# ==============================================================================

mixed_group = upsert_group.("Mixed", "mixed")
upsert_group_membership.(mixed_group, mixedowner_user, :owner)
upsert_group_membership.(mixed_group, member_user, :member)
IO.puts("Mixed group ready (id: #{mixed_group.id})")

mixed_tenant = mixed_group.id

# Seed preset tags for Mixed group
seed_preset_tags.(mixed_tenant)
IO.puts("Mixed group: preset tags seeded.")

# ==============================================================================
# Mixed Group: Players
# 6 men 3.5, 6 men 4.0, 6 women 3.5, 6 women 4.0
# ==============================================================================

mixed_player_defs = [
  # Men — 3.5
  # 1: Men's+Mixed | Willing to Captain
  %{
    name: "Alex Chen",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Men's Leagues"},
      {"League Gender", "Mixed Leagues"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 2: Men's+Mixed | Willing to Captain
  %{
    name: "Ben Davis",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Men's Leagues"},
      {"League Gender", "Mixed Leagues"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 3: Men's+Mixed
  %{
    name: "Chris Evans",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Men's Leagues"},
      {"League Gender", "Mixed Leagues"}
    ]
  },
  # 4: Men's only
  %{
    name: "Dave Foster",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"League Gender", "Men's Leagues"}]
  },
  # 5: Men's only
  %{
    name: "Eric Green",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"League Gender", "Men's Leagues"}]
  },
  # 6: Mixed only | Sub Only
  %{
    name: "Frank Hall",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Mixed Leagues"},
      {"Role", "Sub Only"}
    ]
  },
  # Men — 4.0
  # 7: Men's+Mixed
  %{
    name: "Greg Ingram",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Men's Leagues"},
      {"League Gender", "Mixed Leagues"}
    ]
  },
  # 8: Men's+Mixed
  %{
    name: "Hank Jones",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Men's Leagues"},
      {"League Gender", "Mixed Leagues"}
    ]
  },
  # 9: Men's+Mixed
  %{
    name: "Ian Knox",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Men's Leagues"},
      {"League Gender", "Mixed Leagues"}
    ]
  },
  # 10: Men's only
  %{
    name: "Jake Long",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"League Gender", "Men's Leagues"}]
  },
  # 11: Men's only
  %{
    name: "Kyle Moon",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"League Gender", "Men's Leagues"}]
  },
  # 12: Mixed only
  %{
    name: "Lars North",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"League Gender", "Mixed Leagues"}]
  },

  # Women — 3.5
  # 1: Women's+Mixed | Willing to Captain
  %{
    name: "Alice Brooks",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Women's Leagues"},
      {"League Gender", "Mixed Leagues"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 2: Women's+Mixed | Willing to Captain
  %{
    name: "Beth Clark",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Women's Leagues"},
      {"League Gender", "Mixed Leagues"},
      {"Role", "Willing to Captain"}
    ]
  },
  # 3: Women's+Mixed
  %{
    name: "Carol Dunn",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Women's Leagues"},
      {"League Gender", "Mixed Leagues"}
    ]
  },
  # 4: Women's only
  %{
    name: "Diana Earl",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"League Gender", "Women's Leagues"}]
  },
  # 5: Women's only
  %{
    name: "Elena Ford",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"League Gender", "Women's Leagues"}]
  },
  # 6: Mixed only | Sub Only
  %{
    name: "Fiona Gray",
    ntrp: "3.5",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Mixed Leagues"},
      {"Role", "Sub Only"}
    ]
  },
  # Women — 4.0
  # 7: Women's+Mixed
  %{
    name: "Grace Hart",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Women's Leagues"},
      {"League Gender", "Mixed Leagues"}
    ]
  },
  # 8: Women's+Mixed
  %{
    name: "Helen Irwin",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Women's Leagues"},
      {"League Gender", "Mixed Leagues"}
    ]
  },
  # 9: Women's+Mixed
  %{
    name: "Iris James",
    ntrp: "4.0",
    tags: [
      {"Age Group", "18+"},
      {"League Gender", "Women's Leagues"},
      {"League Gender", "Mixed Leagues"}
    ]
  },
  # 10: Women's only
  %{
    name: "Jane Kelly",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"League Gender", "Women's Leagues"}]
  },
  # 11: Women's only
  %{
    name: "Kate Lane",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"League Gender", "Women's Leagues"}]
  },
  # 12: Mixed only
  %{
    name: "Lisa Moon",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"League Gender", "Mixed Leagues"}]
  }
]

mixed_players = Enum.map(mixed_player_defs, &upsert_player.(&1, mixed_tenant))

IO.puts("Mixed group: #{length(mixed_players)} players seeded.")

# Assign tags to Mixed players
Enum.zip(mixed_player_defs, mixed_players)
|> Enum.each(fn {def, player} ->
  Enum.each(def.tags, fn {category_name, tag_name} ->
    tag = find_tag.(mixed_tenant, category_name, tag_name)
    if tag, do: upsert_player_tag.(player, tag, mixed_tenant)
  end)
end)

IO.puts("Mixed group: player tags assigned.")

# ==============================================================================
# Main Group: Matches
# 4-6 matches per team, spread across past and upcoming dates
# ==============================================================================

upsert_match = fn attrs, tenant ->
  existing =
    Match
    |> Ash.Query.filter(
      team_id == ^attrs.team_id and match_start_datetime == ^attrs.match_start_datetime
    )
    |> Ash.read_one(domain: Tennis, tenant: tenant, authorize?: false)

  case existing do
    {:ok, %Match{} = m} ->
      m

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

# Opponents for Main group matches
main_opponents_45 = ["Westside 4.5", "Millard 4.5", "Ralston 4.5", "Benson 4.5", "Papillion 4.5"]

main_opponents_40 = [
  "Westside 4.0",
  "Millard 4.0",
  "Ralston 4.0",
  "Benson 4.0",
  "Papillion 4.0",
  "Bellevue 4.0"
]

main_opponents_35 = [
  "Westside 3.5",
  "Millard 3.5",
  "Ralston 3.5",
  "Benson 3.5",
  "Papillion 3.5",
  "Bellevue 3.5"
]

today = DateTime.utc_now()

# Helper: build a UTC datetime N weeks from today at a given hour
weeks_from_today = fn weeks, hour ->
  today
  |> DateTime.add(weeks * 7 * 24 * 60 * 60, :second)
  |> Map.put(:hour, hour)
  |> Map.put(:minute, 0)
  |> Map.put(:second, 0)
  |> Map.put(:microsecond, {0, 0})
end

# --- Main 18+ 4.5 (5 matches: 2 past, 3 upcoming) ---
[
  %{opponent: Enum.at(main_opponents_45, 0), home_or_away: :home, offset: -6, loc: main_loc_1},
  %{opponent: Enum.at(main_opponents_45, 1), home_or_away: :away, offset: -3, loc: nil},
  %{opponent: Enum.at(main_opponents_45, 2), home_or_away: :home, offset: 1, loc: main_loc_1},
  %{opponent: Enum.at(main_opponents_45, 3), home_or_away: :away, offset: 3, loc: nil},
  %{opponent: Enum.at(main_opponents_45, 4), home_or_away: :home, offset: 5, loc: main_loc_2}
]
|> Enum.each(fn %{opponent: opp, home_or_away: h, offset: w, loc: loc} ->
  upsert_match.(
    %{
      team_id: main_team_18_45.id,
      opponent: opp,
      home_or_away: h,
      match_start_datetime: weeks_from_today.(w, 18),
      duration_minutes: 90,
      timezone: "America/Chicago",
      location_id: loc && loc.id
    },
    main_tenant
  )
end)

# --- Main 18+ 4.0 A (5 matches: 2 past, 3 upcoming) ---
[
  %{opponent: Enum.at(main_opponents_40, 0), home_or_away: :away, offset: -5, loc: nil},
  %{opponent: Enum.at(main_opponents_40, 1), home_or_away: :home, offset: -2, loc: main_loc_2},
  %{opponent: Enum.at(main_opponents_40, 2), home_or_away: :home, offset: 1, loc: main_loc_2},
  %{opponent: Enum.at(main_opponents_40, 3), home_or_away: :away, offset: 3, loc: nil},
  %{opponent: Enum.at(main_opponents_40, 4), home_or_away: :home, offset: 6, loc: main_loc_1}
]
|> Enum.each(fn %{opponent: opp, home_or_away: h, offset: w, loc: loc} ->
  upsert_match.(
    %{
      team_id: main_team_18_40_a.id,
      opponent: opp,
      home_or_away: h,
      match_start_datetime: weeks_from_today.(w, 18),
      duration_minutes: 90,
      timezone: "America/Chicago",
      location_id: loc && loc.id
    },
    main_tenant
  )
end)

# --- Main 18+ 4.0 B (5 matches: 2 past, 3 upcoming) ---
[
  %{opponent: Enum.at(main_opponents_40, 1), home_or_away: :home, offset: -5, loc: main_loc_1},
  %{opponent: Enum.at(main_opponents_40, 2), home_or_away: :away, offset: -2, loc: nil},
  %{opponent: Enum.at(main_opponents_40, 3), home_or_away: :home, offset: 2, loc: main_loc_1},
  %{opponent: Enum.at(main_opponents_40, 4), home_or_away: :away, offset: 4, loc: nil},
  %{opponent: Enum.at(main_opponents_40, 5), home_or_away: :home, offset: 7, loc: main_loc_2}
]
|> Enum.each(fn %{opponent: opp, home_or_away: h, offset: w, loc: loc} ->
  upsert_match.(
    %{
      team_id: main_team_18_40_b.id,
      opponent: opp,
      home_or_away: h,
      match_start_datetime: weeks_from_today.(w, 18),
      duration_minutes: 90,
      timezone: "America/Chicago",
      location_id: loc && loc.id
    },
    main_tenant
  )
end)

# --- Main 18+ 3.5 A (5 matches: 2 past, 3 upcoming) ---
[
  %{opponent: Enum.at(main_opponents_35, 0), home_or_away: :home, offset: -6, loc: main_loc_2},
  %{opponent: Enum.at(main_opponents_35, 1), home_or_away: :away, offset: -3, loc: nil},
  %{opponent: Enum.at(main_opponents_35, 2), home_or_away: :away, offset: 1, loc: nil},
  %{opponent: Enum.at(main_opponents_35, 3), home_or_away: :home, offset: 4, loc: main_loc_1},
  %{opponent: Enum.at(main_opponents_35, 4), home_or_away: :home, offset: 6, loc: main_loc_2}
]
|> Enum.each(fn %{opponent: opp, home_or_away: h, offset: w, loc: loc} ->
  upsert_match.(
    %{
      team_id: main_team_18_35_a.id,
      opponent: opp,
      home_or_away: h,
      match_start_datetime: weeks_from_today.(w, 18),
      duration_minutes: 90,
      timezone: "America/Chicago",
      location_id: loc && loc.id
    },
    main_tenant
  )
end)

# --- Main 18+ 3.5 B (5 matches: 2 past, 3 upcoming) ---
[
  %{opponent: Enum.at(main_opponents_35, 1), home_or_away: :away, offset: -4, loc: nil},
  %{opponent: Enum.at(main_opponents_35, 2), home_or_away: :home, offset: -1, loc: main_loc_1},
  %{opponent: Enum.at(main_opponents_35, 3), home_or_away: :home, offset: 2, loc: main_loc_1},
  %{opponent: Enum.at(main_opponents_35, 4), home_or_away: :away, offset: 5, loc: nil},
  %{opponent: Enum.at(main_opponents_35, 5), home_or_away: :home, offset: 7, loc: main_loc_2}
]
|> Enum.each(fn %{opponent: opp, home_or_away: h, offset: w, loc: loc} ->
  upsert_match.(
    %{
      team_id: main_team_18_35_b.id,
      opponent: opp,
      home_or_away: h,
      match_start_datetime: weeks_from_today.(w, 18),
      duration_minutes: 90,
      timezone: "America/Chicago",
      location_id: loc && loc.id
    },
    main_tenant
  )
end)

# --- Main 40+ 3.5 (4 matches: 1 past, 3 upcoming) ---
[
  %{opponent: Enum.at(main_opponents_35, 0), home_or_away: :away, offset: -3, loc: nil},
  %{opponent: Enum.at(main_opponents_35, 2), home_or_away: :home, offset: 2, loc: main_loc_1},
  %{opponent: Enum.at(main_opponents_35, 3), home_or_away: :away, offset: 4, loc: nil},
  %{opponent: Enum.at(main_opponents_35, 4), home_or_away: :home, offset: 6, loc: main_loc_2}
]
|> Enum.each(fn %{opponent: opp, home_or_away: h, offset: w, loc: loc} ->
  upsert_match.(
    %{
      team_id: main_team_40_35.id,
      opponent: opp,
      home_or_away: h,
      match_start_datetime: weeks_from_today.(w, 18),
      duration_minutes: 90,
      timezone: "America/Chicago",
      location_id: loc && loc.id
    },
    main_tenant
  )
end)

IO.puts("Main group: matches seeded.")

# ==============================================================================
# Main Group: Roster Planning Sessions
# One pseudo-team per team-type/year creates the planning session context.
# Also seed a few unassigned players at each NTRP level.
# ==============================================================================

# Ensure pseudo-teams (planning sessions) exist for every Main group division
Tennis.ensure_pseudo_team(main_tt_18_45.id, current_year,
  tenant: main_tenant,
  actor: mainowner_user
)

Tennis.ensure_pseudo_team(main_tt_18_40.id, current_year,
  tenant: main_tenant,
  actor: mainowner_user
)

Tennis.ensure_pseudo_team(main_tt_18_35.id, current_year,
  tenant: main_tenant,
  actor: mainowner_user
)

Tennis.ensure_pseudo_team(main_tt_40_35.id, current_year,
  tenant: main_tenant,
  actor: mainowner_user
)

IO.puts("Main group: roster planning sessions created.")

# Unassigned players — created but not assigned to any team
# 3 at 4.5, 3 at 4.0, 3 at 3.5
unassigned_player_defs = [
  %{name: "Pat Nolan", ntrp: "4.5", tags: [{"Age Group", "18+"}]},
  %{
    name: "Quinn Orr",
    ntrp: "4.5",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  %{
    name: "Ross Penn",
    ntrp: "4.5",
    tags: [{"Age Group", "18+"}, {"Role", "Prospect"}]
  },
  %{name: "Sam Quinn", ntrp: "4.0", tags: [{"Age Group", "18+"}]},
  %{
    name: "Trey Reid",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  %{
    name: "Ulf Stone",
    ntrp: "4.0",
    tags: [{"Age Group", "18+"}, {"Role", "Prospect"}]
  },
  %{name: "Vern Tate", ntrp: "3.5", tags: [{"Age Group", "18+"}]},
  %{
    name: "Wade Uhl",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"Age Group", "40+"}]
  },
  %{
    name: "Xen Voss",
    ntrp: "3.5",
    tags: [{"Age Group", "18+"}, {"Role", "Prospect"}]
  }
]

unassigned_players = Enum.map(unassigned_player_defs, &upsert_player.(&1, main_tenant))

Enum.zip(unassigned_player_defs, unassigned_players)
|> Enum.each(fn {def, player} ->
  Enum.each(def.tags, fn {category_name, tag_name} ->
    tag = find_tag.(main_tenant, category_name, tag_name)
    if tag, do: upsert_player_tag.(player, tag, main_tenant)
  end)
end)

IO.puts("Main group: #{length(unassigned_players)} unassigned players seeded.")

# ==============================================================================
# Mixed Group: Roster Planning Sessions
# Mixed group has no real teams, so no planning sessions needed.
# ==============================================================================

IO.puts("Seeds complete!")
