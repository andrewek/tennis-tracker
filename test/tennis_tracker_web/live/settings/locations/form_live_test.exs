defmodule TennisTrackerWeb.Settings.Locations.FormLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "access control" do
    test "non-owner is redirected from new form", %{conn: conn, group: grp} do
      member_user = Factory.user()
      Factory.group_membership(group: grp, user: member_user)
      conn = log_in_user(conn, member_user)

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/g/#{grp.slug}/settings/locations/new")

      assert path == ~p"/g/#{grp.slug}"
    end

    test "non-owner is redirected from edit form", %{conn: conn, group: grp} do
      loc = Factory.location(group: grp)
      member_user = Factory.user()
      Factory.group_membership(group: grp, user: member_user)
      conn = log_in_user(conn, member_user)

      assert {:error, {:live_redirect, %{to: path}}} =
               live(conn, ~p"/g/#{grp.slug}/settings/locations/#{loc.id}/edit")

      assert path == ~p"/g/#{grp.slug}"
    end
  end

  describe "create form" do
    test "renders create form", %{conn: conn, group: grp} do
      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/settings/locations/new")

      assert html =~ "Add Location"
    end

    test "successfully creates a location and redirects", %{conn: conn, group: grp, user: usr} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations/new")

      n = System.unique_integer([:positive])
      name = "New Venue #{n}"

      {:ok, _view, html} =
        view
        |> form("form", form: %{name: name, address: "123 Test Ave"})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Location saved"

      locations = Tennis.list_locations!(tenant: grp.id, actor: usr)
      assert Enum.any?(locations, &(&1.name == name))
    end

    test "shows validation error for missing required field", %{conn: conn, group: grp} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/locations/new")

      html =
        view
        |> form("form", form: %{name: "", address: ""})
        |> render_submit()

      assert html =~ "required" or html =~ "blank"
    end
  end

  describe "edit form" do
    test "renders edit form pre-populated with location data", %{conn: conn, group: grp} do
      loc = Factory.location(group: grp, name: "My Court", address: "1 Court Lane")

      {:ok, _view, html} =
        live(conn, ~p"/g/#{grp.slug}/settings/locations/#{loc.id}/edit")

      assert html =~ "Edit Location"
      assert html =~ "My Court"
    end

    test "successfully updates a location and redirects", %{conn: conn, group: grp, user: usr} do
      loc = Factory.location(group: grp, name: "Before Update", address: "Old Address")

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/settings/locations/#{loc.id}/edit")

      n = System.unique_integer([:positive])
      new_name = "After Update #{n}"

      {:ok, _view, html} =
        view
        |> form("form", form: %{name: new_name, address: "New Address"})
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Location saved"

      updated = Tennis.get_location!(loc.id, tenant: grp.id, actor: usr)
      assert updated.name == new_name
    end
  end
end
