defmodule TennisTracker.Tennis.Team do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("teams")
    repo(TennisTracker.Repo)

    custom_indexes do
      index([:season_year])
      index([:team_type_id, :season_year])
    end
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :captain, :string do
      allow_nil?(true)
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

    timestamps()
  end

  relationships do
    belongs_to :team_type, TennisTracker.Tennis.TeamType do
      allow_nil?(false)
      public?(true)
    end

    has_many :memberships, TennisTracker.Tennis.TeamMembership
  end

  actions do
    read :read do
      primary?(true)
    end

    read :for_context do
      argument(:team_type_id, :uuid, allow_nil?: false)
      argument(:season_year, :integer, allow_nil?: false)

      filter(expr(team_type_id == ^arg(:team_type_id) and season_year == ^arg(:season_year)))
    end

    create :create do
      primary?(true)
      accept([:name, :captain, :season_year, :is_pseudo, :team_type_id])
    end

    update :update do
      primary?(true)
      accept([:name, :captain])
    end

    destroy :destroy do
      primary?(true)
    end
  end
end
