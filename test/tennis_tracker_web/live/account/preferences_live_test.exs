defmodule TennisTrackerWeb.Account.PreferencesLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    user = Factory.user()
    conn = log_in_user(build_conn(), user)
    {:ok, conn: conn, user: user}
  end

  describe "sidebar group context" do
    test "shows group nav when a last group is in session", %{conn: conn, user: user} do
      group = Factory.group()
      Factory.group_membership(group: group, user: user, role: :member)

      conn = Plug.Conn.put_session(conn, "last_group_slug", group.slug)
      {:ok, view, _html} = live(conn, ~p"/account/settings/preferences")

      assert has_element?(view, "aside a[href='/g/#{group.slug}/teams']", "Teams")
    end

    test "shows no group nav when no last group is in session", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/preferences")

      refute has_element?(view, "aside nav")
    end
  end

  describe "unauthenticated access" do
    test "redirects to sign-in", %{} do
      {:error, {:redirect, %{to: path}}} = live(build_conn(), ~p"/account/settings/preferences")
      assert path =~ "/sign-in"
    end
  end

  describe "sub-navigation" do
    test "preferences tab is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/preferences")

      assert has_element?(view, ".tab-active", "Preferences")
      refute has_element?(view, ".tab-active", "Profile")
      refute has_element?(view, ".tab-active", "Security")
    end
  end

  describe "page loads" do
    test "renders preferences page with theme select element", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/preferences")

      assert has_element?(view, "h2", "Theme")
      assert has_element?(view, "select[phx-hook='ThemeSelect']")
      assert has_element?(view, "option[value='system']")
      assert has_element?(view, "option[value='light']")
      assert has_element?(view, "option[value='dark']")
    end
  end
end
