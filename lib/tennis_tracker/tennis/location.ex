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

    attribute :street_address, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :city, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :state, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :postal_code, :string do
      allow_nil?(true)
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
      accept([:name, :street_address, :city, :state, :postal_code, :google_maps_url, :group_id])
      change(&trim_address_fields/2)
    end

    update :update do
      primary?(true)
      require_atomic?(false)
      accept([:name, :street_address, :city, :state, :postal_code, :google_maps_url])
      change(&trim_address_fields/2)
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

  identities do
    identity(:unique_name_per_group, [:name, :group_id])
  end

  calculations do
    calculate(
      :formatted_address,
      :string,
      expr(
        fragment(
          "NULLIF(CONCAT_WS(', ', ?, ?, NULLIF(CONCAT_WS(' ', ?, ?), '')), '')",
          street_address,
          city,
          state,
          postal_code
        )
      )
    )
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end

  defp trim_address_fields(changeset, _context) do
    [:street_address, :city, :state, :postal_code]
    |> Enum.reduce(changeset, fn field, cs ->
      case Ash.Changeset.fetch_change(cs, field) do
        {:ok, value} when is_binary(value) ->
          Ash.Changeset.force_change_attribute(cs, field, String.trim(value))

        _ ->
          cs
      end
    end)
  end
end
