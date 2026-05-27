defmodule TennisTracker.Tennis.Tag do
  @moduledoc false

  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("tags")
    repo(TennisTracker.Repo)

    custom_indexes do
      index([:group_id, :tag_category_id, "lower(name)"],
        unique: true,
        name: "tags_unique_name_per_category_group"
      )
    end

    references do
      reference(:tag_category, on_delete: :delete)
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

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :tag_category, TennisTracker.Tennis.TagCategory do
      allow_nil?(false)
      public?(true)
    end

    has_many :player_tags, TennisTracker.Tennis.PlayerTag

    has_many :season_rules_default_tags, TennisTracker.Tennis.SeasonRulesDefaultTag

    many_to_many :players, TennisTracker.Tennis.Player do
      through(TennisTracker.Tennis.PlayerTag)
      source_attribute_on_join_resource(:tag_id)
      destination_attribute_on_join_resource(:player_id)
      public?(true)
    end
  end

  actions do
    read :read do
      primary?(true)
    end

    read :list do
      prepare(build(sort: [name: :asc]))
    end

    create :create do
      primary?(true)
      accept([:name, :group_id, :tag_category_id])
    end

    update :update do
      primary?(true)
      accept([:name])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  validations do
    validate match(:name, ~r/^[^:]+$/) do
      message("cannot contain ':'")
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
