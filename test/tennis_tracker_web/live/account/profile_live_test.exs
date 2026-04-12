defmodule TennisTrackerWeb.Account.ProfileLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Accounts

  setup do
    user = Factory.user(email: "jane@example.com")
    {:ok, user: user}
  end

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "sidebar group context" do
    test "shows group nav when a last group is in session", %{conn: conn, user: user} do
      group = Factory.group(slug: "my-org")
      Factory.group_membership(group: group, user: user, role: :member)

      conn = Plug.Conn.put_session(conn, "last_group_slug", group.slug)
      {:ok, view, _html} = live(conn, ~p"/account/settings/profile")

      assert has_element?(view, "aside a[href='/g/#{group.slug}/teams']", "Teams")
      assert has_element?(view, "aside a[href='/g/#{group.slug}/players']", "Players")
    end

    test "shows no group nav when no last group is in session", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/profile")

      refute has_element?(view, "aside nav")
    end
  end

  describe "unauthenticated access" do
    test "redirects to sign-in", %{} do
      {:error, {:redirect, %{to: path}}} = live(build_conn(), ~p"/account/settings/profile")
      assert path =~ "/sign-in"
    end
  end

  describe "sub-navigation" do
    test "profile tab is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/profile")

      assert has_element?(view, ".tab-active", "Profile")
      refute has_element?(view, ".tab-active", "Security")
      refute has_element?(view, ".tab-active", "Preferences")
    end
  end

  describe "page loads" do
    test "renders profile page with name and email forms", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/profile")

      assert has_element?(view, "h2", "Name")
      assert has_element?(view, "h2", "Email Address")
      assert has_element?(view, "#name-form")
      assert has_element?(view, "#email-form")
    end

    test "forms are pre-populated with the user's current values", %{conn: conn, user: user} do
      {:ok, _user} = Accounts.update_profile(user, %{name: "Jane Doe"}, authorize?: false)

      {:ok, view, _html} = live(conn, ~p"/account/settings/profile")

      assert has_element?(view, "#name-form input[value='Jane Doe']")
      assert has_element?(view, "#email-form input[value='jane@example.com']")
    end
  end

  describe "name update" do
    test "succeeds with valid name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/profile")

      view
      |> form("#name-form", name_form: %{name: "New Name"})
      |> render_submit()

      assert has_element?(view, "[role='alert']", "Name updated successfully")
    end
  end

  describe "email update" do
    test "succeeds with an unused email address", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/profile")

      view
      |> form("#email-form", email_form: %{email: "new_unique@example.com"})
      |> render_submit()

      assert has_element?(view, "[role='alert']", "Email updated successfully")
    end

    test "shows error when email format is invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/profile")

      view
      |> form("#email-form", email_form: %{email: "not-an-email"})
      |> render_submit()

      assert has_element?(view, "p", "must match")
    end

    test "shows error when email is already taken", %{conn: conn} do
      _other = Factory.user(email: "taken@example.com")

      {:ok, view, _html} = live(conn, ~p"/account/settings/profile")

      view
      |> form("#email-form", email_form: %{email: "taken@example.com"})
      |> render_submit()

      assert has_element?(view, "p", "has already been taken")
    end
  end
end
