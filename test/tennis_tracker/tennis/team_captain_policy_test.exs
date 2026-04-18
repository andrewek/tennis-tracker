defmodule TennisTracker.Tennis.TeamCaptainPolicyTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis
  alias TennisTracker.Groups

  require Ash.Query

  setup :setup_group_with_owner

  setup %{group: grp, user: owner} do
    team_a = Factory.team(group: grp)
    team_b = Factory.team(group: grp)

    member_user = Factory.user()
    Factory.group_membership(group: grp, user: member_user)

    captain_a = Factory.user()
    Factory.group_membership(group: grp, user: captain_a)
    Factory.team_role(group: grp, user: captain_a, team: team_a, traits: [:captain])

    outsider = Factory.user()

    {:ok,
     team_a: team_a,
     team_b: team_b,
     owner: owner,
     member: member_user,
     captain_a: captain_a,
     outsider: outsider}
  end

  # ---------------------------------------------------------------------------
  # 8.1 IsTeamCaptainForTeamRoleCheck — TeamRole create
  # ---------------------------------------------------------------------------

  describe "TeamRole create — captain of team A" do
    test "can create a TeamRole for team A", %{group: grp, team_a: team_a, captain_a: captain_a} do
      target = Factory.user()
      Factory.group_membership(group: grp, user: target)

      result =
        Tennis.create_team_role(
          %{user_id: target.id, team_id: team_a.id, group_id: grp.id, role: :captain},
          tenant: grp.id,
          actor: captain_a
        )

      assert {:ok, _} = result
    end

    test "cannot create a TeamRole for team B", %{
      group: grp,
      team_b: team_b,
      captain_a: captain_a
    } do
      target = Factory.user()
      Factory.group_membership(group: grp, user: target)

      result =
        Tennis.create_team_role(
          %{user_id: target.id, team_id: team_b.id, group_id: grp.id, role: :captain},
          tenant: grp.id,
          actor: captain_a
        )

      assert {:error, _} = result
    end
  end

  describe "TeamRole create — non-captain" do
    test "regular group member cannot create a TeamRole", %{
      group: grp,
      team_a: team_a,
      member: member
    } do
      target = Factory.user()
      Factory.group_membership(group: grp, user: target)

      result =
        Tennis.create_team_role(
          %{user_id: target.id, team_id: team_a.id, group_id: grp.id, role: :captain},
          tenant: grp.id,
          actor: member
        )

      assert {:error, _} = result
    end
  end

  # ---------------------------------------------------------------------------
  # 8.2 TeamRole read policy
  # ---------------------------------------------------------------------------

  describe "TeamRole read policy" do
    test "group member can read TeamRole records for the group", %{
      group: grp,
      team_a: team_a,
      member: member
    } do
      roles = Tennis.list_team_roles_for_team!(team_a.id, tenant: grp.id, actor: member)
      assert is_list(roles)
    end

    test "outsider sees no TeamRole records (filtered out by policy)", %{
      group: grp,
      team_a: team_a,
      outsider: outsider
    } do
      roles =
        TennisTracker.Tennis.TeamRole
        |> Ash.Query.for_read(:for_team, %{team_id: team_a.id}, actor: outsider)
        |> Ash.read!(domain: Tennis, tenant: grp.id)

      assert roles == []
    end
  end

  # ---------------------------------------------------------------------------
  # 8.3 TeamRole update/destroy
  # ---------------------------------------------------------------------------

  describe "TeamRole update" do
    test "captain of team A can update a role on team A", %{
      group: grp,
      team_a: team_a,
      captain_a: captain_a
    } do
      target = Factory.user()
      Factory.group_membership(group: grp, user: target)
      role = Factory.team_role(group: grp, user: target, team: team_a, role: :member)

      result =
        Tennis.update_team_role_role!(role, %{role: :captain},
          tenant: grp.id,
          actor: captain_a
        )

      assert result.role == :captain
    end

    test "captain of team A cannot update a role on team B", %{
      group: grp,
      team_b: team_b,
      captain_a: captain_a
    } do
      target = Factory.user()
      Factory.group_membership(group: grp, user: target)
      role = Factory.team_role(group: grp, user: target, team: team_b, role: :member)

      assert_raise Ash.Error.Forbidden, fn ->
        Tennis.update_team_role_role!(role, %{role: :captain},
          tenant: grp.id,
          actor: captain_a
        )
      end
    end

    test "regular member cannot update a role", %{group: grp, team_a: team_a, member: member} do
      target = Factory.user()
      Factory.group_membership(group: grp, user: target)
      role = Factory.team_role(group: grp, user: target, team: team_a, role: :member)

      assert_raise Ash.Error.Forbidden, fn ->
        Tennis.update_team_role_role!(role, %{role: :captain},
          tenant: grp.id,
          actor: member
        )
      end
    end
  end

  describe "TeamRole destroy" do
    test "captain of team A can destroy a role on team A", %{
      group: grp,
      team_a: team_a,
      captain_a: captain_a
    } do
      target = Factory.user()
      Factory.group_membership(group: grp, user: target)
      role = Factory.team_role(group: grp, user: target, team: team_a, role: :member)

      assert :ok = Tennis.destroy_team_role!(role, tenant: grp.id, actor: captain_a)
    end

    test "captain of team A cannot destroy a role on team B", %{
      group: grp,
      team_b: team_b,
      captain_a: captain_a
    } do
      target = Factory.user()
      Factory.group_membership(group: grp, user: target)
      role = Factory.team_role(group: grp, user: target, team: team_b, role: :member)

      assert_raise Ash.Error.Forbidden, fn ->
        Tennis.destroy_team_role!(role, tenant: grp.id, actor: captain_a)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # 8.4 GroupMembership read policy
  # ---------------------------------------------------------------------------

  describe "GroupMembership read policy" do
    test "group member can read all group memberships for the group", %{
      group: grp,
      member: member
    } do
      memberships =
        Groups.list_group_memberships_for_group!(grp.id,
          tenant: grp.id,
          actor: member
        )

      assert memberships != []
    end

    test "outsider sees no GroupMembership records (filtered out by policy)", %{
      group: grp,
      outsider: outsider
    } do
      memberships =
        TennisTracker.Groups.GroupMembership
        |> Ash.Query.for_read(:for_group, %{group_id: grp.id}, actor: outsider)
        |> Ash.read!(domain: TennisTracker.Groups)

      assert memberships == []
    end
  end
end
