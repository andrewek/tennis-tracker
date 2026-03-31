defmodule TennisTracker.Tennis.TeamMembership do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    extensions: [AshAdmin.Resource]

  postgres do
    table("team_memberships")
    repo(TennisTracker.Repo)

    custom_indexes do
      index([:team_type_id, :season_year])
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

  pub_sub do
    module(Phoenix.PubSub)
    name(TennisTracker.PubSub)
    prefix("roster")

    publish(:create, [:group_id, :team_type_id, :season_year])
    publish(:update, [:group_id, :team_type_id, :season_year])
    publish(:destroy, [:group_id, :team_type_id, :season_year])
  end

  admin do
    create_actions []
    update_actions []
  end

  attributes do
    uuid_v7_primary_key(:id)

    # Denormalized from the team for the unique constraint
    attribute :team_type_id, :uuid do
      allow_nil?(false)
      public?(true)
    end

    attribute :season_year, :integer do
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
    belongs_to :player, TennisTracker.Tennis.Player do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :team, TennisTracker.Tennis.Team do
      allow_nil?(false)
      public?(true)
    end
  end

  actions do
    read :read do
      primary?(true)
    end

    read :for_player do
      argument(:player_id, :uuid, allow_nil?: false)

      filter(expr(player_id == ^arg(:player_id) and team.is_pseudo == false))

      prepare(fn query, _ ->
        Ash.Query.sort(query, [
          {:season_year, :desc},
          {:team_age_group, :asc_nils_last},
          {:team_ntrp_level, :desc_nils_last}
        ])
      end)
    end

    read :for_context do
      argument(:team_type_id, :uuid, allow_nil?: false)
      argument(:season_year, :integer, allow_nil?: false)

      filter(expr(team_type_id == ^arg(:team_type_id) and season_year == ^arg(:season_year)))
    end

    read :for_team do
      argument(:team_id, :uuid, allow_nil?: false)

      filter(expr(team_id == ^arg(:team_id)))
    end

    create :create do
      primary?(true)
      accept([:player_id, :team_id, :team_type_id, :season_year, :group_id])
    end

    update :update do
      primary?(true)
      accept([:team_id])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  identities do
    identity(:unique_player_context, [:player_id, :team_type_id, :season_year])
  end

  calculations do
    calculate(
      :display_label,
      :string,
      expr(
        fragment(
          "CAST(? AS text) || ' ' || ? || ' - ' || ?",
          season_year,
          team.team_type.name,
          team.name
        )
      )
    )

    calculate(:team_age_group, :string, expr(team.team_type.age_group))
    calculate(:team_ntrp_level, :decimal, expr(team.team_type.ntrp_level))
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
