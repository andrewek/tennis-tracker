defmodule TennisTracker.Groups.GroupMembershipPolicyTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Factory
  alias TennisTracker.Groups

  setup do
    owner = Factory.user()
    member = Factory.user()
    other_owner = Factory.user()
    grp = Factory.group()
    owner_membership = Factory.group_membership(group: grp, user: owner, traits: [:owner])
    member_membership = Factory.group_membership(group: grp, user: member)

    other_owner_membership =
      Factory.group_membership(group: grp, user: other_owner, traits: [:owner])

    %{
      owner: owner,
      member: member,
      other_owner: other_owner,
      group: grp,
      owner_membership: owner_membership,
      member_membership: member_membership,
      other_owner_membership: other_owner_membership
    }
  end

  describe ":update_role action" do
    test "owner can change another member's role", %{
      owner: owner,
      member_membership: membership,
      group: grp
    } do
      assert {:ok, updated} =
               Groups.update_group_membership_role(membership, %{role: :owner},
                 actor: owner,
                 tenant: grp.id
               )

      assert updated.role == :owner
    end

    test "owner cannot change their own role", %{
      owner: owner,
      owner_membership: membership,
      group: grp
    } do
      assert {:error, _} =
               Groups.update_group_membership_role(membership, %{role: :member},
                 actor: owner,
                 tenant: grp.id
               )
    end

    test "non-owner cannot update roles", %{
      member: member,
      member_membership: membership,
      other_owner_membership: other_membership,
      group: grp
    } do
      assert {:error, _} =
               Groups.update_group_membership_role(other_membership, %{role: :member},
                 actor: member,
                 tenant: grp.id
               )

      assert {:error, _} =
               Groups.update_group_membership_role(membership, %{role: :owner},
                 actor: member,
                 tenant: grp.id
               )
    end
  end

  describe "destroy policy" do
    test "owner can remove another member", %{
      owner: owner,
      member_membership: membership,
      group: grp
    } do
      assert :ok =
               Ash.destroy(membership, actor: owner, tenant: grp.id, domain: Groups)
    end

    test "owner cannot destroy their own membership", %{
      owner: owner,
      owner_membership: membership,
      group: grp
    } do
      assert {:error, _} =
               Ash.destroy(membership, actor: owner, tenant: grp.id, domain: Groups)
    end
  end
end
