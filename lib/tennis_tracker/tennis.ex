defmodule TennisTracker.Tennis do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  require Ash.Query

  alias TennisTracker.Tennis.{Team, TeamMembership, SeasonRules, Player}

  admin do
    show? true
  end

  @doc """
  Returns all planning contexts that have been previously accessed,
  identified by the existence of a pseudo-team. Ordered by season_year desc.
  """
  def list_planning_contexts do
    Team
    |> Ash.Query.filter(is_pseudo == true)
    |> Ash.Query.load(:team_type)
    |> Ash.Query.sort(season_year: :desc)
    |> Ash.read!(domain: __MODULE__)
  end

  @doc """
  Returns the SeasonRules for a given team_type_id and season_year,
  or nil if none exist.
  """
  def get_season_rules_for_context(team_type_id, season_year) do
    SeasonRules
    |> Ash.Query.filter(team_type_id == ^team_type_id and season_year == ^season_year)
    |> Ash.read_one(domain: __MODULE__)
  end

  @doc """
  Lists all teams (real and pseudo) for a planning context.
  """
  def list_teams_for_context(team_type_id, season_year) do
    Team
    |> Ash.Query.filter(team_type_id == ^team_type_id and season_year == ^season_year)
    |> Ash.Query.sort(:name)
    |> Ash.read(domain: __MODULE__)
  end

  @doc """
  Finds or creates the "Not Participating" pseudo-team for a context.
  Returns {:ok, team} or {:error, reason}.
  """
  def ensure_pseudo_team(team_type_id, season_year) do
    existing =
      Team
      |> Ash.Query.filter(
        team_type_id == ^team_type_id and season_year == ^season_year and is_pseudo == true
      )
      |> Ash.read_one(domain: __MODULE__)

    case existing do
      {:ok, nil} ->
        create_team(%{
          name: "Not Participating",
          team_type_id: team_type_id,
          season_year: season_year,
          is_pseudo: true
        })

      {:ok, team} ->
        {:ok, team}

      error ->
        error
    end
  end

  @doc """
  Lists all memberships for a planning context, preloading player and team.
  """
  def list_memberships_for_context(team_type_id, season_year) do
    TeamMembership
    |> Ash.Query.filter(team_type_id == ^team_type_id and season_year == ^season_year)
    |> Ash.Query.load([:player])
    |> Ash.read(domain: __MODULE__)
  end

  @doc """
  Assigns a player to a team within a planning context.
  If a membership already exists for this player in this context, it is updated.
  If the target team_id is nil, the membership is removed (unassign).
  """
  def assign_player(player_id, team_id, team_type_id, season_year) do
    TeamMembership
    |> Ash.Changeset.for_create(
      :create,
      %{
        player_id: player_id,
        team_id: team_id,
        team_type_id: team_type_id,
        season_year: season_year
      },
      domain: __MODULE__
    )
    |> Ash.create(
      upsert?: true,
      upsert_identity: :unique_player_context,
      upsert_fields: [:team_id]
    )
  end

  @doc """
  Deletes a team and all its memberships. Players assigned to the team return to Unassigned.
  """
  def delete_team(team) do
    TeamMembership
    |> Ash.Query.filter(team_id == ^team.id)
    |> Ash.read!(domain: __MODULE__)
    |> Enum.each(&destroy_team_membership/1)

    destroy_team(team)
  end

  @doc """
  Returns all eligible, unassigned players for a planning context, sorted by NTRP
  descending (nils last) then name ascending.

  Eligibility is determined by:
  - Age group flag (eligible_18_plus or eligible_40_plus) matching the team type
  - NTRP rating within the team type's allowed_ntrp_levels, OR nil (unrated)

  Players already assigned to any team in this context are excluded.
  """
  def list_eligible_unassigned_players(team_type, team_type_id, season_year) do
    allowed_levels = team_type.allowed_ntrp_levels

    age_query =
      case team_type.age_group do
        "18_plus" -> Ash.Query.filter(Player, eligible_18_plus == true)
        "40_plus" -> Ash.Query.filter(Player, eligible_40_plus == true)
        _ -> Ash.Query.filter(Player, eligible_18_plus == true)
      end

    age_query
    |> Ash.Query.filter(
      (is_nil(ntrp_rating) or ntrp_rating in ^allowed_levels) and
        not exists(
          team_memberships,
          team_type_id == ^team_type_id and season_year == ^season_year
        )
    )
    |> Ash.Query.sort(ntrp_rating: :desc_nils_last, name: :asc)
    |> Ash.read!(domain: __MODULE__)
  end

  @doc """
  Removes a player's membership from a planning context (moves them back to Unassigned).
  """
  def unassign_player(player_id, team_type_id, season_year) do
    membership =
      TeamMembership
      |> Ash.Query.filter(
        player_id == ^player_id and team_type_id == ^team_type_id and season_year == ^season_year
      )
      |> Ash.read_one!(domain: __MODULE__)

    if membership do
      destroy_team_membership(membership)
    else
      {:ok, nil}
    end
  end

  resources do
    resource TennisTracker.Tennis.Player do
      define(:list_players, action: :read)
      define(:get_player, action: :read, get_by: [:id])
      define(:create_player, action: :create)
      define(:update_player, action: :update)
      define(:destroy_player, action: :destroy)
    end

    resource TennisTracker.Tennis.TeamType do
      define(:list_team_types, action: :read)
      define(:get_team_type, action: :read, get_by: [:id])
      define(:create_team_type, action: :create)
    end

    resource TennisTracker.Tennis.SeasonRules do
      define(:create_season_rules, action: :create)
    end

    resource TennisTracker.Tennis.Team do
      define(:create_team, action: :create)
      define(:update_team, action: :update)
      define(:destroy_team, action: :destroy)
    end

    resource TennisTracker.Tennis.TeamMembership do
      define(:list_real_memberships_for_player, action: :for_player, args: [:player_id])
      define(:create_team_membership, action: :create)
      define(:update_team_membership, action: :update)
      define(:destroy_team_membership, action: :destroy)
    end
  end
end
