defmodule TennisTracker.Tennis.TeamCreateProvisioningTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  describe "team creation auto-provisioning" do
    test "creates exactly one 'Reserve' column", %{group: grp, user: usr} do
      team = Factory.team(group: grp)

      columns = Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, actor: usr)

      assert length(columns) == 1
      assert hd(columns).name == "Reserve"
    end

    test "creates exactly one 'Out' exclusion slot in the Reserve column", %{
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)

      columns = Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, actor: usr)
      reserve_col = hd(columns)

      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, actor: usr)

      assert length(slots) == 1
      out_slot = hd(slots)
      assert out_slot.name == "Out"
      assert out_slot.participation_type == :out
      assert out_slot.team_lineup_column_id == reserve_col.id
      assert out_slot.include_in_clipboard == false
    end

    test "does not provision columns or slots for pseudo-teams", %{group: grp, user: usr} do
      pseudo_team = Factory.team(group: grp, traits: [:pseudo])

      columns = Tennis.list_lineup_columns_for_team!(pseudo_team.id, tenant: grp.id, actor: usr)
      slots = Tennis.list_lineup_slots_for_team!(pseudo_team.id, tenant: grp.id, actor: usr)

      assert columns == []
      assert slots == []
    end

    test "each team gets its own independent column and slot", %{group: grp, user: usr} do
      team1 = Factory.team(group: grp)
      team2 = Factory.team(group: grp)

      cols1 = Tennis.list_lineup_columns_for_team!(team1.id, tenant: grp.id, actor: usr)
      cols2 = Tennis.list_lineup_columns_for_team!(team2.id, tenant: grp.id, actor: usr)

      assert length(cols1) == 1
      assert length(cols2) == 1
      refute hd(cols1).id == hd(cols2).id
    end
  end
end
