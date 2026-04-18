defmodule TennisTracker.Tennis.TagCategory do
  @moduledoc false

  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("tag_categories")
    repo(TennisTracker.Repo)
  end

  policies do
    bypass actor_attribute_equals(:role, :admin) do
      authorize_if(always())
    end

    policy action_type(:read) do
      authorize_if(TennisTracker.Policies.IsGroupMember)
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

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many :tags, TennisTracker.Tennis.Tag
  end

  actions do
    read :read do
      primary?(true)
      prepare(build(sort: [name: :asc]))
    end

    create :create do
      primary?(true)
      accept([:name, :group_id])
    end

    update :update do
      primary?(true)
      accept([:name])
    end

    destroy :destroy do
      primary?(true)
      require_atomic?(false)
    end
  end

  identities do
    identity(:unique_name_per_group, [:group_id, :name])
  end

  validations do
    validate match(:name, ~r/^[^:]+$/) do
      message("cannot contain ':'")
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
