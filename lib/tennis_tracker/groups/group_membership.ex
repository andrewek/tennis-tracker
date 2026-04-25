defmodule TennisTracker.Groups.GroupMembership do
  @moduledoc false

  use Ash.Resource,
    domain: TennisTracker.Groups,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("group_memberships")
    repo(TennisTracker.Repo)
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if(always())
    end

    policy action_type(:read) do
      authorize_if(expr(user_id == ^actor(:id)))
      authorize_if(TennisTracker.Policies.IsGroupOwner)
      authorize_if(TennisTracker.Policies.IsGroupMember)
    end

    policy action_type(:create) do
      authorize_if(TennisTracker.Policies.IsGroupOwnerCheck)
    end

    policy action(:update_role) do
      forbid_if(expr(user_id == ^actor(:id)))
      authorize_if(TennisTracker.Policies.IsGroupOwner)
    end

    policy action(:destroy) do
      forbid_if(expr(user_id == ^actor(:id)))
      authorize_if(TennisTracker.Policies.IsGroupOwner)
    end

    policy action_type([:update, :destroy]) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
    end
  end

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :role, :atom do
      constraints(one_of: [:owner, :member])
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :group, TennisTracker.Groups.Group do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :user, TennisTracker.Accounts.User do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    read :read do
      primary?(true)
    end

    read :for_user do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id)))
    end

    read :for_group do
      argument(:group_id, :uuid, allow_nil?: false)
      filter(expr(group_id == ^arg(:group_id)))
      prepare(fn query, _ -> Ash.Query.load(query, :user) end)
    end

    read :candidate_members_for_team do
      argument(:group_id, :uuid, allow_nil?: false)
      argument(:team_id, :uuid, allow_nil?: false)

      filter(
        expr(
          group_id == ^arg(:group_id) and
            not exists(
              TennisTracker.Tennis.TeamRole,
              team_id == ^arg(:team_id) and user_id == parent(user_id) and role == :captain
            )
        )
      )

      prepare(fn query, _ -> Ash.Query.load(query, :user) end)
    end

    read :groups_for_user do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id)))
      prepare(fn query, _ -> Ash.Query.load(query, :group) end)
    end

    create :create do
      primary?(true)
      accept([:role, :user_id, :group_id])
    end

    update :update do
      primary?(true)
      accept([:role])
    end

    update :update_role do
      accept([:role])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  identities do
    identity(:unique_user_group, [:user_id, :group_id])
  end
end
