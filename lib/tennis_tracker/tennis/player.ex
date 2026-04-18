defmodule TennisTracker.Tennis.Player do
  @moduledoc false

  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("players")
    repo(TennisTracker.Repo)

    custom_indexes do
      index([:ntrp_rating, :name])
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
      authorize_if(TennisTracker.Policies.IsGroupMemberCheck)
    end

    policy action_type(:update) do
      authorize_if(TennisTracker.Policies.IsGroupMember)
    end

    policy action_type(:destroy) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
    end
  end

  admin do
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

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    has_many :team_memberships, TennisTracker.Tennis.TeamMembership

    many_to_many :tags, TennisTracker.Tennis.Tag do
      through(TennisTracker.Tennis.PlayerTag)
      source_attribute_on_join_resource(:player_id)
      destination_attribute_on_join_resource(:tag_id)
      public?(true)
    end
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
        :group_id
      ])
    end

    update :update do
      primary?(true)

      accept([
        :name,
        :email,
        :phone_number,
        :ntrp_rating
      ])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  validations do
    validate attribute_in(:ntrp_rating, TennisTracker.Tennis.NtrpLevels.player_levels()) do
      where([present(:ntrp_rating)])
      message("must be a valid NTRP rating (2.5, 3.0, 3.5, 4.0, 4.5, or 5.0)")
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
