defmodule TennisTracker.Tennis.Location do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("locations")
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

    attribute :address, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :google_maps_url, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  actions do
    read :read do
      primary?(true)
    end

    read :list_locations do
      prepare(fn query, _ -> Ash.Query.sort(query, :name) end)
    end

    create :create do
      primary?(true)
      accept([:name, :address, :google_maps_url, :group_id])
      upsert?(true)
      upsert_identity(:unique_name)
      upsert_fields([:address, :google_maps_url])
    end
  end

  identities do
    identity(:unique_name, [:group_id, :name])
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
