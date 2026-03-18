defmodule TennisTracker.Tennis.TeamRosterTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  # ---------------------------------------------------------------------------
  # TeamType
  # ---------------------------------------------------------------------------

  describe "TeamType" do
    test "creates successfully with valid attributes", %{group: grp, user: _usr} do
      team_type =
        Factory.team_type(
          group: grp,
          name: "40+ 4.0",
          age_group: "40_plus",
          ntrp_level: Decimal.new("4.0"),
          allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]
        )

      assert team_type.name == "40+ 4.0"
      assert team_type.age_group == "40_plus"
    end

    test "list_team_types returns all team types", %{group: grp, user: usr} do
      Factory.team_type(group: grp, name: "Type A")
      Factory.team_type(group: grp, name: "Type B")
      types = Tennis.list_team_types!(tenant: grp.id, actor: usr)
      names = Enum.map(types, & &1.name)
      assert "Type A" in names
      assert "Type B" in names
    end
  end

  # ---------------------------------------------------------------------------
  # SeasonRules uniqueness
  # ---------------------------------------------------------------------------

  describe "SeasonRules uniqueness" do
    test "creates season rules for a team type and year", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)

      assert {:ok, rules} =
               Tennis.create_season_rules(
                 %{
                   team_type_id: tt.id,
                   season_year: 2026,
                   min_roster: 8,
                   max_roster: 18,
                   on_level_min_pct: Decimal.new("0.60"),
                   group_id: grp.id
                 }, tenant: grp.id, actor: usr)

      assert rules.season_year == 2026
      assert rules.min_roster == 8
    end

    test "cannot create duplicate rules for same team type and year", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)

      Tennis.create_season_rules!(
        %{
          team_type_id: tt.id,
          season_year: 2026,
          min_roster: 8,
          max_roster: 18,
          on_level_min_pct: Decimal.new("0.60"),
          group_id: grp.id
        }, tenant: grp.id, actor: usr)

      assert {:error, _} =
               Tennis.create_season_rules(
                 %{
                   team_type_id: tt.id,
                   season_year: 2026,
                   min_roster: 10,
                   max_roster: 15,
                   on_level_min_pct: Decimal.new("0.50"),
                   group_id: grp.id
                 }, tenant: grp.id, actor: usr)
    end

    test "can create rules for same team type in different years", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)

      Tennis.create_season_rules!(
        %{
          team_type_id: tt.id,
          season_year: 2025,
          min_roster: 8,
          max_roster: 18,
          on_level_min_pct: Decimal.new("0.60"),
          group_id: grp.id
        }, tenant: grp.id, actor: usr)

      assert {:ok, _} =
               Tennis.create_season_rules(
                 %{
                   team_type_id: tt.id,
                   season_year: 2026,
                   min_roster: 10,
                   max_roster: 18,
                   on_level_min_pct: Decimal.new("0.60"),
                   group_id: grp.id
                 }, tenant: grp.id, actor: usr)
    end
  end

  # ---------------------------------------------------------------------------
  # TeamMembership uniqueness
  # ---------------------------------------------------------------------------

  describe "TeamMembership uniqueness" do
    test "player can join a team", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      team = Factory.team(group: grp, team_type: tt)
      player = Factory.player(group: grp)

      assert {:ok, _} =
               Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
                 tenant: grp.id,
                 actor: usr
               )
    end

    test "player cannot join two teams of the same type in the same season", %{
      group: grp,
      user: usr
    } do
      tt = Factory.team_type(group: grp)
      team_a = Factory.team(group: grp, team_type: tt, name: "Team A")
      team_b = Factory.team(group: grp, team_type: tt, name: "Team B")
      player = Factory.player(group: grp)

      Tennis.assign_player(player.id, team_a.id, tt.id, team_a.season_year,
        tenant: grp.id,
        actor: usr
      )

      # assign_player is an upsert — it moves the player, not creates a duplicate
      # To test the uniqueness constraint directly, use create_team_membership
      assert {:error, _} =
               Tennis.create_team_membership(
                 %{
                   player_id: player.id,
                   team_id: team_b.id,
                   team_type_id: tt.id,
                   season_year: team_b.season_year,
                   group_id: grp.id
                 }, tenant: grp.id, actor: usr)
    end

    test "player can join teams of different types in the same season", %{group: grp, user: usr} do
      tt_35 = Factory.team_type(group: grp, traits: [:_35], name: "18+ 3.5")
      tt_40 = Factory.team_type(group: grp, traits: [:_40], name: "18+ 4.0")

      team_35 = Factory.team(group: grp, team_type: tt_35)
      team_40 = Factory.team(group: grp, team_type: tt_40)
      player = Factory.player(group: grp)

      Tennis.assign_player(player.id, team_35.id, tt_35.id, team_35.season_year,
        tenant: grp.id,
        actor: usr
      )

      assert {:ok, _} =
               Tennis.assign_player(player.id, team_40.id, tt_40.id, team_40.season_year,
                 tenant: grp.id,
                 actor: usr
               )
    end
  end

  # ---------------------------------------------------------------------------
  # ensure_pseudo_team
  # ---------------------------------------------------------------------------

  describe "ensure_pseudo_team/2" do
    test "creates pseudo team if none exists", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      assert {:ok, team} = Tennis.ensure_pseudo_team(tt.id, 2026, tenant: grp.id, actor: usr)
      assert team.is_pseudo == true
      assert team.name == "Not Participating"
    end

    test "returns existing pseudo team if already created", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      {:ok, first} = Tennis.ensure_pseudo_team(tt.id, 2026, tenant: grp.id, actor: usr)
      {:ok, second} = Tennis.ensure_pseudo_team(tt.id, 2026, tenant: grp.id, actor: usr)
      assert first.id == second.id
    end
  end

  # ---------------------------------------------------------------------------
  # assign_player / unassign_player
  # ---------------------------------------------------------------------------

  describe "assign_player/4 and unassign_player/3" do
    test "assigns a player to a team", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      team = Factory.team(group: grp, team_type: tt)
      player = Factory.player(group: grp)

      assert {:ok, membership} =
               Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
                 tenant: grp.id,
                 actor: usr
               )

      assert membership.team_id == team.id
      assert membership.player_id == player.id
    end

    test "reassigning a player moves them to the new team", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      team_a = Factory.team(group: grp, team_type: tt, name: "Team A")
      team_b = Factory.team(group: grp, team_type: tt, name: "Team B")
      player = Factory.player(group: grp)

      Tennis.assign_player(player.id, team_a.id, tt.id, team_a.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, membership} =
        Tennis.assign_player(player.id, team_b.id, tt.id, team_b.season_year,
          tenant: grp.id,
          actor: usr
        )

      assert membership.team_id == team_b.id
    end

    test "unassign_player removes the membership", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      team = Factory.team(group: grp, team_type: tt)
      player = Factory.player(group: grp)

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      Tennis.unassign_player(player.id, tt.id, team.season_year, tenant: grp.id, actor: usr)

      {:ok, memberships} =
        Tennis.list_memberships_for_context(tt.id, team.season_year, tenant: grp.id, actor: usr)

      assert Enum.empty?(memberships)
    end
  end
end
