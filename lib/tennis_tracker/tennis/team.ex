defmodule TennisTracker.Tennis.Team do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    primary_read_warning?: false,
    extensions: [AshAdmin.Resource]

  postgres do
    table("teams")
    repo(TennisTracker.Repo)

    custom_indexes do
      index([:season_year])
      index([:team_type_id, :season_year])
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
    end

    policy action_type([:update, :destroy]) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
    end
  end

  pub_sub do
    module(Phoenix.PubSub)
    name(TennisTracker.PubSub)
    prefix("roster")

    publish(:create, [:group_id, :team_type_id, :season_year])
    publish(:update, [:group_id, :team_type_id, :season_year])
    publish(:destroy, [:group_id, :team_type_id, :season_year])
  end

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :season_year, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :is_pseudo, :boolean do
      allow_nil?(false)
      public?(true)
      default(false)
    end

    attribute :default_timezone, :string do
      allow_nil?(true)
      public?(true)
      default("America/Chicago")
    end

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :team_type, TennisTracker.Tennis.TeamType do
      allow_nil?(false)
      public?(true)
    end

    has_many :memberships, TennisTracker.Tennis.TeamMembership
    has_many :matches, TennisTracker.Tennis.Match
    has_many :team_roles, TennisTracker.Tennis.TeamRole
  end

  actions do
    read :read do
      primary?(true)
      prepare(&default_sort/2)
    end

    read :list_real do
      filter(expr(is_pseudo == false))
      prepare(&default_sort/2)
    end

    read :for_context do
      argument(:team_type_id, :uuid, allow_nil?: false)
      argument(:season_year, :integer, allow_nil?: false)

      filter(expr(team_type_id == ^arg(:team_type_id) and season_year == ^arg(:season_year)))
    end

    create :create do
      primary?(true)
      accept([:name, :season_year, :is_pseudo, :team_type_id, :group_id])
    end

    update :update do
      primary?(true)
      accept([:name, :default_timezone])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  aggregates do
    first :next_match_start_datetime, :matches, :match_start_datetime do
      filter(expr(match_start_datetime >= fragment("NOW()")))
      sort(match_start_datetime: :asc)
    end
  end

  defp default_sort(query, _context) do
    Ash.Query.sort(query, [
      {:season_year, :desc},
      {:team_type_age_group, :asc_nils_last},
      {:team_type_ntrp_level, :desc_nils_last},
      {:name, :asc}
    ])
  end

  calculations do
    calculate(:team_type_name, :string, expr(team_type.name))
    calculate(:team_type_age_group, :string, expr(team_type.age_group))
    calculate(:team_type_ntrp_level, :decimal, expr(team_type.ntrp_level))
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
