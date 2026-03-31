defmodule TennisTracker.Tennis.MatchLineupAssignment do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshAdmin.Resource]

  postgres do
    table("match_lineup_assignments")
    repo(TennisTracker.Repo)

    references do
      reference(:team_lineup_slot, on_delete: :delete)
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
      authorize_if(TennisTracker.Policies.IsTeamCaptainForLineupAssignmentCheck)
    end

    policy action_type([:update, :destroy]) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
      authorize_if(TennisTracker.Policies.IsTeamCaptainForLineupAssignment)
    end
  end

  pub_sub do
    module(Phoenix.PubSub)
    name(TennisTracker.PubSub)
    prefix("lineup")

    publish(:create, [:group_id, :match_id])
    publish(:update, [:group_id, :match_id])
    publish(:destroy, [:group_id, :match_id])
  end

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :group_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :match, TennisTracker.Tennis.Match do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :player, TennisTracker.Tennis.Player do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :team_lineup_slot, TennisTracker.Tennis.TeamLineupSlot do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    read :read do
      primary?(true)
    end

    read :for_match do
      argument(:match_id, :uuid, allow_nil?: false)
      filter(expr(match_id == ^arg(:match_id)))
    end

    create :create do
      primary?(true)
      accept([:match_id, :player_id, :team_lineup_slot_id, :group_id])
    end

    update :update do
      primary?(true)
      accept([:team_lineup_slot_id])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  identities do
    identity(:player_per_match, [:match_id, :player_id])
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
