defmodule TennisTracker.Tennis.SeasonRules do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("season_rules")
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
    table_columns [:season_year, :team_type, :min_roster, :max_roster, :on_level_min_pct]
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :season_year, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :min_roster, :integer do
      allow_nil?(true)
      public?(true)
    end

    attribute :max_roster, :integer do
      allow_nil?(true)
      public?(true)
    end

    attribute :on_level_min_pct, :decimal do
      allow_nil?(true)
      public?(true)
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

    many_to_many :default_tags, TennisTracker.Tennis.Tag do
      through(TennisTracker.Tennis.SeasonRulesDefaultTag)
      source_attribute_on_join_resource(:season_rules_id)
      destination_attribute_on_join_resource(:tag_id)
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

      accept([
        :season_year,
        :min_roster,
        :max_roster,
        :on_level_min_pct,
        :team_type_id,
        :group_id
      ])
    end

    update :update do
      primary?(true)
      accept([:min_roster, :max_roster, :on_level_min_pct])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  identities do
    identity(:unique_team_type_season, [:group_id, :team_type_id, :season_year])
  end

  validations do
    validate numericality(:min_roster, greater_than: 0) do
      where([present(:min_roster)])
      message("must be a positive integer")
    end

    validate numericality(:max_roster, greater_than: 0) do
      where([present(:max_roster)])
      message("must be a positive integer")
    end

    validate numericality(:on_level_min_pct,
               greater_than_or_equal_to: 0,
               less_than_or_equal_to: 100
             ) do
      where([present(:on_level_min_pct)])
      message("must be between 0.0 and 100.0")
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
