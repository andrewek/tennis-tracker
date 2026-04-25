defmodule TennisTrackerWeb.Settings.Locations.IndexLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "access control" do
    test "redirects non-owner members", %{conn: conn, group: grp} do
      member_user = Factory.user()
      Factory.group_membership(group: grp, user: member_user)
      conn = log_in_user(conn, member_user)

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/g/#{grp.slug}/settings/locations")

      assert path == ~p"/g/#{grp.slug}"
    end

    test "owner can access the page", %{conn: conn, group: grp} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")
      assert has_element?(view, "h1", "Locations")
    end
  end

  describe "active tab" do
    test "lists active locations", %{conn: conn, group: grp} do
      Factory.location(group: grp, name: "River City Courts")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")

      assert has_element?(view, "p", "River City Courts")
    end

    test "shows empty state when no active locations exist", %{conn: conn, group: grp} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")

      assert has_element?(view, "p", "No locations yet")
    end

    test "does not list archived locations on active tab", %{conn: conn, group: grp, user: usr} do
      loc = Factory.location(group: grp, name: "Hidden Court")
      Tennis.archive_location!(loc, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")

      refute has_element?(view, "#active-locations", "Hidden Court")
    end
  end

  describe "archive confirmation flow" do
    test "archive button shows confirmation modal", %{conn: conn, group: grp} do
      Factory.location(group: grp, name: "Archivable Court")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")

      view
      |> element("button[phx-click='request_archive']")
      |> render_click()

      assert has_element?(view, "h3", "Archive Location")
      assert has_element?(view, "strong", "Archivable Court")
    end

    test "confirming archive removes location from active list", %{conn: conn, group: grp} do
      Factory.location(group: grp, name: "Soon Archived")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")

      view
      |> element("button[phx-click='request_archive']")
      |> render_click()

      view |> element("button[phx-click='confirm_action']") |> render_click()

      refute has_element?(view, "#active-locations", "Soon Archived")
    end

    test "canceling archive dismisses modal and keeps location", %{conn: conn, group: grp} do
      Factory.location(group: grp, name: "Stays Active")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")

      view
      |> element("button[phx-click='request_archive']")
      |> render_click()

      view |> element("button", "Cancel") |> render_click()

      refute has_element?(view, "h3", "Archive Location")
      assert has_element?(view, "p", "Stays Active")
    end
  end

  describe "archived tab" do
    test "shows archived locations on archived tab", %{conn: conn, group: grp, user: usr} do
      loc = Factory.location(group: grp, name: "Old Venue")
      Tennis.archive_location!(loc, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")

      view |> element("button[phx-value-tab='archived']") |> render_click()

      assert has_element?(view, "p", "Old Venue")
    end

    test "shows empty state on archived tab when nothing is archived", %{conn: conn, group: grp} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")

      view |> element("button[phx-value-tab='archived']") |> render_click()

      assert has_element?(view, "p", "No archived locations")
    end
  end

  describe "restore confirmation flow" do
    test "restore button shows confirmation modal", %{conn: conn, group: grp, user: usr} do
      loc = Factory.location(group: grp, name: "Restorable Court")
      Tennis.archive_location!(loc, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")
      view |> element("button[phx-value-tab='archived']") |> render_click()

      view |> element("button[phx-click='request_restore']") |> render_click()

      assert has_element?(view, "h3", "Restore Location")
      assert has_element?(view, "strong", "Restorable Court")
    end

    test "confirming restore moves location back to active", %{conn: conn, group: grp, user: usr} do
      loc = Factory.location(group: grp, name: "Coming Back")
      Tennis.archive_location!(loc, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")
      view |> element("button[phx-value-tab='archived']") |> render_click()
      view |> element("button[phx-click='request_restore']") |> render_click()
      view |> element("button[phx-click='confirm_action']") |> render_click()

      view |> element("button[phx-value-tab='active']") |> render_click()

      assert has_element?(view, "p", "Coming Back")
    end

    test "canceling restore keeps location archived", %{conn: conn, group: grp, user: usr} do
      loc = Factory.location(group: grp, name: "Stays Archived")
      Tennis.archive_location!(loc, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations")
      view |> element("button[phx-value-tab='archived']") |> render_click()
      view |> element("button[phx-click='request_restore']") |> render_click()
      view |> element("button", "Cancel") |> render_click()

      refute has_element?(view, "h3", "Restore Location")
      assert has_element?(view, "p", "Stays Archived")
    end
  end
end
