defmodule TennisTracker.Tennis.TeamLineupColumn do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    primary_read_warning?: false,
    extensions: [AshAdmin.Resource]

  require Ash.Query

  postgres do
    table("team_lineup_columns")
    repo(TennisTracker.Repo)

    references do
      reference(:team, on_delete: :delete)
    end
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
      authorize_if(TennisTracker.Policies.IsTeamCaptainCheck)
    end

    policy action_type([:update, :destroy]) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
      authorize_if(TennisTracker.Policies.IsTeamCaptain)
    end
  end

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
      constraints(min_length: 1, max_length: 50)
    end

    attribute :sort_order, :integer do
      allow_nil?(false)
      public?(true)
      default(0)
    end

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :team, TennisTracker.Tennis.Team do
      allow_nil?(false)
      public?(true)
    end

    has_many :lineup_slots, TennisTracker.Tennis.TeamLineupSlot
  end

  actions do
    read :read do
      primary?(true)

      prepare(fn query, _ ->
        Ash.Query.sort(query, sort_order: :asc)
      end)
    end

    read :for_team do
      argument(:team_id, :uuid, allow_nil?: false)
      filter(expr(team_id == ^arg(:team_id)))

      prepare(fn query, _ ->
        Ash.Query.sort(query, sort_order: :asc)
      end)
    end

    create :create do
      primary?(true)
      accept([:name, :team_id, :group_id])

      change(fn changeset, context ->
        team_id = Ash.Changeset.get_attribute(changeset, :team_id)
        tenant = context.tenant

        if team_id && tenant do
          max_column =
            TennisTracker.Tennis.TeamLineupColumn
            |> Ash.Query.filter(team_id == ^team_id)
            |> Ash.Query.sort(sort_order: :desc)
            |> Ash.Query.limit(1)
            |> Ash.read_one!(domain: TennisTracker.Tennis, tenant: tenant, authorize?: false)

          next_sort_order =
            case max_column do
              nil -> 0
              col -> col.sort_order + 1
            end

          Ash.Changeset.force_change_attribute(changeset, :sort_order, next_sort_order)
        else
          changeset
        end
      end)
    end

    update :update do
      primary?(true)
      accept([:name, :sort_order])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  identities do
    identity(:unique_column_name_per_team, [:team_id, :name])
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
