defmodule TennisTracker.Tennis.TeamMembership do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("team_memberships")
    repo(TennisTracker.Repo)
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

    timestamps()
  end

  identities do
    identity(:unique_player_context, [:player_id, :team_type_id, :season_year])
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

    read :for_context do
      argument(:team_type_id, :uuid, allow_nil?: false)
      argument(:season_year, :integer, allow_nil?: false)

      filter(expr(team_type_id == ^arg(:team_type_id) and season_year == ^arg(:season_year)))
    end

    create :create do
      primary?(true)
      accept([:player_id, :team_id, :team_type_id, :season_year])
    end

    update :update do
      primary?(true)
      accept([:team_id])
    end

    destroy :destroy do
      primary?(true)
    end
  end
end
