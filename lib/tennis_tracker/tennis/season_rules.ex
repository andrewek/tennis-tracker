defmodule TennisTracker.Tennis.SeasonRules do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("season_rules")
    repo(TennisTracker.Repo)
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :season_year, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :min_roster, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :max_roster, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :on_level_min_pct, :decimal do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  identities do
    identity(:unique_team_type_season, [:team_type_id, :season_year])
  end

  relationships do
    belongs_to :team_type, TennisTracker.Tennis.TeamType do
      allow_nil?(false)
      public?(true)
    end
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
      accept([:season_year, :min_roster, :max_roster, :on_level_min_pct, :team_type_id])
    end
  end
end
