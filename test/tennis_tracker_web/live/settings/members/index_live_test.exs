defmodule TennisTrackerWeb.Settings.Members.IndexLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Factory
  alias TennisTracker.Groups

  setup :setup_group_with_owner

  setup %{conn: conn, user: owner} do
    {:ok, conn: log_in_user(conn, owner)}
  end

  # ---------------------------------------------------------------------------
  # 6.1 – Access control
  # ---------------------------------------------------------------------------

  describe "access control" do
    test "owner can access the members page", %{conn: conn, group: grp} do
      {:ok, _view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members")
    end

    test "non-owner is redirected to group home", %{group: grp} do
      member = Factory.user()
      Factory.group_membership(group: grp, user: member)
      conn = log_in_user(build_conn(), member)

      {:error, {:live_redirect, %{to: to}}} =
        live(conn, ~p"/g/#{grp.slug}/settings/members")

      assert to == ~p"/g/#{grp.slug}"
    end
  end

  # ---------------------------------------------------------------------------
  # 6.1a – Navigation link
  # ---------------------------------------------------------------------------

  describe "navigation" do
    test "Members link is visible for owners", %{conn: conn, group: grp} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}")
      assert has_element?(view, "a", "Members")
    end

    test "Members link is absent for non-owners", %{group: grp} do
      member = Factory.user()
      Factory.group_membership(group: grp, user: member)
      conn = log_in_user(build_conn(), member)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}")
      refute has_element?(view, "a", "Members")
    end
  end

  # ---------------------------------------------------------------------------
  # 6.2 – Add-member form (lives at /settings/members/new)
  # ---------------------------------------------------------------------------

  describe "add-member form" do
    test "adding an existing user redirects to the member list", %{conn: conn, group: grp} do
      existing = Factory.user()

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members/new")

      assert {:error, {:live_redirect, %{to: to}}} =
               view
               |> form("#add-member-form", %{
                 "member" => %{"email" => to_string(existing.email), "role" => "member"}
               })
               |> render_submit()

      {:ok, index_view, _html} = live(conn, to)
      assert has_element?(index_view, "#memberships", to_string(existing.email))
    end

    test "adding a new user shows the temporary password card", %{conn: conn, group: grp} do
      new_email = "newperson#{System.unique_integer()}@example.com"

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members/new")

      view
      |> form("#add-member-form", %{
        "member" => %{"email" => new_email, "role" => "member"}
      })
      |> render_submit()

      assert has_element?(view, "p", "New account created")
      assert has_element?(view, "button", "Dismiss")
    end

    test "adding a duplicate member shows an inline error", %{conn: conn, group: grp} do
      existing = Factory.user()
      Factory.group_membership(group: grp, user: existing)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members/new")

      view
      |> form("#add-member-form", %{
        "member" => %{"email" => to_string(existing.email), "role" => "member"}
      })
      |> render_submit()

      assert has_element?(view, "p.text-error")
    end

    test "no password card is shown when adding an existing user", %{conn: conn, group: grp} do
      existing = Factory.user()

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members/new")

      assert {:error, {:live_redirect, %{to: to}}} =
               view
               |> form("#add-member-form", %{
                 "member" => %{"email" => to_string(existing.email), "role" => "member"}
               })
               |> render_submit()

      {:ok, index_view, _html} = live(conn, to)
      refute has_element?(index_view, "p", "New account created")
    end

    test "dismissing the password card navigates back to the member list", %{
      conn: conn,
      group: grp
    } do
      new_email = "dismiss#{System.unique_integer()}@example.com"

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members/new")

      view
      |> form("#add-member-form", %{
        "member" => %{"email" => new_email, "role" => "member"}
      })
      |> render_submit()

      assert has_element?(view, "p", "New account created")

      assert {:error, {:live_redirect, %{to: to}}} =
               render_click(view, "dismiss_password_card", %{})

      {:ok, index_view, _html} = live(conn, to)
      refute has_element?(index_view, "p", "New account created")
    end
  end

  # ---------------------------------------------------------------------------
  # 6.3 – Role change
  # ---------------------------------------------------------------------------

  describe "role change" do
    test "owner can change another member's role", %{conn: conn, group: grp, user: owner} do
      member = Factory.user()
      membership = Factory.group_membership(group: grp, user: member)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members")

      render_click(view, "change_role", %{
        "membership_id" => membership.id,
        "role" => "owner"
      })

      updated =
        Groups.list_group_memberships_for_group!(grp.id, actor: owner, tenant: grp.id)
        |> Enum.find(&(&1.user_id == member.id))

      assert updated.role == :owner
    end

    test "owner's own row has no role-change select", %{conn: conn, group: grp, user: owner} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members")

      owner_membership =
        Groups.list_group_memberships_for_group!(grp.id, actor: owner, tenant: grp.id)
        |> Enum.find(&(&1.user_id == owner.id))

      refute has_element?(view, "#memberships-#{owner_membership.id} select")
    end
  end

  # ---------------------------------------------------------------------------
  # 6.4 – Remove member
  # ---------------------------------------------------------------------------

  describe "remove member" do
    test "clicking Remove shows confirmation prompt", %{conn: conn, group: grp} do
      member = Factory.user()
      membership = Factory.group_membership(group: grp, user: member)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members")

      render_click(view, "request_remove", %{"id" => membership.id})

      assert has_element?(view, "button", "Remove")
      assert has_element?(view, "button", "Cancel")
    end

    test "cancelling removal keeps the member", %{conn: conn, group: grp} do
      member = Factory.user()
      membership = Factory.group_membership(group: grp, user: member)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members")

      render_click(view, "request_remove", %{"id" => membership.id})
      render_click(view, "cancel_remove", %{})

      assert has_element?(view, "#memberships", to_string(member.email))
    end

    test "confirming removal removes the member from the list", %{conn: conn, group: grp} do
      member = Factory.user()
      membership = Factory.group_membership(group: grp, user: member)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members")

      render_click(view, "request_remove", %{"id" => membership.id})
      render_click(view, "confirm_remove", %{"id" => membership.id})

      refute has_element?(view, "#memberships", to_string(member.email))
    end

    test "own row has no Remove button", %{conn: conn, group: grp, user: owner} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/members")

      owner_membership =
        Groups.list_group_memberships_for_group!(grp.id, actor: owner, tenant: grp.id)
        |> Enum.find(&(&1.user_id == owner.id))

      refute has_element?(view, "#memberships-#{owner_membership.id} button", "Remove")
    end
  end
end
