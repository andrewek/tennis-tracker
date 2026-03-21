defmodule TennisTracker.Tennis.Match do
  use Ash.Resource,
    domain: TennisTracker.Tennis,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAdmin.Resource]

  postgres do
    table("matches")
    repo(TennisTracker.Repo)

    custom_indexes do
      index([:team_id, :match_start_datetime])
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
      authorize_if(TennisTracker.Policies.IsTeamCaptainForMatch)
    end

    policy action_type([:update, :destroy]) do
      authorize_if(TennisTracker.Policies.IsGroupOwner)
      authorize_if(TennisTracker.Policies.IsTeamCaptainForMatch)
    end
  end

  admin do
  end

  attributes do
    uuid_v7_primary_key(:id)

    attribute :timezone, :string do
      allow_nil?(false)
      public?(true)
      default("America/Chicago")
    end

    attribute :match_start_datetime, :utc_datetime do
      allow_nil?(false)
      public?(true)
    end

    attribute :duration_minutes, :integer do
      allow_nil?(false)
      public?(true)
      default(90)
    end

    attribute :opponent, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :home_or_away, TennisTracker.Tennis.HomeOrAway do
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
    belongs_to :team, TennisTracker.Tennis.Team do
      allow_nil?(false)
      public?(true)
    end

    belongs_to :location, TennisTracker.Tennis.Location do
      allow_nil?(true)
      public?(true)
      read_action(:load_for_relationship)
    end
  end

  actions do
    read :read do
      primary?(true)
    end

    read :list_upcoming_matches_for_team do
      argument(:team_id, :uuid, allow_nil?: false)

      filter(
        expr(
          team_id == ^arg(:team_id) and
            match_start_datetime >= fragment("NOW()")
        )
      )

      prepare(fn query, _ ->
        Ash.Query.sort(query, match_start_datetime: :asc)
      end)
    end

    read :next_upcoming_match_for_team do
      argument(:team_id, :uuid, allow_nil?: false)

      filter(
        expr(
          team_id == ^arg(:team_id) and
            match_start_datetime >= fragment("NOW()")
        )
      )

      prepare(fn query, _ ->
        query
        |> Ash.Query.sort(match_start_datetime: :asc)
        |> Ash.Query.limit(1)
      end)
    end

    read :list_past_matches_for_team do
      argument(:team_id, :uuid, allow_nil?: false)

      filter(
        expr(
          team_id == ^arg(:team_id) and
            match_start_datetime < fragment("NOW()")
        )
      )

      prepare(fn query, _ ->
        Ash.Query.sort(query, match_start_datetime: :desc)
      end)
    end

    create :create do
      primary?(true)

      accept([
        :match_start_datetime,
        :timezone,
        :duration_minutes,
        :opponent,
        :home_or_away,
        :team_id,
        :location_id,
        :group_id
      ])
    end

    update :update do
      primary?(true)

      accept([
        :match_start_datetime,
        :timezone,
        :duration_minutes,
        :opponent,
        :home_or_away,
        :location_id
      ])
    end

    destroy :destroy do
      primary?(true)
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:group_id)
    global?(true)
  end
end
