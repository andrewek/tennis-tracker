defmodule TennisTracker.Tennis.TeamRosterTest do
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

  defp create_team(team_type, attrs \\ %{}) do
    defaults = %{
      name: "Test Team",
      team_type_id: team_type.id,
      season_year: 2026,
      is_pseudo: false
    }

    Tennis.create_team!(Map.merge(defaults, attrs))
  end

  defp create_player(attrs \\ %{}) do
    defaults = %{name: "Test Player", eligible_18_plus: true}
    Tennis.create_player!(Map.merge(defaults, attrs))
  end

  # ---------------------------------------------------------------------------
  # TeamType
  # ---------------------------------------------------------------------------

  describe "TeamType" do
    test "creates successfully with valid attributes" do
      team_type =
        create_team_type(%{
          name: "40+ 4.0",
          age_group: "40_plus",
          ntrp_level: Decimal.new("4.0"),
          allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]
        })

      assert team_type.name == "40+ 4.0"
      assert team_type.age_group == "40_plus"
    end

    test "list_team_types returns all team types" do
      create_team_type(%{name: "Type A"})
      create_team_type(%{name: "Type B"})
      types = Tennis.list_team_types!()
      names = Enum.map(types, & &1.name)
      assert "Type A" in names
      assert "Type B" in names
    end
  end

  # ---------------------------------------------------------------------------
  # SeasonRules uniqueness
  # ---------------------------------------------------------------------------

  describe "SeasonRules uniqueness" do
    test "creates season rules for a team type and year" do
      tt = create_team_type()

      assert {:ok, rules} =
               Tennis.create_season_rules(%{
                 team_type_id: tt.id,
                 season_year: 2026,
                 min_roster: 8,
                 max_roster: 18,
                 on_level_min_pct: Decimal.new("0.60")
               })

      assert rules.season_year == 2026
      assert rules.min_roster == 8
    end

    test "cannot create duplicate rules for same team type and year" do
      tt = create_team_type()

      Tennis.create_season_rules!(%{
        team_type_id: tt.id,
        season_year: 2026,
        min_roster: 8,
        max_roster: 18,
        on_level_min_pct: Decimal.new("0.60")
      })

      assert {:error, _} =
               Tennis.create_season_rules(%{
                 team_type_id: tt.id,
                 season_year: 2026,
                 min_roster: 10,
                 max_roster: 15,
                 on_level_min_pct: Decimal.new("0.50")
               })
    end

    test "can create rules for same team type in different years" do
      tt = create_team_type()

      Tennis.create_season_rules!(%{
        team_type_id: tt.id,
        season_year: 2025,
        min_roster: 8,
        max_roster: 18,
        on_level_min_pct: Decimal.new("0.60")
      })

      assert {:ok, _} =
               Tennis.create_season_rules(%{
                 team_type_id: tt.id,
                 season_year: 2026,
                 min_roster: 10,
                 max_roster: 18,
                 on_level_min_pct: Decimal.new("0.60")
               })
    end
  end

  # ---------------------------------------------------------------------------
  # TeamMembership uniqueness
  # ---------------------------------------------------------------------------

  describe "TeamMembership uniqueness" do
    test "player can join a team" do
      tt = create_team_type()
      team = create_team(tt)
      player = create_player()

      assert {:ok, _} =
               Tennis.create_team_membership(%{
                 player_id: player.id,
                 team_id: team.id,
                 team_type_id: tt.id,
                 season_year: 2026
               })
    end

    test "player cannot join two teams of the same type in the same season" do
      tt = create_team_type()
      team_a = create_team(tt, %{name: "Team A"})
      team_b = create_team(tt, %{name: "Team B"})
      player = create_player()

      Tennis.create_team_membership!(%{
        player_id: player.id,
        team_id: team_a.id,
        team_type_id: tt.id,
        season_year: 2026
      })

      assert {:error, _} =
               Tennis.create_team_membership(%{
                 player_id: player.id,
                 team_id: team_b.id,
                 team_type_id: tt.id,
                 season_year: 2026
               })
    end

    test "player can join teams of different types in the same season" do
      tt_35 =
        create_team_type(%{
          name: "18+ 3.5",
          ntrp_level: Decimal.new("3.5"),
          allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
        })

      tt_40 =
        create_team_type(%{
          name: "18+ 4.0",
          ntrp_level: Decimal.new("4.0"),
          allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]
        })

      team_35 = create_team(tt_35)
      team_40 = create_team(tt_40)
      player = create_player()

      Tennis.create_team_membership!(%{
        player_id: player.id,
        team_id: team_35.id,
        team_type_id: tt_35.id,
        season_year: 2026
      })

      assert {:ok, _} =
               Tennis.create_team_membership(%{
                 player_id: player.id,
                 team_id: team_40.id,
                 team_type_id: tt_40.id,
                 season_year: 2026
               })
    end
  end

  # ---------------------------------------------------------------------------
  # ensure_pseudo_team
  # ---------------------------------------------------------------------------

  describe "ensure_pseudo_team/2" do
    test "creates pseudo team if none exists" do
      tt = create_team_type()
      assert {:ok, team} = Tennis.ensure_pseudo_team(tt.id, 2026)
      assert team.is_pseudo == true
      assert team.name == "Not Participating"
    end

    test "returns existing pseudo team if already created" do
      tt = create_team_type()
      {:ok, first} = Tennis.ensure_pseudo_team(tt.id, 2026)
      {:ok, second} = Tennis.ensure_pseudo_team(tt.id, 2026)
      assert first.id == second.id
    end
  end

  # ---------------------------------------------------------------------------
  # assign_player / unassign_player
  # ---------------------------------------------------------------------------

  describe "assign_player/4 and unassign_player/3" do
    test "assigns a player to a team" do
      tt = create_team_type()
      team = create_team(tt)
      player = create_player()

      assert {:ok, membership} = Tennis.assign_player(player.id, team.id, tt.id, 2026)
      assert membership.team_id == team.id
      assert membership.player_id == player.id
    end

    test "reassigning a player moves them to the new team" do
      tt = create_team_type()
      team_a = create_team(tt, %{name: "Team A"})
      team_b = create_team(tt, %{name: "Team B"})
      player = create_player()

      Tennis.assign_player(player.id, team_a.id, tt.id, 2026)
      {:ok, membership} = Tennis.assign_player(player.id, team_b.id, tt.id, 2026)
      assert membership.team_id == team_b.id
    end

    test "unassign_player removes the membership" do
      tt = create_team_type()
      team = create_team(tt)
      player = create_player()

      Tennis.assign_player(player.id, team.id, tt.id, 2026)
      Tennis.unassign_player(player.id, tt.id, 2026)

      {:ok, memberships} = Tennis.list_memberships_for_context(tt.id, 2026)
      assert Enum.empty?(memberships)
    end
  end
end
