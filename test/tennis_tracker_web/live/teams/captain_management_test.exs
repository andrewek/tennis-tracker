defmodule TennisTrackerWeb.Teams.CaptainManagementTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{group: grp, user: owner} do
    team = Factory.team(group: grp)

    captain_user = Factory.user()
    Factory.group_membership(group: grp, user: captain_user)
    Factory.team_role(group: grp, user: captain_user, team: team, traits: [:captain])

    member_user = Factory.user()
    Factory.group_membership(group: grp, user: member_user)

    {:ok, team: team, owner: owner, captain: captain_user, member: member_user}
  end

  # ---------------------------------------------------------------------------
  # Edit page — captain section visibility
  # ---------------------------------------------------------------------------

  describe "edit page — group owner" do
    # 8.6
    test "sees Captains section with controls", %{conn: conn, group: grp, user: owner, team: team} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      assert has_element?(view, "h2", "Captains")
      assert has_element?(view, "button", "Add Captain")
    end
  end

  describe "edit page — team captain" do
    # 8.7
    test "sees Captains section with controls", %{
      conn: conn,
      group: grp,
      captain: captain,
      team: team
    } do
      conn = log_in_user(conn, captain)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      assert has_element?(view, "h2", "Captains")
      assert has_element?(view, "button", "Add Captain")
    end
  end

  describe "edit page — regular group member" do
    # 8.8
    test "is redirected to show page", %{conn: conn, group: grp, member: member, team: team} do
      conn = log_in_user(conn, member)

      {:error, {:live_redirect, %{to: to}}} =
        live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      assert to == ~p"/g/#{grp.slug}/teams/#{team.id}"
    end
  end

  # ---------------------------------------------------------------------------
  # Adding captains
  # ---------------------------------------------------------------------------

  describe "add_captain — no existing TeamRole" do
    # 8.9
    test "creates a new :captain TeamRole and refreshes list", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team
    } do
      target = Factory.user()
      Factory.group_membership(group: grp, user: target)

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view |> render_hook("select_captain_candidate", %{"user_id" => target.id})
      view |> render_hook("add_captain", %{})

      assert has_element?(view, "#captains-list", target.name || to_string(target.email))

      roles = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)
      assert Enum.any?(roles, &(&1.user_id == target.id && &1.role == :captain))
    end
  end

  describe "add_captain — existing :member TeamRole" do
    # 8.10
    test "updates the role to :captain", %{conn: conn, group: grp, user: owner, team: team} do
      target = Factory.user()
      Factory.group_membership(group: grp, user: target)
      Factory.team_role(group: grp, user: target, team: team, role: :member)

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view |> render_hook("select_captain_candidate", %{"user_id" => target.id})
      view |> render_hook("add_captain", %{})

      roles = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)
      assert Enum.any?(roles, &(&1.user_id == target.id && &1.role == :captain))
    end
  end

  describe "add_captain — no candidate selected" do
    # 8.10a
    test "is a no-op when candidate_user_id is nil", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team
    } do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      roles_before = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)

      view |> render_hook("add_captain", %{})

      roles_after = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)
      assert length(roles_before) == length(roles_after)
    end
  end

  # ---------------------------------------------------------------------------
  # Removal modal
  # ---------------------------------------------------------------------------

  describe "removal modal — remove from team entirely" do
    # 8.11
    test "destroys the TeamRole", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team,
      captain: captain
    } do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      [role] = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)

      view |> render_hook("remove_captain", %{"team_role_id" => role.id})
      view |> render_hook("confirm_remove_entirely", %{})

      roles = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)
      refute Enum.any?(roles, &(&1.user_id == captain.id))
    end
  end

  describe "removal modal — convert to member" do
    # 8.12
    test "updates the role to :member", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team,
      captain: captain
    } do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      [role] = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)

      view |> render_hook("remove_captain", %{"team_role_id" => role.id})
      view |> render_hook("confirm_convert_to_member", %{})

      captains = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)
      refute Enum.any?(captains, &(&1.user_id == captain.id))

      all_roles = Tennis.list_team_roles_for_team!(team.id, tenant: grp.id, authorize?: false)
      assert Enum.any?(all_roles, &(&1.user_id == captain.id && &1.role == :member))
    end
  end

  describe "removal modal — cancel" do
    # 8.13
    test "makes no changes to TeamRole", %{conn: conn, group: grp, user: owner, team: team} do
      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      roles_before = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)
      [role] = roles_before

      view |> render_hook("remove_captain", %{"team_role_id" => role.id})
      view |> render_hook("cancel_remove", %{})

      roles_after = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)
      assert length(roles_before) == length(roles_after)

      refute has_element?(view, "button", "Remove from team entirely")
    end
  end

  describe "removal modal — captain removes themselves" do
    test "captain can destroy their own TeamRole", %{
      conn: conn,
      group: grp,
      captain: captain,
      team: team
    } do
      conn = log_in_user(conn, captain)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      [role] = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)

      view |> render_hook("remove_captain", %{"team_role_id" => role.id})
      view |> render_hook("confirm_remove_entirely", %{})

      roles = Tennis.list_captains_for_team!(team.id, tenant: grp.id, authorize?: false)
      refute Enum.any?(roles, &(&1.user_id == captain.id))
    end
  end

  # ---------------------------------------------------------------------------
  # Show page — captains section
  # ---------------------------------------------------------------------------

  describe "show page — captains section" do
    # 8.14
    test "any group member sees captain names", %{
      conn: conn,
      group: grp,
      member: member,
      team: team,
      captain: captain
    } do
      conn = log_in_user(conn, member)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}")

      assert has_element?(view, "h2", "Captains")
      assert has_element?(view, "#captains-list", captain.name || to_string(captain.email))
    end

    # 8.15
    test "shows empty state when no captains assigned", %{conn: conn, group: grp, user: owner} do
      team = Factory.team(group: grp)

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}")

      assert has_element?(view, "h2", "Captains")
      assert has_element?(view, "p", "No captains assigned")
    end
  end

  # ---------------------------------------------------------------------------
  # 8.5 User.name display fallback
  # ---------------------------------------------------------------------------

  describe "captain display name" do
    test "falls back to email when name is nil", %{
      conn: conn,
      group: grp,
      user: owner,
      team: team,
      captain: captain
    } do
      assert is_nil(captain.name)

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      assert has_element?(view, "#captains-list", to_string(captain.email))
    end

    test "shows name when set", %{conn: conn, group: grp, user: owner, team: team} do
      named_user = Factory.user()
      Factory.group_membership(group: grp, user: named_user)

      {:ok, named_user} =
        Ash.update(named_user, %{name: "Named Captain"},
          action: :update_profile,
          domain: TennisTracker.Accounts,
          authorize?: false
        )

      Factory.team_role(group: grp, user: named_user, team: team, traits: [:captain])

      conn = log_in_user(conn, owner)
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      assert has_element?(view, "#captains-list", "Named Captain")
    end
  end
end
