defmodule TennisTracker.Tennis.TeamType do
  @moduledoc false

  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("team_types")
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
    relationship_display_fields [:name]
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :age_group, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :ntrp_level, :decimal do
      allow_nil?(true)
      public?(true)
    end

    attribute :allowed_ntrp_levels, {:array, :decimal} do
      allow_nil?(false)
      public?(true)
      default([])
    end

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
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
      accept([:name, :age_group, :ntrp_level, :allowed_ntrp_levels, :group_id])
    end

    update :update do
      primary?(true)
      accept([:name, :age_group, :ntrp_level, :allowed_ntrp_levels])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  validations do
    validate attribute_in(:age_group, ["18_plus", "40_plus"]) do
      where([present(:age_group)])
    end

    validate attribute_in(:ntrp_level, TennisTracker.Tennis.NtrpLevels.team_levels()) do
      where([present(:ntrp_level)])
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
