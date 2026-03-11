defmodule TennisTracker.Tennis.TeamType do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("team_types")
    repo(TennisTracker.Repo)
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :age_group, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :ntrp_level, :decimal do
      allow_nil?(false)
      public?(true)
    end

    attribute :allowed_ntrp_levels, {:array, :decimal} do
      allow_nil?(false)
      public?(true)
      default([])
    end

    timestamps()
  end

  validations do
    validate(attribute_in(:age_group, ["18_plus", "40_plus"]))

    validate(
      attribute_in(:ntrp_level, [
        Decimal.new("3.0"),
        Decimal.new("3.5"),
        Decimal.new("4.0"),
        Decimal.new("4.5")
      ])
    )
  end

  relationships do
    has_many :teams, TennisTracker.Tennis.Team
    has_many :season_rules, TennisTracker.Tennis.SeasonRules
  end

  actions do
    read :read do
      primary?(true)
    end

    create :create do
      primary?(true)
      accept([:name, :age_group, :ntrp_level, :allowed_ntrp_levels])
    end
  end
end
