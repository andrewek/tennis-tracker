defmodule TennisTrackerWeb.Account.SecurityLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @password "Password1!"

  setup do
    user = Factory.user(password: @password)
    {:ok, user: user}
  end

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "sidebar group context" do
    test "shows group nav when a last group is in session", %{conn: conn, user: user} do
      group = Factory.group()
      Factory.group_membership(group: group, user: user, role: :member)

      conn = Plug.Conn.put_session(conn, "last_group_slug", group.slug)
      {:ok, view, _html} = live(conn, ~p"/account/settings/security")

      assert has_element?(view, "aside a[href='/g/#{group.slug}/teams']", "Teams")
    end

    test "shows no group nav when no last group is in session", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/security")

      refute has_element?(view, "aside nav")
    end
  end

  describe "unauthenticated access" do
    test "redirects to sign-in", %{} do
      {:error, {:redirect, %{to: path}}} = live(build_conn(), ~p"/account/settings/security")
      assert path =~ "/sign-in"
    end
  end

  describe "sub-navigation" do
    test "security tab is active", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/security")

      assert has_element?(view, ".tab-active", "Security")
      refute has_element?(view, ".tab-active", "Profile")
      refute has_element?(view, ".tab-active", "Preferences")
    end
  end

  describe "page loads" do
    test "renders security page with password form and warning", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/security")

      assert has_element?(view, "[role='alert']", "sign you out of all sessions")
      assert has_element?(view, "[name='password_form[current_password]']")
      assert has_element?(view, "[name='password_form[password]']")
      assert has_element?(view, "[name='password_form[password_confirmation]']")
    end
  end

  describe "password change" do
    test "redirects to sign-in on successful password change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/security")

      result =
        view
        |> form("#security-form",
          password_form: %{
            current_password: @password,
            password: "NewPassword1!",
            password_confirmation: "NewPassword1!"
          }
        )
        |> render_submit()

      assert {:error, {:redirect, %{to: "/sign-out"}}} = result
    end

    test "shows error when current password is wrong", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/security")

      view
      |> form("#security-form",
        password_form: %{
          current_password: "WrongPassword!",
          password: "NewPassword1!",
          password_confirmation: "NewPassword1!"
        }
      )
      |> render_submit()

      assert has_element?(view, "p", "was incorrect")
    end

    test "shows error when new password and confirmation do not match", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account/settings/security")

      view
      |> form("#security-form",
        password_form: %{
          current_password: @password,
          password: "NewPassword1!",
          password_confirmation: "DifferentPassword1!"
        }
      )
      |> render_submit()

      assert has_element?(view, "p", "confirmation did not match value")
    end
  end
end
