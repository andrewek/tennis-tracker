defmodule TennisTracker.Tennis.ListRealTeamsTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp create_team_type(attrs \\ %{}) do
    defaults = %{
      name: "18+ 3.5",
      age_group: "18_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    }

    Tennis.create_team_type!(Map.merge(defaults, attrs))
  end

  defp create_team(team_type, attrs) do
    defaults = %{
      name: "Test Team",
      team_type_id: team_type.id,
      season_year: 2026,
      is_pseudo: false
    }

    Tennis.create_team!(Map.merge(defaults, attrs))
  end

  # ---------------------------------------------------------------------------
  # list_real_teams!/1 — filter tests
  # ---------------------------------------------------------------------------

  describe "list_real_teams!/1 filter" do
    test "returns real teams" do
      tt = create_team_type()
      team = create_team(tt, %{name: "Alpha"})

      results = Tennis.list_real_teams!()
      ids = Enum.map(results, & &1.id)

      assert team.id in ids
    end

    test "excludes pseudo-teams" do
      tt = create_team_type()
      _pseudo = create_team(tt, %{name: "Not Participating", is_pseudo: true})
      real = create_team(tt, %{name: "Real Team"})

      results = Tennis.list_real_teams!()
      ids = Enum.map(results, & &1.id)

      assert real.id in ids
      refute Enum.any?(results, & &1.is_pseudo)
    end

    test "loads team_type_name, team_type_age_group, team_type_ntrp_level calculations" do
      tt =
        create_team_type(%{name: "18+ 3.5", age_group: "18_plus", ntrp_level: Decimal.new("3.5")})

      create_team(tt, %{name: "Alpha"})

      [team] =
        Tennis.list_real_teams!(
          load: [:team_type_name, :team_type_age_group, :team_type_ntrp_level]
        )

      assert team.team_type_name == "18+ 3.5"
      assert team.team_type_age_group == "18_plus"
      assert Decimal.equal?(team.team_type_ntrp_level, Decimal.new("3.5"))
    end
  end

  # ---------------------------------------------------------------------------
  # list_real_teams!/1 — sort tests
  # ---------------------------------------------------------------------------

  describe "list_real_teams!/1 sort order" do
    test "sorts by season_year descending" do
      tt = create_team_type()
      older = create_team(tt, %{name: "Older", season_year: 2024})
      newer = create_team(tt, %{name: "Newer", season_year: 2026})

      results = Tennis.list_real_teams!()
      ids = Enum.map(results, & &1.id)

      assert Enum.find_index(ids, &(&1 == newer.id)) <
               Enum.find_index(ids, &(&1 == older.id))
    end

    test "within same year, sorts by age_group ascending (nils last)" do
      tt_18 =
        create_team_type(%{
          name: "18+ 3.5",
          age_group: "18_plus",
          ntrp_level: Decimal.new("3.5"),
          allowed_ntrp_levels: [Decimal.new("3.5")]
        })

      tt_40 =
        create_team_type(%{
          name: "40+ 3.5",
          age_group: "40_plus",
          ntrp_level: Decimal.new("3.5"),
          allowed_ntrp_levels: [Decimal.new("3.5")]
        })

      team_40 = create_team(tt_40, %{name: "40+ Team", season_year: 2026})
      team_18 = create_team(tt_18, %{name: "18+ Team", season_year: 2026})

      results = Tennis.list_real_teams!()
      ids = Enum.map(results, & &1.id)

      # "18_plus" < "40_plus" alphabetically → 18+ team comes first
      assert Enum.find_index(ids, &(&1 == team_18.id)) <
               Enum.find_index(ids, &(&1 == team_40.id))
    end

    test "within same year and age_group, sorts by ntrp_level descending (nils last)" do
      tt_high =
        create_team_type(%{
          name: "18+ 4.0",
          age_group: "18_plus",
          ntrp_level: Decimal.new("4.0"),
          allowed_ntrp_levels: [Decimal.new("4.0")]
        })

      tt_low =
        create_team_type(%{
          name: "18+ 3.0",
          age_group: "18_plus",
          ntrp_level: Decimal.new("3.0"),
          allowed_ntrp_levels: [Decimal.new("3.0")]
        })

      team_low = create_team(tt_low, %{name: "3.0 Team", season_year: 2026})
      team_high = create_team(tt_high, %{name: "4.0 Team", season_year: 2026})

      results = Tennis.list_real_teams!()
      ids = Enum.map(results, & &1.id)

      # Higher NTRP comes first (desc)
      assert Enum.find_index(ids, &(&1 == team_high.id)) <
               Enum.find_index(ids, &(&1 == team_low.id))
    end

    test "within same year, age_group, and ntrp_level, sorts by name ascending" do
      tt = create_team_type()
      team_b = create_team(tt, %{name: "Beta"})
      team_a = create_team(tt, %{name: "Alpha"})

      results = Tennis.list_real_teams!()
      ids = Enum.map(results, & &1.id)

      assert Enum.find_index(ids, &(&1 == team_a.id)) <
               Enum.find_index(ids, &(&1 == team_b.id))
    end
  end
end
