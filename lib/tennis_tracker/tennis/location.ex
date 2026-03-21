defmodule TennisTracker.Tennis.Location do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource, AshArchival.Resource]

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

    policy action_type(:update) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
    end
  end

  admin do
  end

  archive do
    exclude_read_actions [:archived, :load_for_relationship]
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

    read :archived do
      filter(expr(not is_nil(archived_at)))
      prepare(fn query, _ -> Ash.Query.sort(query, :name) end)
    end

    read :load_for_relationship do
    end

    create :create do
      primary?(true)
      accept([:name, :address, :google_maps_url, :group_id])
    end

    update :update do
      primary?(true)
      accept([:name, :address, :google_maps_url])
    end

    update :archive do
      accept([])
      require_atomic?(false)

      change(fn changeset, _ ->
        Ash.Changeset.force_change_attribute(changeset, :archived_at, DateTime.utc_now())
      end)
    end

    update :unarchive do
      accept([])
      change(set_attribute(:archived_at, nil))
      atomic_upgrade_with(:archived)
    end

    destroy :destroy do
      primary?(true)
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
