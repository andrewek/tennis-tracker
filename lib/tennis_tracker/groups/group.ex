defmodule TennisTracker.Groups.Group do
  @moduledoc false

  use Ash.Resource,
    domain: TennisTracker.Groups,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("groups")
    repo(TennisTracker.Repo)
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if(always())
    end

    policy action_type(:read) do
      authorize_if(expr(exists(group_memberships, user_id == ^actor(:id))))
    end

    policy action_type([:create, :update, :destroy]) do
      forbid_if(always())
    end
  end

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :slug, :string do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many :group_memberships, TennisTracker.Groups.GroupMembership
  end

  actions do
    read :read do
      primary?(true)
    end

    create :create do
      primary?(true)
      accept([:name, :slug])
    end

    update :update do
      primary?(true)
      accept([:name, :slug])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  identities do
    identity(:unique_slug, [:slug])
  end
end
