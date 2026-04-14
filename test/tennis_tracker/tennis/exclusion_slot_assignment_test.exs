defmodule TennisTracker.Tennis.ExclusionSlotAssignmentTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{group: grp, user: usr} do
    team = Factory.team(group: grp)
    match = Factory.match(group: grp, team: team)
    player = Factory.player(group: grp)

    # The team auto-provision creates a "Reserve" column with an "Out" exclusion slot.
    # Get those for use in tests.
    [exclusion_slot] =
      Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, actor: usr)
      |> Enum.filter(&(&1.participation_type == :out))

    [reserve_col] = Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, actor: usr)

    # Create a playing slot in the reserve column (column required)
    {:ok, playing_slot} =
      Tennis.create_lineup_slot(
        %{
          name: "S1",
          team_id: team.id,
          group_id: grp.id,
          team_lineup_column_id: reserve_col.id
        },
        tenant: grp.id,
        authorize?: false
      )

    {:ok,
     team: team,
     match: match,
     player: player,
     exclusion_slot: exclusion_slot,
     playing_slot: playing_slot}
  end

  # ---------------------------------------------------------------------------
  # Task 1.1: Block playing slot assignment when player is excluded
  # ---------------------------------------------------------------------------

  describe "blocked playing-slot assignment when player is excluded" do
    test "cannot assign to playing slot when player has exclusion assignment", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      exclusion_slot: exclusion_slot,
      playing_slot: playing_slot
    } do
      {:ok, _} =
        Tennis.assign_to_slot(match.id, player.id, exclusion_slot.id,
          tenant: grp.id,
          actor: usr
        )

      result =
        Tennis.assign_to_slot(match.id, player.id, playing_slot.id,
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result

      assignments = Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: usr)
      assert length(assignments) == 1
      assert hd(assignments).team_lineup_slot_id == exclusion_slot.id
    end

    test "can assign to playing slot when player has no exclusion assignment", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      playing_slot: playing_slot
    } do
      {:ok, assignment} =
        Tennis.assign_to_slot(match.id, player.id, playing_slot.id,
          tenant: grp.id,
          actor: usr
        )

      assert assignment.team_lineup_slot_id == playing_slot.id
    end
  end

  # ---------------------------------------------------------------------------
  # Task 1.2: Auto-removal of playing assignments when assigning to exclusion slot
  # ---------------------------------------------------------------------------

  describe "auto-removal of playing assignments on exclusion assign" do
    test "assigns to exclusion slot and removes existing playing assignment", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      exclusion_slot: exclusion_slot,
      playing_slot: playing_slot
    } do
      {:ok, _} =
        Tennis.assign_to_slot(match.id, player.id, playing_slot.id,
          tenant: grp.id,
          actor: usr
        )

      {:ok, excl_assignment} =
        Tennis.assign_to_slot(match.id, player.id, exclusion_slot.id,
          tenant: grp.id,
          actor: usr
        )

      assert excl_assignment.team_lineup_slot_id == exclusion_slot.id

      assignments = Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: usr)
      assert length(assignments) == 1
      assert hd(assignments).team_lineup_slot_id == exclusion_slot.id
    end

    test "assigns to exclusion slot when player has no prior assignments", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      exclusion_slot: exclusion_slot
    } do
      {:ok, assignment} =
        Tennis.assign_to_slot(match.id, player.id, exclusion_slot.id,
          tenant: grp.id,
          actor: usr
        )

      assert assignment.team_lineup_slot_id == exclusion_slot.id
      assignments = Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: usr)
      assert length(assignments) == 1
    end
  end
end
