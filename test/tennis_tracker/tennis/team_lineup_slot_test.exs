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

    reserve_col =
      Tennis.list_lineup_columns_for_team!(team.id, tenant: grp.id, authorize?: false)
      |> Enum.find(&(&1.name == "Reserve"))

    {:ok, team: team, member: member_user, captain: captain_user, reserve_col: reserve_col}
  end

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------

  describe "create" do
    test "owner can create a slot", %{group: grp, user: usr, team: team, reserve_col: reserve_col} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert slot.name == "S1"
      assert slot.team_id == team.id
      assert slot.include_in_clipboard == true
      assert is_nil(slot.expected_count)
    end

    test "captain can create a slot", %{
      group: grp,
      captain: captain,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "D1",
            expected_count: 2,
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: captain
        )

      assert slot.name == "D1"
      assert slot.expected_count == 2
    end

    test "non-captain member cannot create a slot", %{
      group: grp,
      member: member,
      team: team,
      reserve_col: reserve_col
    } do
      result =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: member
        )

      assert {:error, _} = result
    end

    test "include_in_clipboard defaults to true", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert slot.include_in_clipboard == true
    end

    test "can set include_in_clipboard to false", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            include_in_clipboard: false,
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert slot.include_in_clipboard == false
    end

    test "rejects blank name", %{group: grp, user: usr, team: team, reserve_col: reserve_col} do
      result =
        Tennis.create_lineup_slot(
          %{name: "", team_id: team.id, group_id: grp.id, team_lineup_column_id: reserve_col.id},
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end

    test "rejects name longer than 12 chars", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      result =
        Tennis.create_lineup_slot(
          %{
            name: "TooLongSlotX!",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end

    test "rejects slot without a column", %{group: grp, user: usr, team: team} do
      result =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end

    test "rejects duplicate name within same team", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, _} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      result =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end

    test "same name allowed on different teams", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      team2 = Factory.team(group: grp)

      col2 =
        Tennis.list_lineup_columns_for_team!(team2.id, tenant: grp.id, authorize?: false)
        |> Enum.find(&(&1.name == "Reserve"))

      {:ok, _} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      {:ok, slot2} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team2.id,
            group_id: grp.id,
            team_lineup_column_id: col2.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert slot2.name == "S1"
    end

    test "sort_order is auto-assigned in ascending order within the team", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, slot1} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      {:ok, slot2} =
        Tennis.create_lineup_slot(
          %{
            name: "D1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      {:ok, slot3} =
        Tennis.create_lineup_slot(
          %{
            name: "D2",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert slot1.sort_order < slot2.sort_order
      assert slot2.sort_order < slot3.sort_order
    end

    test "default auto-provisioned Out slot has participation_type :out", %{
      group: grp,
      team: team
    } do
      [out_slot] =
        Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
        |> Enum.filter(&(&1.participation_type == :out))

      assert out_slot.name == "Out"
      assert out_slot.participation_type == :out
    end

    test "creating a :playing slot succeeds", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            participation_type: :playing,
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert slot.participation_type == :playing
    end

    test "creating a :neutral slot succeeds", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "Beer",
            participation_type: :neutral,
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert slot.participation_type == :neutral
    end

    test "creating an :out slot succeeds when team has no :out slot", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      # Delete the auto-provisioned Out slot directly (bypass the destroy validation)
      import Ecto.Query

      TennisTracker.Repo.delete_all(
        from(s in TennisTracker.Tennis.TeamLineupSlot,
          where: s.team_id == ^team.id and s.participation_type == "out"
        )
      )

      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "Unavail",
            participation_type: :out,
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert slot.participation_type == :out
    end

    test "rejects second out slot", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      result =
        Tennis.create_lineup_slot(
          %{
            name: "Sick",
            participation_type: :out,
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end
  end

  # ---------------------------------------------------------------------------
  # Read
  # ---------------------------------------------------------------------------

  describe "list_lineup_slots_for_team" do
    test "includes default slots plus added slots in sort_order", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, _} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      {:ok, _} =
        Tennis.create_lineup_slot(
          %{
            name: "D1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, actor: usr)
      names = Enum.map(slots, & &1.name)
      # 6 default playing slots + 1 Out + S1 and D1
      assert "Out" in names
      assert "S1" in names
      assert "D1" in names
    end

    test "member can read slots", %{
      group: grp,
      member: member,
      team: team,
      user: usr,
      reserve_col: reserve_col
    } do
      {:ok, _} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, actor: member)
      # 6 default playing slots + 1 Out + "S1" = 8 total
      assert length(slots) == 8
    end
  end

  # ---------------------------------------------------------------------------
  # Update
  # ---------------------------------------------------------------------------

  describe "update" do
    test "owner can update a slot", %{group: grp, user: usr, team: team, reserve_col: reserve_col} do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      {:ok, updated} =
        Tennis.update_lineup_slot(slot, %{name: "S2"}, tenant: grp.id, actor: usr)

      assert updated.name == "S2"
    end

    test "captain can update a slot", %{
      group: grp,
      captain: captain,
      team: team,
      user: usr,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
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

    test "non-captain member cannot update", %{
      group: grp,
      member: member,
      team: team,
      user: usr,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
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
    test "owner can delete a non-exclusion slot", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert :ok = Tennis.delete_lineup_slot!(slot, tenant: grp.id, actor: usr)
      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, actor: usr)
      refute Enum.any?(slots, &(&1.id == slot.id))
    end

    test "captain can delete a non-exclusion slot", %{
      group: grp,
      captain: captain,
      team: team,
      user: usr,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert :ok = Tennis.delete_lineup_slot!(slot, tenant: grp.id, actor: captain)
    end

    test "non-captain member cannot delete", %{
      group: grp,
      member: member,
      team: team,
      user: usr,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      result = Tennis.delete_lineup_slot(slot, tenant: grp.id, actor: member)
      assert {:error, _} = result
    end

    test "delete succeeds for :playing slot", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "S1",
            participation_type: :playing,
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert :ok = Tennis.delete_lineup_slot!(slot, tenant: grp.id, actor: usr)
    end

    test "delete succeeds for :neutral slot", %{
      group: grp,
      user: usr,
      team: team,
      reserve_col: reserve_col
    } do
      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{
            name: "Beer",
            participation_type: :neutral,
            team_id: team.id,
            group_id: grp.id,
            team_lineup_column_id: reserve_col.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert :ok = Tennis.delete_lineup_slot!(slot, tenant: grp.id, actor: usr)
    end

    test "out slot cannot be deleted", %{group: grp, user: usr, team: team} do
      [out_slot] =
        Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
        |> Enum.filter(&(&1.participation_type == :out))

      result = Tennis.delete_lineup_slot(out_slot, tenant: grp.id, actor: usr)
      assert {:error, _} = result
    end
  end
end
