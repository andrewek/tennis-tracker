defmodule TennisTracker.Tennis.TeamLineupSlotTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{group: grp, user: _usr} do
    team = Factory.team(group: grp)
    member_user = Factory.user()
    Factory.group_membership(group: grp, user: member_user)
    captain_user = Factory.user()
    Factory.group_membership(group: grp, user: captain_user)
    Factory.team_role(group: grp, user: captain_user, team: team, traits: [:captain])
    {:ok, team: team, member: member_user, captain: captain_user}
  end

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------

  describe "create" do
    test "owner can create a slot", %{group: grp, user: usr, team: team} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "#1 Singles", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert slot.name == "#1 Singles"
      assert slot.team_id == team.id
      assert slot.include_in_clipboard == true
      assert is_nil(slot.expected_count)
    end

    test "captain can create a slot", %{group: grp, captain: captain, team: team} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "#1 Doubles", expected_count: 2, team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: captain
        )

      assert slot.name == "#1 Doubles"
      assert slot.expected_count == 2
    end

    test "non-captain member cannot create a slot", %{group: grp, member: member, team: team} do
      result =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: member
        )

      assert {:error, _} = result
    end

    test "include_in_clipboard defaults to true", %{group: grp, user: usr, team: team} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "Out", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert slot.include_in_clipboard == true
    end

    test "can set include_in_clipboard to false", %{group: grp, user: usr, team: team} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "Out", include_in_clipboard: false, team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert slot.include_in_clipboard == false
    end

    test "rejects blank name", %{group: grp, user: usr, team: team} do
      result =
        Tennis.create_lineup_slot(
          %{name: "", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end

    test "rejects name longer than 12 chars", %{group: grp, user: usr, team: team} do
      result =
        Tennis.create_lineup_slot(
          %{name: "TooLongSlotX!", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end

    test "rejects duplicate name within same team", %{group: grp, user: usr, team: team} do
      {:ok, _} =
        Tennis.create_lineup_slot(
          %{name: "#1 Singles", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      result =
        Tennis.create_lineup_slot(
          %{name: "#1 Singles", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end

    test "same name allowed on different teams", %{group: grp, user: usr, team: team} do
      team2 = Factory.team(group: grp)

      {:ok, _} =
        Tennis.create_lineup_slot(
          %{name: "#1 Singles", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, slot2} =
        Tennis.create_lineup_slot(
          %{name: "#1 Singles", team_id: team2.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert slot2.name == "#1 Singles"
    end

    test "sort_order is auto-assigned starting at 0", %{group: grp, user: usr, team: team} do
      {:ok, slot1} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, slot2} =
        Tennis.create_lineup_slot(
          %{name: "D1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, slot3} =
        Tennis.create_lineup_slot(
          %{name: "D2", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert slot1.sort_order == 0
      assert slot2.sort_order == 1
      assert slot3.sort_order == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Read
  # ---------------------------------------------------------------------------

  describe "list_lineup_slots_for_team" do
    test "returns slots ordered by sort_order", %{group: grp, user: usr, team: team} do
      {:ok, _} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, _} =
        Tennis.create_lineup_slot(
          %{name: "D1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, _} =
        Tennis.create_lineup_slot(
          %{name: "D2", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, actor: usr)
      names = Enum.map(slots, & &1.name)
      assert names == ["S1", "D1", "D2"]
    end

    test "member can read slots", %{group: grp, member: member, team: team, user: usr} do
      {:ok, _} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, actor: member)
      assert length(slots) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Update
  # ---------------------------------------------------------------------------

  describe "update" do
    test "owner can update a slot", %{group: grp, user: usr, team: team} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, updated} =
        Tennis.update_lineup_slot(slot, %{name: "S2"}, tenant: grp.id, actor: usr)

      assert updated.name == "S2"
    end

    test "captain can update a slot", %{group: grp, captain: captain, team: team, user: usr} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, updated} =
        Tennis.update_lineup_slot(slot, %{include_in_clipboard: false},
          tenant: grp.id,
          actor: captain
        )

      assert updated.include_in_clipboard == false
    end

    test "non-captain member cannot update", %{group: grp, member: member, team: team, user: usr} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      result = Tennis.update_lineup_slot(slot, %{name: "S2"}, tenant: grp.id, actor: member)
      assert {:error, _} = result
    end
  end

  # ---------------------------------------------------------------------------
  # Delete
  # ---------------------------------------------------------------------------

  describe "delete" do
    test "owner can delete a slot", %{group: grp, user: usr, team: team} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert :ok = Tennis.delete_lineup_slot!(slot, tenant: grp.id, actor: usr)
      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, actor: usr)
      assert slots == []
    end

    test "captain can delete a slot", %{group: grp, captain: captain, team: team, user: usr} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert :ok = Tennis.delete_lineup_slot!(slot, tenant: grp.id, actor: captain)
    end

    test "non-captain member cannot delete", %{group: grp, member: member, team: team, user: usr} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      result = Tennis.delete_lineup_slot(slot, tenant: grp.id, actor: member)
      assert {:error, _} = result
    end
  end
end
