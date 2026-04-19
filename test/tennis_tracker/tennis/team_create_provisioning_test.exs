defmodule TennisTracker.Tennis.TeamCreateProvisioningTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  describe "team creation auto-provisioning" do
    test "creates 'Assigned' and 'Reserve' columns", %{group: grp, user: usr} do
      team = Factory.team(group: grp)

      columns = Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, actor: usr)

      assert length(columns) == 2
      assert Enum.map(columns, & &1.name) == ["Assigned", "Reserve"]
    end

    test "creates six default playing slots in the Assigned column", %{group: grp, user: usr} do
      team = Factory.team(group: grp)

      columns = Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, actor: usr)
      assigned_col = Enum.find(columns, &(&1.name == "Assigned"))

      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, actor: usr)
      assigned_slots = Enum.filter(slots, &(&1.team_lineup_column_id == assigned_col.id))

      assert length(assigned_slots) == 6

      slot_names = Enum.map(assigned_slots, & &1.name)
      assert "#1 Singles" in slot_names
      assert "#2 Singles" in slot_names
      assert "#1 Doubles" in slot_names
      assert "#2 Doubles" in slot_names
      assert "#3 Doubles" in slot_names
      assert "Sub" in slot_names

      Enum.each(assigned_slots, fn slot ->
        assert slot.participation_type == :playing
        assert slot.include_in_clipboard == true
      end)
    end

    test "creates exactly one 'Out' exclusion slot in the Reserve column", %{
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)

      columns = Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, actor: usr)
      reserve_col = Enum.find(columns, &(&1.name == "Reserve"))

      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, actor: usr)
      reserve_slots = Enum.filter(slots, &(&1.team_lineup_column_id == reserve_col.id))

      assert length(reserve_slots) == 1
      out_slot = hd(reserve_slots)
      assert out_slot.name == "Out"
      assert out_slot.participation_type == :out
      assert out_slot.include_in_clipboard == false
    end

    test "does not provision columns or slots for pseudo-teams", %{group: grp, user: usr} do
      pseudo_team = Factory.team(group: grp, traits: [:pseudo])

      columns = Tennis.list_lineup_columns_for_team!(pseudo_team.id, tenant: grp.id, actor: usr)
      slots = Tennis.list_lineup_slots_for_team!(pseudo_team.id, tenant: grp.id, actor: usr)

      assert columns == []
      assert slots == []
    end

    test "each team gets its own independent columns and slots", %{group: grp, user: usr} do
      team1 = Factory.team(group: grp)
      team2 = Factory.team(group: grp)

      cols1 = Tennis.list_lineup_columns_for_team!(team1.id, tenant: grp.id, actor: usr)
      cols2 = Tennis.list_lineup_columns_for_team!(team2.id, tenant: grp.id, actor: usr)

      assert length(cols1) == 2
      assert length(cols2) == 2

      col_ids1 = MapSet.new(cols1, & &1.id)
      col_ids2 = MapSet.new(cols2, & &1.id)
      assert MapSet.disjoint?(col_ids1, col_ids2)
    end
  end
end
