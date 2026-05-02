defmodule TennisTracker.Tennis.TeamMembershipAddRemoveRosterTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.MatchLineupAssignment

  require Ash.Query

  setup :setup_group_with_owner

  setup %{group: grp, user: owner} do
    tt = Factory.team_type(group: grp)
    team = Factory.team(group: grp, team_type: tt)
    player = Factory.player(group: grp)

    captain_user = Factory.user()
    Factory.group_membership(group: grp, user: captain_user)
    Factory.team_role(group: grp, user: captain_user, team: team, traits: [:captain])

    member_user = Factory.user()
    Factory.group_membership(group: grp, user: member_user)

    {:ok,
     team: team,
     team_type: tt,
     player: player,
     owner: owner,
     captain: captain_user,
     member: member_user}
  end

  # ---------------------------------------------------------------------------
  # add_to_roster
  # ---------------------------------------------------------------------------

  describe "add_to_roster — team captain" do
    test "creates a TeamMembership", %{
      group: grp,
      team: team,
      team_type: tt,
      player: player,
      captain: captain
    } do
      assert {:ok, membership} =
               Tennis.add_to_roster(
                 %{
                   player_id: player.id,
                   team_id: team.id,
                   team_type_id: tt.id,
                   season_year: team.season_year,
                   group_id: grp.id
                 },
                 tenant: grp.id,
                 actor: captain
               )

      assert membership.player_id == player.id
      assert membership.team_id == team.id
    end
  end

  describe "add_to_roster — group owner" do
    test "creates a TeamMembership", %{
      group: grp,
      team: team,
      team_type: tt,
      player: player,
      owner: owner
    } do
      assert {:ok, membership} =
               Tennis.add_to_roster(
                 %{
                   player_id: player.id,
                   team_id: team.id,
                   team_type_id: tt.id,
                   season_year: team.season_year,
                   group_id: grp.id
                 },
                 tenant: grp.id,
                 actor: owner
               )

      assert membership.player_id == player.id
    end
  end

  describe "add_to_roster — group member (non-captain, non-owner)" do
    test "is denied with an authorization error", %{
      group: grp,
      team: team,
      team_type: tt,
      player: player,
      member: member
    } do
      assert {:error, %Ash.Error.Forbidden{}} =
               Tennis.add_to_roster(
                 %{
                   player_id: player.id,
                   team_id: team.id,
                   team_type_id: tt.id,
                   season_year: team.season_year,
                   group_id: grp.id
                 },
                 tenant: grp.id,
                 actor: member
               )
    end
  end

  # ---------------------------------------------------------------------------
  # remove_from_roster
  # ---------------------------------------------------------------------------

  describe "remove_from_roster — no match assignments" do
    test "destroys the TeamMembership", %{
      group: grp,
      team: team,
      player: player,
      captain: captain
    } do
      membership = Factory.team_membership(group: grp, player: player, team: team)

      assert :ok = Tennis.remove_from_roster(membership, tenant: grp.id, actor: captain)

      memberships =
        Tennis.list_memberships_for_team!(team.id, tenant: grp.id, authorize?: false)

      refute Enum.any?(memberships, &(&1.player_id == player.id))
    end
  end

  describe "remove_from_roster — player has match lineup assignment" do
    test "fails with a validation error", %{group: grp, owner: owner} do
      team = Factory.team(group: grp)
      player = Factory.player(group: grp)
      membership = Factory.team_membership(group: grp, player: player, team: team)
      match = Factory.match(group: grp, team: team)

      slots = Tennis.list_lineup_slots_for_team!(team.id, tenant: grp.id, authorize?: false)
      slot = Enum.find(slots, &(&1.participation_type == :playing))

      MatchLineupAssignment
      |> Ash.Changeset.for_create(
        :create,
        %{
          match_id: match.id,
          player_id: player.id,
          team_lineup_slot_id: slot.id,
          group_id: grp.id
        },
        domain: Tennis,
        tenant: grp.id,
        authorize?: false
      )
      |> Ash.create!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               Tennis.remove_from_roster(membership, tenant: grp.id, actor: owner)
    end
  end

  describe "remove_from_roster — group member (non-captain, non-owner)" do
    test "is denied with an authorization error", %{
      group: grp,
      team: team,
      player: player,
      member: member
    } do
      membership = Factory.team_membership(group: grp, player: player, team: team)

      assert {:error, %Ash.Error.Forbidden{}} =
               Tennis.remove_from_roster(membership, tenant: grp.id, actor: member)
    end
  end
end
