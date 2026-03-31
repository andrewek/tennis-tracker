defmodule TennisTracker.Tennis.MatchLineupAssignmentTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{group: grp, user: _usr} do
    team = Factory.team(group: grp)
    match = Factory.match(group: grp, team: team)
    player = Factory.player(group: grp)

    member_user = Factory.user()
    Factory.group_membership(group: grp, user: member_user)

    captain_user = Factory.user()
    Factory.group_membership(group: grp, user: captain_user)
    Factory.team_role(group: grp, user: captain_user, team: team, traits: [:captain])

    slot =
      Tennis.create_lineup_slot!(
        %{name: "S1", team_id: team.id, group_id: grp.id},
        tenant: grp.id,
        authorize?: false
      )

    {:ok,
     team: team,
     match: match,
     player: player,
     member: member_user,
     captain: captain_user,
     slot: slot}
  end

  # ---------------------------------------------------------------------------
  # assign_to_slot
  # ---------------------------------------------------------------------------

  describe "assign_to_slot" do
    test "captain can assign a player to a slot", %{
      group: grp,
      match: match,
      player: player,
      captain: captain,
      slot: slot
    } do
      {:ok, assignment} =
        Tennis.assign_to_slot(match.id, player.id, slot.id,
          tenant: grp.id,
          actor: captain
        )

      assert assignment.match_id == match.id
      assert assignment.player_id == player.id
      assert assignment.team_lineup_slot_id == slot.id
    end

    test "owner can assign a player to a slot", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      slot: slot
    } do
      {:ok, assignment} =
        Tennis.assign_to_slot(match.id, player.id, slot.id,
          tenant: grp.id,
          actor: usr
        )

      assert assignment.match_id == match.id
    end

    test "member cannot assign a player to a slot", %{
      group: grp,
      match: match,
      player: player,
      member: member,
      slot: slot
    } do
      result =
        Tennis.assign_to_slot(match.id, player.id, slot.id,
          tenant: grp.id,
          actor: member
        )

      assert {:error, _} = result
    end

    test "upsert moves player to new slot", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      team: team,
      slot: slot
    } do
      slot2 =
        Tennis.create_lineup_slot!(
          %{name: "D1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          authorize?: false
        )

      {:ok, _} =
        Tennis.assign_to_slot(match.id, player.id, slot.id,
          tenant: grp.id,
          actor: usr
        )

      {:ok, updated} =
        Tennis.assign_to_slot(match.id, player.id, slot2.id,
          tenant: grp.id,
          actor: usr
        )

      assert updated.team_lineup_slot_id == slot2.id

      assignments =
        Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: usr)

      assert length(assignments) == 1
      assert hd(assignments).team_lineup_slot_id == slot2.id
    end
  end

  # ---------------------------------------------------------------------------
  # unassign_from_lineup
  # ---------------------------------------------------------------------------

  describe "unassign_from_lineup" do
    test "captain can remove a player's assignment", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      captain: captain,
      slot: slot
    } do
      Tennis.assign_to_slot(match.id, player.id, slot.id,
        tenant: grp.id,
        actor: usr
      )

      result =
        Tennis.unassign_from_lineup(match.id, player.id,
          tenant: grp.id,
          actor: captain
        )

      assert :ok = result
      assignments = Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: usr)
      assert assignments == []
    end

    test "returns ok when no assignment exists", %{
      group: grp,
      match: match,
      player: player,
      captain: captain
    } do
      result =
        Tennis.unassign_from_lineup(match.id, player.id,
          tenant: grp.id,
          actor: captain
        )

      assert {:ok, nil} = result
    end
  end

  # ---------------------------------------------------------------------------
  # list_assignments_for_match
  # ---------------------------------------------------------------------------

  describe "list_assignments_for_match" do
    test "returns all assignments for a match", %{
      group: grp,
      user: usr,
      match: match,
      team: team,
      slot: slot
    } do
      player1 = Factory.player(group: grp)
      player2 = Factory.player(group: grp)

      slot2 =
        Tennis.create_lineup_slot!(
          %{name: "D1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          authorize?: false
        )

      Tennis.assign_to_slot(match.id, player1.id, slot.id, tenant: grp.id, actor: usr)
      Tennis.assign_to_slot(match.id, player2.id, slot2.id, tenant: grp.id, actor: usr)

      assignments = Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: usr)
      assert length(assignments) == 2
    end

    test "member can read assignments", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      member: member,
      slot: slot
    } do
      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)
      assignments = Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: member)
      assert length(assignments) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Authorization on update/destroy
  # ---------------------------------------------------------------------------

  describe "authorization" do
    test "member cannot destroy an assignment", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      member: member,
      slot: slot
    } do
      {:ok, assignment} =
        Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      result = Ash.destroy(assignment, domain: Tennis, actor: member, tenant: grp.id)
      assert {:error, _} = result
    end

    test "captain can destroy an assignment", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      captain: captain,
      slot: slot
    } do
      {:ok, assignment} =
        Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      assert :ok = Ash.destroy(assignment, domain: Tennis, actor: captain, tenant: grp.id)
    end
  end

  # ---------------------------------------------------------------------------
  # Cascade delete
  # ---------------------------------------------------------------------------

  describe "cascade delete" do
    test "deleting a slot removes its assignments", %{
      group: grp,
      user: usr,
      match: match,
      player: player,
      slot: slot
    } do
      Tennis.assign_to_slot(match.id, player.id, slot.id, tenant: grp.id, actor: usr)

      Tennis.delete_lineup_slot!(slot, tenant: grp.id, actor: usr)

      assignments = Tennis.list_assignments_for_match!(match.id, tenant: grp.id, actor: usr)
      assert assignments == []
    end
  end
end
