defmodule TennisTracker.Tennis.AssignmentModeTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{group: grp, user: usr} do
    team = Factory.team(group: grp)
    match = Factory.match(group: grp, team: team)
    player = Factory.player(group: grp)
    player2 = Factory.player(group: grp)

    reserve_col =
      Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, actor: usr)
      |> Enum.find(&(&1.name == "Reserve"))

    singles_col =
      Tennis.create_lineup_column!(
        %{name: "Singles", team_id: team.id, group_id: grp.id},
        tenant: grp.id,
        authorize?: false
      )

    doubles_col =
      Tennis.create_lineup_column!(
        %{name: "Doubles", team_id: team.id, group_id: grp.id},
        tenant: grp.id,
        authorize?: false
      )

    slot_s1 =
      Tennis.create_lineup_slot!(
        %{name: "S1", team_id: team.id, group_id: grp.id, team_lineup_column_id: singles_col.id},
        tenant: grp.id,
        authorize?: false
      )

    slot_s2 =
      Tennis.create_lineup_slot!(
        %{name: "S2", team_id: team.id, group_id: grp.id, team_lineup_column_id: singles_col.id},
        tenant: grp.id,
        authorize?: false
      )

    slot_d1 =
      Tennis.create_lineup_slot!(
        %{name: "D1", team_id: team.id, group_id: grp.id, team_lineup_column_id: doubles_col.id},
        tenant: grp.id,
        authorize?: false
      )

    {:ok,
     team: team,
     match: match,
     player: player,
     player2: player2,
     reserve_col: reserve_col,
     singles_col: singles_col,
     doubles_col: doubles_col,
     slot_s1: slot_s1,
     slot_s2: slot_s2,
     slot_d1: slot_d1}
  end

  # ---------------------------------------------------------------------------
  # Task 2.4: :one_per_match — reassignment updates slot, only one assignment
  # ---------------------------------------------------------------------------

  describe ":one_per_match mode" do
    setup %{group: grp, user: usr, team: team} do
      {:ok, team} =
        Tennis.update_team(team, %{lineup_assignment_mode: :one_per_match},
          tenant: grp.id,
          actor: usr
        )

      {:ok, team: team}
    end

    test "reassigning moves player to new slot (only one assignment remains)", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      slot_s1: slot_s1,
      slot_s2: slot_s2
    } do
      {:ok, _} =
        Tennis.assign_to_slot(match.id, player.id, slot_s1.id, tenant: grp.id, actor: usr)

      {:ok, updated} =
        Tennis.assign_to_slot(match.id, player.id, slot_s2.id, tenant: grp.id, actor: usr)

      assert updated.team_lineup_slot_id == slot_s2.id

      assignments = Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: usr)
      assert length(assignments) == 1
      assert hd(assignments).team_lineup_slot_id == slot_s2.id
    end

    test "second create is blocked when player already has assignment", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      slot_s1: slot_s1,
      slot_s2: slot_s2
    } do
      # Direct create (not through assign_to_slot) to bypass the domain-level upsert
      Tennis.create_lineup_assignment!(
        %{
          match_id: match.id,
          player_id: player.id,
          team_lineup_slot_id: slot_s1.id,
          group_id: grp.id
        },
        tenant: grp.id,
        actor: usr
      )

      result =
        Tennis.create_lineup_assignment(
          %{
            match_id: match.id,
            player_id: player.id,
            team_lineup_slot_id: slot_s2.id,
            group_id: grp.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end
  end

  # ---------------------------------------------------------------------------
  # Task 2.5: :one_per_column — second slot in same column is blocked, different columns succeed
  # ---------------------------------------------------------------------------

  describe ":one_per_column mode" do
    setup %{group: grp, user: usr, team: team} do
      {:ok, team} =
        Tennis.update_team(team, %{lineup_assignment_mode: :one_per_column},
          tenant: grp.id,
          actor: usr
        )

      {:ok, team: team}
    end

    test "second slot in the same column is blocked", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      slot_s1: slot_s1,
      slot_s2: slot_s2
    } do
      {:ok, _} =
        Tennis.assign_to_slot(match.id, player.id, slot_s1.id, tenant: grp.id, actor: usr)

      result =
        Tennis.assign_to_slot(match.id, player.id, slot_s2.id, tenant: grp.id, actor: usr)

      assert {:error, _} = result
    end

    test "slots in different columns both succeed", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      slot_s1: slot_s1,
      slot_d1: slot_d1
    } do
      {:ok, _} =
        Tennis.assign_to_slot(match.id, player.id, slot_s1.id, tenant: grp.id, actor: usr)

      {:ok, second} =
        Tennis.assign_to_slot(match.id, player.id, slot_d1.id, tenant: grp.id, actor: usr)

      assert second.team_lineup_slot_id == slot_d1.id

      assignments = Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: usr)
      assert length(assignments) == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Task 2.6: :many_per_match — multiple slots succeed, same slot twice is blocked
  # ---------------------------------------------------------------------------

  describe ":many_per_match mode" do
    setup %{group: grp, user: usr, team: team} do
      {:ok, team} =
        Tennis.update_team(team, %{lineup_assignment_mode: :many_per_match},
          tenant: grp.id,
          actor: usr
        )

      {:ok, team: team}
    end

    test "player can be in multiple slots", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      slot_s1: slot_s1,
      slot_d1: slot_d1
    } do
      {:ok, _} =
        Tennis.assign_to_slot(match.id, player.id, slot_s1.id, tenant: grp.id, actor: usr)

      {:ok, _} =
        Tennis.assign_to_slot(match.id, player.id, slot_d1.id, tenant: grp.id, actor: usr)

      assignments = Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: usr)
      slot_ids = Enum.map(assignments, & &1.team_lineup_slot_id) |> MapSet.new()
      assert MapSet.member?(slot_ids, slot_s1.id)
      assert MapSet.member?(slot_ids, slot_d1.id)
    end

    test "same slot twice is blocked by the baseline identity", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      slot_s1: slot_s1
    } do
      {:ok, _} =
        Tennis.assign_to_slot(match.id, player.id, slot_s1.id, tenant: grp.id, actor: usr)

      result =
        Tennis.assign_to_slot(match.id, player.id, slot_s1.id, tenant: grp.id, actor: usr)

      assert {:error, _} = result
    end
  end
end
