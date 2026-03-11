defmodule TennisTracker.Tennis.Player do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("players")
    repo(TennisTracker.Repo)

    custom_indexes do
      index([:ntrp_rating, :name])
    end
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :email, :string do
      public?(true)
    end

    attribute :phone_number, :string do
      public?(true)
    end

    attribute :ntrp_rating, :decimal do
      public?(true)
    end

    attribute :eligible_18_plus, :boolean do
      public?(true)
      default(true)
      allow_nil?(false)
    end

    attribute :eligible_40_plus, :boolean do
      public?(true)
      default(false)
      allow_nil?(false)
    end

    attribute :eligible_55_plus, :boolean do
      public?(true)
      default(false)
      allow_nil?(false)
    end

    timestamps()
  end

  validations do
    validate attribute_in(:ntrp_rating, TennisTracker.Tennis.NtrpLevels.player_levels()) do
      where([present(:ntrp_rating)])
      message("must be a valid NTRP rating (2.5, 3.0, 3.5, 4.0, 4.5, or 5.0)")
    end
  end

  relationships do
    has_many :team_memberships, TennisTracker.Tennis.TeamMembership
  end

  actions do
    read :read do
      primary?(true)
    end

    create :create do
      primary?(true)

      accept([
        :name,
        :email,
        :phone_number,
        :ntrp_rating,
        :eligible_18_plus,
        :eligible_40_plus,
        :eligible_55_plus
      ])
    end

    update :update do
      primary?(true)

      accept([
        :name,
        :email,
        :phone_number,
        :ntrp_rating,
        :eligible_18_plus,
        :eligible_40_plus,
        :eligible_55_plus
      ])
    end

    destroy :destroy do
      primary?(true)
    end
  end
end
