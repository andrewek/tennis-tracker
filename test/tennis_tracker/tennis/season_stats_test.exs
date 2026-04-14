defmodule TennisTracker.Tennis.SeasonStatsTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{group: grp, user: _usr} do
    team = Factory.team(group: grp)
    player = Factory.player(group: grp)
    Factory.team_membership(group: grp, team: team, player: player)

    [reserve_col] =
      Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, authorize?: false)

    playing_slot =
      Tennis.create_lineup_slot!(
        %{
          name: "S1",
          participation_type: :playing,
          team_id: team.id,
          group_id: grp.id,
          team_lineup_column_id: reserve_col.id
        },
        tenant: grp.id,
        authorize?: false
      )

    [out_slot] =
      Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
      |> Enum.filter(&(&1.participation_type == :out))

    neutral_slot =
      Tennis.create_lineup_slot!(
        %{
          name: "Beer",
          participation_type: :neutral,
          team_id: team.id,
          group_id: grp.id,
          team_lineup_column_id: reserve_col.id
        },
        tenant: grp.id,
        authorize?: false
      )

    {:ok,
     team: team,
     player: player,
     playing_slot: playing_slot,
     out_slot: out_slot,
     neutral_slot: neutral_slot,
     reserve_col: reserve_col}
  end

  defp past_match(grp, team) do
    Factory.match(
      group: grp,
      team: team,
      match_start_datetime:
        DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second)
    )
  end

  defp future_match(grp, team) do
    Factory.match(group: grp, team: team)
  end

  defp assign!(match, player, slot, grp, usr) do
    {:ok, _} = Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)
  end

  defp load_matches(team, grp, usr) do
    Tennis.list_all_matches_for_team!(team.id, tenant: grp.id, actor: usr)
  end

  # ---------------------------------------------------------------------------

  describe "season_stats_for_team!" do
    test "player with only past playing assignments → correct played_past, zero others", %{
      group: grp,
      user: usr,
      team: team,
      player: player,
      playing_slot: playing_slot
    } do
      match = past_match(grp, team)
      assign!(match, player, playing_slot, grp, usr)

      all_matches = load_matches(team, grp, usr)

      %{by_player: by_player} =
        Tennis.season_stats_for_team!(team.id, all_matches, tenant: grp.id, actor: usr)

      stats = Map.fetch!(by_player, player.id)
      assert stats.played_past == 1
      assert stats.played_future == 0
      assert stats.out == 0
      assert stats.neutral == %{}
    end

    test "player with only future playing assignments → correct played_future, zero others", %{
      group: grp,
      user: usr,
      team: team,
      player: player,
      playing_slot: playing_slot
    } do
      match = future_match(grp, team)
      assign!(match, player, playing_slot, grp, usr)

      all_matches = load_matches(team, grp, usr)

      %{by_player: by_player} =
        Tennis.season_stats_for_team!(team.id, all_matches, tenant: grp.id, actor: usr)

      stats = Map.fetch!(by_player, player.id)
      assert stats.played_past == 0
      assert stats.played_future == 1
      assert stats.out == 0
    end

    test "player with out assignments → correct out count, not reflected in played counts", %{
      group: grp,
      user: usr,
      team: team,
      player: player,
      out_slot: out_slot
    } do
      past = past_match(grp, team)
      future = future_match(grp, team)
      assign!(past, player, out_slot, grp, usr)
      assign!(future, player, out_slot, grp, usr)

      all_matches = load_matches(team, grp, usr)

      %{by_player: by_player} =
        Tennis.season_stats_for_team!(team.id, all_matches, tenant: grp.id, actor: usr)

      stats = Map.fetch!(by_player, player.id)
      assert stats.out == 2
      assert stats.played_past == 0
      assert stats.played_future == 0
    end

    test "player with neutral slot assignments → appears in neutral map, not in played counts", %{
      group: grp,
      user: usr,
      team: team,
      player: player,
      neutral_slot: neutral_slot
    } do
      match = past_match(grp, team)
      assign!(match, player, neutral_slot, grp, usr)

      all_matches = load_matches(team, grp, usr)

      %{by_player: by_player} =
        Tennis.season_stats_for_team!(team.id, all_matches, tenant: grp.id, actor: usr)

      stats = Map.fetch!(by_player, player.id)
      assert stats.neutral == %{"Beer" => 1}
      assert stats.played_past == 0
      assert stats.played_future == 0
    end

    test "player with mix of past playing + future out + neutral → all counts correct", %{
      group: grp,
      user: usr,
      team: team,
      player: player,
      playing_slot: playing_slot,
      out_slot: out_slot,
      neutral_slot: neutral_slot
    } do
      past = past_match(grp, team)
      future = future_match(grp, team)
      neutral_match = past_match(grp, team)

      assign!(past, player, playing_slot, grp, usr)
      assign!(future, player, out_slot, grp, usr)
      assign!(neutral_match, player, neutral_slot, grp, usr)

      all_matches = load_matches(team, grp, usr)

      %{by_player: by_player} =
        Tennis.season_stats_for_team!(team.id, all_matches, tenant: grp.id, actor: usr)

      stats = Map.fetch!(by_player, player.id)
      assert stats.played_past == 1
      assert stats.played_future == 0
      assert stats.out == 1
      assert stats.neutral == %{"Beer" => 1}
    end

    test "player with assignments at multiple neutral slots → both slots tracked", %{
      group: grp,
      user: usr,
      team: team,
      player: player,
      reserve_col: reserve_col,
      neutral_slot: neutral_slot
    } do
      snack_slot =
        Tennis.create_lineup_slot!(
          %{
            name: "Snack",
            participation_type: :neutral,
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          authorize?: false
        )

      match1 = past_match(grp, team)
      match2 = past_match(grp, team)
      assign!(match1, player, neutral_slot, grp, usr)
      assign!(match2, player, snack_slot, grp, usr)

      all_matches = load_matches(team, grp, usr)

      %{by_player: by_player} =
        Tennis.season_stats_for_team!(team.id, all_matches, tenant: grp.id, actor: usr)

      stats = Map.fetch!(by_player, player.id)
      assert stats.neutral == %{"Beer" => 1, "Snack" => 1}
    end

    test "player with no assignments at all → absent from by_player", %{
      group: grp,
      user: usr,
      team: team,
      player: player
    } do
      _match = future_match(grp, team)

      all_matches = load_matches(team, grp, usr)

      %{by_player: by_player} =
        Tennis.season_stats_for_team!(team.id, all_matches, tenant: grp.id, actor: usr)

      refute Map.has_key?(by_player, player.id)
    end

    test "total_matches equals count of all matches for team regardless of assignments", %{
      group: grp,
      user: usr,
      team: team
    } do
      future_match(grp, team)
      future_match(grp, team)
      future_match(grp, team)

      all_matches = load_matches(team, grp, usr)

      %{total_matches: total_matches} =
        Tennis.season_stats_for_team!(team.id, all_matches, tenant: grp.id, actor: usr)

      assert total_matches == 3
    end

    test "stats scoped to team_id — other team assignments not counted", %{
      group: grp,
      user: usr,
      team: team,
      player: player,
      playing_slot: playing_slot
    } do
      # Create a second team with a match and assign the same player there
      team2 = Factory.team(group: grp)
      Factory.team_membership(group: grp, team: team2, player: player)

      [col2] = Tennis.list_lineup_columns_for_team!(team2.id, tenant: grp.id, authorize?: false)

      slot2 =
        Tennis.create_lineup_slot!(
          %{name: "S1", team_id: team2.id, group_id: grp.id, team_lineup_column_id: col2.id},
          tenant: grp.id,
          authorize?: false
        )

      match2 = future_match(grp, team2)
      {:ok, _} = Tennis.assign_to_slot(match2.id, player.id, slot2.id, tenant: grp.id, actor: usr)

      # Assign to team1's match too
      match1 = future_match(grp, team)
      assign!(match1, player, playing_slot, grp, usr)

      all_matches = load_matches(team, grp, usr)

      %{by_player: by_player} =
        Tennis.season_stats_for_team!(team.id, all_matches, tenant: grp.id, actor: usr)

      stats = Map.fetch!(by_player, player.id)
      assert stats.played_future == 1
    end
  end
end
