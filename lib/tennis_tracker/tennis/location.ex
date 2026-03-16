defmodule TennisTracker.Tennis.Location do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table("locations")
    repo(TennisTracker.Repo)
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

    timestamps()
  end

  identities do
    identity :unique_name, [:name]
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
      accept([:name, :address, :google_maps_url])
      upsert?(true)
      upsert_identity(:unique_name)
      upsert_fields([:address, :google_maps_url])
    end
  end
end
