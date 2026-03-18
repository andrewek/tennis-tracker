defmodule TennisTracker.Tennis.TeamRole do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("team_roles")
    repo(TennisTracker.Repo)
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if(always())
    end

    policy action_type(:read) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
      authorize_if(expr(user_id == ^actor(:id)))
    end

    policy action_type(:create) do
      authorize_if(TennisTracker.Policies.IsGroupOwnerCheck)
    end

    policy action_type([:update, :destroy]) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
    end
  end

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :role, :atom do
      constraints(one_of: [:captain, :member])
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :user, TennisTracker.Accounts.User do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :team, TennisTracker.Tennis.Team do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    read :read do
      primary?(true)
    end

    read :for_team do
      argument(:team_id, :uuid, allow_nil?: false)
      filter(expr(team_id == ^arg(:team_id)))
    end

    read :for_user do
      argument(:user_id, :uuid, allow_nil?: false)
      filter(expr(user_id == ^arg(:user_id)))
    end

    create :create do
      primary?(true)
      accept([:role, :user_id, :team_id, :group_id])
    end

    update :update do
      primary?(true)
      accept([:role])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  identities do
    identity(:unique_user_team, [:user_id, :team_id])
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
