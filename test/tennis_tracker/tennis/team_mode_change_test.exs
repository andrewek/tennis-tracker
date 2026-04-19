defmodule TennisTracker.Tennis.TeamModeChangeTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{group: grp, user: usr} do
    team = Factory.team(group: grp)
    match = Factory.match(group: grp, team: team)
    player = Factory.player(group: grp)

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
     slot_s1: slot_s1,
     slot_s2: slot_s2,
     slot_d1: slot_d1}
  end

  # ---------------------------------------------------------------------------
  # Mode change to :one_per_match
  # ---------------------------------------------------------------------------

  describe "mode change to :one_per_match" do
    test "blocked when player has multiple assignments across slots", %{
      group: grp,
      user: usr,
      team: team,
      match: match,
      player: player,
      slot_s1: slot_s1,
      slot_d1: slot_d1
    } do
      # First set team to many_per_match so we can create multiple assignments
      team =
        Tennis.update_team!(team, %{lineup_assignment_mode: :many_per_match},
          tenant: grp.id,
          actor: usr
        )

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

      Tennis.create_lineup_assignment!(
        %{
          match_id: match.id,
          player_id: player.id,
          team_lineup_slot_id: slot_d1.id,
          group_id: grp.id
        },
        tenant: grp.id,
        actor: usr
      )

      result =
        Tennis.update_team(team, %{lineup_assignment_mode: :one_per_match},
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end

    test "succeeds when player has at most one assignment per match", %{
      group: grp,
      user: usr,
      team: team,
      match: match,
      player: player,
      slot_s1: slot_s1
    } do
      Tennis.create_lineup_assignment!(
        %{
          match_id: match.id,
          player_id: player.id,
          team_lineup_slot_id: slot_s1.id,
          group_id: grp.id
        },
        tenant: grp.id,
        authorize?: false
      )

      {:ok, updated} =
        Tennis.update_team(team, %{lineup_assignment_mode: :one_per_match},
          tenant: grp.id,
          actor: usr
        )

      assert updated.lineup_assignment_mode == :one_per_match
    end
  end

  # ---------------------------------------------------------------------------
  # Mode change to :one_per_column
  # ---------------------------------------------------------------------------

  describe "mode change to :one_per_column" do
    test "blocked when player has multiple assignments in same column", %{
      group: grp,
      user: usr,
      team: team,
      match: match,
      player: player,
      slot_s1: slot_s1,
      slot_s2: slot_s2
    } do
      team =
        Tennis.update_team!(team, %{lineup_assignment_mode: :many_per_match},
          tenant: grp.id,
          actor: usr
        )

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

      Tennis.create_lineup_assignment!(
        %{
          match_id: match.id,
          player_id: player.id,
          team_lineup_slot_id: slot_s2.id,
          group_id: grp.id
        },
        tenant: grp.id,
        actor: usr
      )

      result =
        Tennis.update_team(team, %{lineup_assignment_mode: :one_per_column},
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end

    test "succeeds when no player has multiple assignments in the same column", %{
      group: grp,
      user: usr,
      team: team,
      match: match,
      player: player,
      slot_s1: slot_s1,
      slot_d1: slot_d1
    } do
      team =
        Tennis.update_team!(team, %{lineup_assignment_mode: :many_per_match},
          tenant: grp.id,
          actor: usr
        )

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

      Tennis.create_lineup_assignment!(
        %{
          match_id: match.id,
          player_id: player.id,
          team_lineup_slot_id: slot_d1.id,
          group_id: grp.id
        },
        tenant: grp.id,
        actor: usr
      )

      {:ok, updated} =
        Tennis.update_team(team, %{lineup_assignment_mode: :one_per_column},
          tenant: grp.id,
          actor: usr
        )

      assert updated.lineup_assignment_mode == :one_per_column
    end
  end

  # ---------------------------------------------------------------------------
  # Mode change to :many_per_match always succeeds
  # ---------------------------------------------------------------------------

  describe "mode change to :many_per_match" do
    test "always succeeds regardless of existing assignments", %{
      group: grp,
      user: usr,
      team: team,
      match: match,
      player: player,
      slot_s1: slot_s1,
      slot_s2: slot_s2
    } do
      # Already in :one_per_match, create two separate player assignments
      player2 = Factory.player(group: grp)

      Tennis.create_lineup_assignment!(
        %{
          match_id: match.id,
          player_id: player.id,
          team_lineup_slot_id: slot_s1.id,
          group_id: grp.id
        },
        tenant: grp.id,
        authorize?: false
      )

      Tennis.create_lineup_assignment!(
        %{
          match_id: match.id,
          player_id: player2.id,
          team_lineup_slot_id: slot_s2.id,
          group_id: grp.id
        },
        tenant: grp.id,
        authorize?: false
      )

      {:ok, updated} =
        Tennis.update_team(team, %{lineup_assignment_mode: :many_per_match},
          tenant: grp.id,
          actor: usr
        )

      assert updated.lineup_assignment_mode == :many_per_match
    end
  end
end
