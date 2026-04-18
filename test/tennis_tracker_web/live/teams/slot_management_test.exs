defmodule TennisTrackerWeb.Teams.SlotManagementTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import TennisTrackerWeb.LineupTestHelpers

  alias TennisTracker.Tennis

  # ---------------------------------------------------------------------------
  # Authorization: page visibility
  # ---------------------------------------------------------------------------

  describe "lineup settings page visibility" do
    setup :setup_group_with_owner

    test "owner can access lineup settings page", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      assert has_element?(view, ".tab-active", "Lineup Settings")
    end

    test "captain can access lineup settings page", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      captain = setup_captain(grp, team)

      {:ok, view, _html} =
        live(log_in_user(conn, captain), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      assert has_element?(view, ".tab-active", "Lineup Settings")
    end

    test "non-captain member is redirected", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      member = setup_member(grp)

      assert {:error, {:live_redirect, _}} =
               live(
                 log_in_user(conn, member),
                 ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup"
               )
    end
  end

  # ---------------------------------------------------------------------------
  # CRUD: Add slot via modal
  # ---------------------------------------------------------------------------

  describe "add slot" do
    setup :setup_group_with_owner

    test "owner can add a slot via modal", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      view
      |> element(
        "button[phx-click='open_add_slot_modal'][phx-value-column_id='#{reserve_col.id}']"
      )
      |> render_click()

      view
      |> form("form[phx-submit='save_slot_modal']", %{
        "slot_form" => %{
          "name" => "#1 Singles",
          "expected_count" => "2",
          "include_in_clipboard" => "true"
        }
      })
      |> render_submit()

      assert has_element?(view, "[id^='slot-']", "#1 Singles")
      assert has_element?(view, "#flash-info", "Slot saved")
    end

    test "captain can add a slot via modal", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      captain = setup_captain(grp, team)
      reserve_col = get_reserve_col(grp, team)

      {:ok, view, _html} =
        live(log_in_user(conn, captain), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      view
      |> element(
        "button[phx-click='open_add_slot_modal'][phx-value-column_id='#{reserve_col.id}']"
      )
      |> render_click()

      view
      |> form("form[phx-submit='save_slot_modal']", %{
        "slot_form" => %{"name" => "D1", "include_in_clipboard" => "true"}
      })
      |> render_submit()

      assert has_element?(view, "[id^='slot-']", "D1")
    end

    test "shows auto-provisioned Out slot before adding any slots", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      assert has_element?(view, "[id^='slot-']", "Out")
    end

    test "modal closes after cancel", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      view
      |> element(
        "button[phx-click='open_add_slot_modal'][phx-value-column_id='#{reserve_col.id}']"
      )
      |> render_click()

      view |> element("button[phx-click='close_slot_modal']") |> render_click()

      refute has_element?(view, "form[phx-submit='save_slot_modal']")
    end

    test "participation_type select shown in add slot modal", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      view
      |> element(
        "button[phx-click='open_add_slot_modal'][phx-value-column_id='#{reserve_col.id}']"
      )
      |> render_click()

      assert has_element?(view, "select[name='slot_form[participation_type]']")

      assert has_element?(
               view,
               "select[name='slot_form[participation_type]'] option[value='playing']"
             )

      assert has_element?(
               view,
               "select[name='slot_form[participation_type]'] option[value='out']"
             )

      assert has_element?(
               view,
               "select[name='slot_form[participation_type]'] option[value='neutral']"
             )
    end

    test ":out option is disabled when team already has an :out slot", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      view
      |> element(
        "button[phx-click='open_add_slot_modal'][phx-value-column_id='#{reserve_col.id}']"
      )
      |> render_click()

      assert has_element?(
               view,
               "select[name='slot_form[participation_type]'] option[value='out'][disabled]"
             )
    end

    test ":out option is not disabled when team has no :out slot", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

      import Ecto.Query

      TennisTracker.Repo.delete_all(
        from(s in TennisTracker.Tennis.TeamLineupSlot,
          where: s.team_id == ^team.id and s.participation_type == "out"
        )
      )

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      view
      |> element(
        "button[phx-click='open_add_slot_modal'][phx-value-column_id='#{reserve_col.id}']"
      )
      |> render_click()

      refute has_element?(
               view,
               "select[name='slot_form[participation_type]'] option[value='out'][disabled]"
             )
    end

    test "participation_type field not shown in edit slot modal", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

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

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      view
      |> element("button[phx-click='open_edit_slot_modal'][phx-value-slot_id='#{slot.id}']")
      |> render_click()

      refute has_element?(view, "select[name='slot_form[participation_type]']")
    end
  end

  # ---------------------------------------------------------------------------
  # CRUD: Edit slot via modal
  # ---------------------------------------------------------------------------

  describe "edit slot" do
    setup :setup_group_with_owner

    test "owner can edit an existing slot via modal", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

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

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      view
      |> element("button[phx-click='open_edit_slot_modal'][phx-value-slot_id='#{slot.id}']")
      |> render_click()

      view
      |> form("form[phx-submit='save_slot_modal']", %{
        "slot_form" => %{"name" => "S2", "include_in_clipboard" => "true"}
      })
      |> render_submit()

      assert has_element?(view, "#slot-#{slot.id}", "S2")
      assert has_element?(view, "#flash-info", "Slot saved")
    end
  end

  # ---------------------------------------------------------------------------
  # CRUD: Delete slot
  # ---------------------------------------------------------------------------

  describe "delete slot" do
    setup :setup_group_with_owner

    test "owner can delete a slot", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

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

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      view
      |> element("button[phx-click='show_delete_slot_modal'][phx-value-slot_id='#{slot.id}']")
      |> render_click()

      assert has_element?(view, "button[phx-click='delete_slot']")

      view |> element("button[phx-click='delete_slot']") |> render_click()

      refute has_element?(view, "#slot-#{slot.id}")
      assert has_element?(view, "#flash-info", "Slot deleted")
    end

    test "delete button absent for :out slot", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)

      [out_slot] =
        Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
        |> Enum.filter(&(&1.participation_type == :out))

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      refute has_element?(
               view,
               "button[phx-click='show_delete_slot_modal'][phx-value-slot_id='#{out_slot.id}']"
             )
    end

    test "delete button present for :playing slot", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

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

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      assert has_element?(
               view,
               "button[phx-click='show_delete_slot_modal'][phx-value-slot_id='#{slot.id}']"
             )
    end

    test "delete button present for :neutral slot", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

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

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      assert has_element?(
               view,
               "button[phx-click='show_delete_slot_modal'][phx-value-slot_id='#{slot.id}']"
             )
    end
  end

  # ---------------------------------------------------------------------------
  # Reorder slots (within category)
  # ---------------------------------------------------------------------------

  describe "reorder slots" do
    setup :setup_group_with_owner

    test "move slot down changes order within category", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

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

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      view
      |> element("button[phx-click='move_slot_down'][phx-value-slot_id='#{slot1.id}']")
      |> render_click()

      html = render(view)
      slot1_idx = :binary.match(html, "slot-#{slot1.id}") |> elem(0)
      slot2_idx = :binary.match(html, "slot-#{slot2.id}") |> elem(0)
      assert slot2_idx < slot1_idx
    end

    test "first slot in category has disabled move-up button", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)

      [out_slot] =
        Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
        |> Enum.filter(&(&1.participation_type == :out))

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      assert has_element?(
               view,
               "button[phx-click='move_slot_up'][phx-value-slot_id='#{out_slot.id}'][disabled]"
             )
    end

    test "last slot in category has disabled move-down button", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      team = Factory.team(group: grp)
      reserve_col = get_reserve_col(grp, team)

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

      {:ok, view, _html} =
        live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/settings/lineup")

      assert has_element?(
               view,
               "button[phx-click='move_slot_down'][phx-value-slot_id='#{slot.id}'][disabled]"
             )
    end
  end
end
