defmodule TennisTracker.Tennis.PlayerTag do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("player_tags")
    repo(TennisTracker.Repo)

    references do
      reference(:tag, on_delete: :delete)
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

    policy action_type(:destroy) do
      authorize_if(TennisTracker.Policies.IsGroupMember)
    end
  end

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :player_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :tag_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end
  end

  relationships do
    belongs_to :player, TennisTracker.Tennis.Player do
      allow_nil?(false)
      public?(true)
      define_attribute?(false)
      source_attribute(:player_id)
      destination_attribute(:id)
    end

    belongs_to :tag, TennisTracker.Tennis.Tag do
      allow_nil?(false)
      public?(true)
      define_attribute?(false)
      source_attribute(:tag_id)
      destination_attribute(:id)
    end
  end

  actions do
    read :read do
      primary?(true)
    end

    create :create do
      primary?(true)
      accept([:player_id, :tag_id, :group_id])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  identities do
    identity(:unique_player_tag, [:player_id, :tag_id])
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
