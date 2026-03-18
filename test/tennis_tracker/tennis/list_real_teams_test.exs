defmodule TennisTracker.Tennis.ListRealTeamsTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group

  # ---------------------------------------------------------------------------
  # list_real_teams!/1 — filter tests
  # ---------------------------------------------------------------------------

  describe "list_real_teams!/1 filter" do
    test "returns real teams", %{group: grp, user: usr} do
      team = Factory.team(group: grp, name: "Alpha")

      results = Tennis.list_real_teams!(tenant: grp.id, actor: usr)
      ids = Enum.map(results, & &1.id)

      assert team.id in ids
    end

    test "excludes pseudo-teams", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)

      _pseudo =
        Factory.team(group: grp, team_type: tt, name: "Not Participating", traits: [:pseudo])

      real = Factory.team(group: grp, team_type: tt, name: "Real Team")

      results = Tennis.list_real_teams!(tenant: grp.id, actor: usr)
      ids = Enum.map(results, & &1.id)

      assert real.id in ids
      refute Enum.any?(results, & &1.is_pseudo)
    end

    test "loads team_type_name, team_type_age_group, team_type_ntrp_level calculations", %{
      group: grp,
      user: usr
    } do
      tt =
        Factory.team_type(
          group: grp,
          name: "18+ 3.5",
          age_group: "18_plus",
          ntrp_level: Decimal.new("3.5")
        )

      Factory.team(group: grp, team_type: tt, name: "Alpha")

      [team] =
        Tennis.list_real_teams!(
          load: [:team_type_name, :team_type_age_group, :team_type_ntrp_level],
          tenant: grp.id,
          actor: usr
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
    test "sorts by season_year descending", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      older = Factory.team(group: grp, team_type: tt, name: "Older", season_year: 2024)
      newer = Factory.team(group: grp, team_type: tt, name: "Newer", season_year: 2026)

      results = Tennis.list_real_teams!(tenant: grp.id, actor: usr)
      ids = Enum.map(results, & &1.id)

      assert Enum.find_index(ids, &(&1 == newer.id)) <
               Enum.find_index(ids, &(&1 == older.id))
    end

    test "within same year, sorts by age_group ascending (nils last)", %{group: grp, user: usr} do
      tt_18 =
        Factory.team_type(
          group: grp,
          name: "18+ 3.5",
          age_group: "18_plus",
          ntrp_level: Decimal.new("3.5"),
          allowed_ntrp_levels: [Decimal.new("3.5")]
        )

      tt_40 =
        Factory.team_type(
          group: grp,
          name: "40+ 3.5",
          age_group: "40_plus",
          ntrp_level: Decimal.new("3.5"),
          allowed_ntrp_levels: [Decimal.new("3.5")]
        )

      team_40 = Factory.team(group: grp, team_type: tt_40, name: "40+ Team", season_year: 2026)
      team_18 = Factory.team(group: grp, team_type: tt_18, name: "18+ Team", season_year: 2026)

      results = Tennis.list_real_teams!(tenant: grp.id, actor: usr)
      ids = Enum.map(results, & &1.id)

      # "18_plus" < "40_plus" alphabetically → 18+ team comes first
      assert Enum.find_index(ids, &(&1 == team_18.id)) <
               Enum.find_index(ids, &(&1 == team_40.id))
    end

    test "within same year and age_group, sorts by ntrp_level descending (nils last)", %{
      group: grp,
      user: usr
    } do
      tt_high =
        Factory.team_type(
          group: grp,
          name: "18+ 4.0",
          age_group: "18_plus",
          ntrp_level: Decimal.new("4.0"),
          allowed_ntrp_levels: [Decimal.new("4.0")]
        )

      tt_low =
        Factory.team_type(
          group: grp,
          name: "18+ 3.0",
          age_group: "18_plus",
          ntrp_level: Decimal.new("3.0"),
          allowed_ntrp_levels: [Decimal.new("3.0")]
        )

      team_low = Factory.team(group: grp, team_type: tt_low, name: "3.0 Team", season_year: 2026)

      team_high =
        Factory.team(group: grp, team_type: tt_high, name: "4.0 Team", season_year: 2026)

      results = Tennis.list_real_teams!(tenant: grp.id, actor: usr)
      ids = Enum.map(results, & &1.id)

      # Higher NTRP comes first (desc)
      assert Enum.find_index(ids, &(&1 == team_high.id)) <
               Enum.find_index(ids, &(&1 == team_low.id))
    end

    test "within same year, age_group, and ntrp_level, sorts by name ascending", %{
      group: grp,
      user: usr
    } do
      tt = Factory.team_type(group: grp)
      team_b = Factory.team(group: grp, team_type: tt, name: "Beta")
      team_a = Factory.team(group: grp, team_type: tt, name: "Alpha")

      results = Tennis.list_real_teams!(tenant: grp.id, actor: usr)
      ids = Enum.map(results, & &1.id)

      assert Enum.find_index(ids, &(&1 == team_a.id)) <
               Enum.find_index(ids, &(&1 == team_b.id))
    end
  end
end
