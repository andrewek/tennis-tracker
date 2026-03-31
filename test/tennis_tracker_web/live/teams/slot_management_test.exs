defmodule TennisTrackerWeb.Teams.SlotManagementTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  # ---------------------------------------------------------------------------
  # Setup helpers
  # ---------------------------------------------------------------------------

  defp setup_captain(grp, team) do
    captain = Factory.user()
    Factory.group_membership(group: grp, user: captain)
    Factory.team_role(group: grp, user: captain, team: team, traits: [:captain])
    captain
  end

  defp setup_member(grp) do
    member = Factory.user()
    Factory.group_membership(group: grp, user: member)
    member
  end

  # ---------------------------------------------------------------------------
  # Authorization: section visibility
  # ---------------------------------------------------------------------------

  describe "slot section visibility" do
    setup :setup_group_with_owner

    test "owner sees slot management section", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      {:ok, _view, html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")
      assert html =~ "Lineup Slots"
    end

    test "captain sees slot management section", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      captain = setup_captain(grp, team)

      {:ok, _view, html} =
        live(log_in_user(conn, captain), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      assert html =~ "Lineup Slots"
    end

    test "non-captain member does not see slot management section", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      member = setup_member(grp)

      # Member cannot manage slots or update team, so they get redirected
      assert {:error, {:live_redirect, _}} =
               live(log_in_user(conn, member), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")
    end
  end

  # ---------------------------------------------------------------------------
  # CRUD: Add slot
  # ---------------------------------------------------------------------------

  describe "add slot" do
    setup :setup_group_with_owner

    test "owner can add a slot via form", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view |> element("button[phx-click='open_add_slot_form']") |> render_click()

      view
      |> form("form[phx-submit='save_slot']", %{
        "slot_form" => %{
          "name" => "#1 Singles",
          "expected_count" => "2",
          "include_in_clipboard" => "true"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "#1 Singles"
      assert html =~ "Slot added"
    end

    test "captain can add a slot", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      captain = setup_captain(grp, team)

      {:ok, view, _html} =
        live(log_in_user(conn, captain), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view |> element("button[phx-click='open_add_slot_form']") |> render_click()

      view
      |> form("form[phx-submit='save_slot']", %{
        "slot_form" => %{"name" => "D1", "include_in_clipboard" => "true"}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "D1"
    end

    test "shows empty state before adding", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      {:ok, _view, html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")
      assert html =~ "No lineup slots defined"
    end

    test "add form disappears after cancel", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)
      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view |> element("button[phx-click='open_add_slot_form']") |> render_click()
      view |> element("button[phx-click='close_add_slot_form']") |> render_click()

      refute has_element?(view, "form[phx-submit='save_slot']")
    end
  end

  # ---------------------------------------------------------------------------
  # CRUD: Edit slot
  # ---------------------------------------------------------------------------

  describe "edit slot" do
    setup :setup_group_with_owner

    test "owner can edit an existing slot", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)

      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view
      |> element("button[phx-click='open_edit_slot'][phx-value-slot_id='#{slot.id}']")
      |> render_click()

      view
      |> form("form[phx-submit='save_edit_slot']", %{
        "edit_slot_form" => %{"name" => "S2", "include_in_clipboard" => "true"}
      })
      |> render_submit()

      html = render(view)
      assert html =~ "S2"
      assert html =~ "Slot updated"
    end
  end

  # ---------------------------------------------------------------------------
  # CRUD: Delete slot
  # ---------------------------------------------------------------------------

  describe "delete slot" do
    setup :setup_group_with_owner

    test "owner can delete a slot", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)

      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view
      |> element("button[phx-click='show_delete_slot_modal'][phx-value-slot_id='#{slot.id}']")
      |> render_click()

      assert has_element?(view, "button[phx-click='delete_slot']")

      view |> element("button[phx-click='delete_slot']") |> render_click()

      refute has_element?(view, "#slot-#{slot.id}")
      assert render(view) =~ "Slot deleted"
    end
  end

  # ---------------------------------------------------------------------------
  # Reorder slots
  # ---------------------------------------------------------------------------

  describe "reorder slots" do
    setup :setup_group_with_owner

    test "move slot down changes order", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)

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

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view
      |> element("button[phx-click='move_slot_down'][phx-value-slot_id='#{slot1.id}']")
      |> render_click()

      # After moving S1 down, slot2 (D1) should appear before slot1 (S1) in the DOM
      html = render(view)
      slot1_idx = :binary.match(html, "slot-#{slot1.id}") |> elem(0)
      slot2_idx = :binary.match(html, "slot-#{slot2.id}") |> elem(0)
      assert slot2_idx < slot1_idx
    end

    test "first slot has no move-up button", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)

      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      refute has_element?(
               view,
               "button[phx-click='move_slot_up'][phx-value-slot_id='#{slot.id}']"
             )
    end

    test "last slot has no move-down button", %{conn: conn, group: grp, user: usr} do
      team = Factory.team(group: grp)

      {:ok, slot} =
        Tennis.create_lineup_slot(
          %{name: "S1", team_id: team.id, group_id: grp.id},
          tenant: grp.id,
          actor: usr
        )

      {:ok, view, _html} = live(log_in_user(conn, usr), ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      refute has_element?(
               view,
               "button[phx-click='move_slot_down'][phx-value-slot_id='#{slot.id}']"
             )
    end
  end
end
