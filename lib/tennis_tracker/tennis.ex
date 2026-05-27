defmodule TennisTracker.Tennis do
  @moduledoc false

  use Ash.Domain, extensions: [AshAdmin.Domain]

  require Ash.Query

  alias TennisTracker.Tennis.{
    Match,
    MatchLineupAssignment,
    Player,
    PlayerTag,
    SeasonRules,
    SeasonRulesDefaultTag,
    Team,
    TeamMembership
  }

  admin do
    show? true
  end

  @doc """
  Returns all planning contexts that have been previously accessed,
  identified by the existence of a pseudo-team. Ordered by season_year desc.
  """
  def list_planning_contexts(opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    Team
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.filter(is_pseudo == true)
    |> Ash.Query.load(:team_type)
    |> Ash.Query.sort(season_year: :desc)
    |> Ash.read!(domain: __MODULE__, tenant: tenant)
  end

  @doc """
  Returns the SeasonRules for a given team_type_id and season_year,
  or nil if none exist.
  """
  def get_season_rules_for_context(team_type_id, season_year, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    SeasonRules
    |> Ash.Query.for_read(:for_context, %{team_type_id: team_type_id, season_year: season_year},
      actor: actor
    )
    |> Ash.read_one(domain: __MODULE__, tenant: tenant)
  end

  @doc """
  Lists all teams (real and pseudo) for a planning context.
  """
  def list_teams_for_context(team_type_id, season_year, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    Team
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.filter(team_type_id == ^team_type_id and season_year == ^season_year)
    |> Ash.Query.load(:team_type)
    |> Ash.Query.sort(:name)
    |> Ash.read(domain: __MODULE__, tenant: tenant)
  end

  @doc """
  Finds or creates the "Not Participating" pseudo-team for a context.
  Returns {:ok, team} or {:error, reason}.
  """
  def ensure_pseudo_team(team_type_id, season_year, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    existing =
      Team
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(
        team_type_id == ^team_type_id and season_year == ^season_year and is_pseudo == true
      )
      |> Ash.read_one(domain: __MODULE__, tenant: tenant)

    case existing do
      {:ok, nil} ->
        create_team(
          %{
            name: "Not Participating",
            team_type_id: team_type_id,
            season_year: season_year,
            is_pseudo: true,
            group_id: tenant
          },
          tenant: tenant,
          actor: actor
        )

      {:ok, team} ->
        {:ok, team}

      error ->
        error
    end
  end

  @doc """
  Lists all memberships for a planning context, preloading player and team.
  """
  def list_memberships_for_context(team_type_id, season_year, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    TeamMembership
    |> Ash.Query.for_read(:for_context, %{team_type_id: team_type_id, season_year: season_year},
      actor: actor
    )
    |> Ash.Query.load([:player])
    |> Ash.read(domain: __MODULE__, tenant: tenant)
  end

  @doc """
  Assigns a player to a team within a planning context.
  If a membership already exists for this player in this context, it is updated.
  If the target team_id is nil, the membership is removed (unassign).
  """
  def assign_player(player_id, team_id, team_type_id, season_year, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    TeamMembership
    |> Ash.Changeset.for_create(
      :create,
      %{
        player_id: player_id,
        team_id: team_id,
        team_type_id: team_type_id,
        season_year: season_year,
        group_id: tenant
      },
      domain: __MODULE__,
      actor: actor,
      tenant: tenant
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
  def delete_team(team, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    TeamMembership
    |> Ash.Query.for_read(:read, %{}, actor: actor)
    |> Ash.Query.filter(team_id == ^team.id)
    |> Ash.read!(domain: __MODULE__, tenant: tenant)
    |> Enum.each(&destroy_team_membership(&1, tenant: tenant, actor: actor))

    destroy_team(team, tenant: tenant, actor: actor)
  end

  @doc """
  Returns all unassigned players for a planning context (those with no membership
  in this context), optionally filtered by a tag_filter map.

  tag_filter shape: %{include: %{category_id => [tag_id]}, show_untagged: [category_id]}
  """
  def list_unassigned_players(team_type_id, season_year, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)
    tag_filter = Keyword.get(opts, :tag_filter, %{include: %{}, show_untagged: []})
    allowed_ntrp_levels = Keyword.get(opts, :allowed_ntrp_levels, [])

    query =
      Player
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(
        not exists(
          team_memberships,
          team_type_id == ^team_type_id and season_year == ^season_year
        )
      )
      |> TennisTracker.Tennis.PlayerFilters.apply_tag_filter(tag_filter)
      |> Ash.Query.sort(ntrp_rating: :desc_nils_last, name: :asc)

    query =
      if allowed_ntrp_levels != [] do
        Ash.Query.filter(query, is_nil(ntrp_rating) or ntrp_rating in ^allowed_ntrp_levels)
      else
        query
      end

    Ash.read!(query, domain: __MODULE__, tenant: tenant)
  end

  @doc """
  Removes a player's membership from a planning context (moves them back to Unassigned).
  """
  def unassign_player(player_id, team_type_id, season_year, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    membership =
      TeamMembership
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(
        player_id == ^player_id and team_type_id == ^team_type_id and season_year == ^season_year
      )
      |> Ash.read_one!(domain: __MODULE__, tenant: tenant)

    if membership do
      destroy_team_membership(membership, tenant: tenant, actor: actor)
    else
      {:ok, nil}
    end
  end

  @doc """
  Loads a real (non-pseudo) team by ID with its team type and roster of players.
  """
  def get_team_with_roster(id, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    case Ash.get(Team, id, domain: __MODULE__, tenant: tenant, actor: actor) do
      {:ok, team} when team.is_pseudo ->
        {:error, :not_found}

      {:ok, team} ->
        Ash.load(team, [:team_type, memberships: [:player]],
          domain: __MODULE__,
          tenant: tenant,
          actor: actor
        )

      {:error, _} ->
        {:error, :not_found}
    end
  end

  @doc """
  Adds a tag to a player. Creates a PlayerTag record.
  """
  def add_player_tag(player_id, tag_id, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    PlayerTag
    |> Ash.Changeset.for_create(
      :create,
      %{player_id: player_id, tag_id: tag_id, group_id: tenant},
      domain: __MODULE__,
      actor: actor,
      tenant: tenant
    )
    |> Ash.create(upsert?: true, upsert_identity: :unique_player_tag)
  end

  @doc """
  Removes a tag from a player. Destroys the matching PlayerTag record.
  """
  def remove_player_tag(player_id, tag_id, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    case PlayerTag
         |> Ash.Query.for_read(:read, %{}, actor: actor)
         |> Ash.Query.filter(player_id == ^player_id and tag_id == ^tag_id)
         |> Ash.read_one(domain: __MODULE__, tenant: tenant) do
      {:ok, nil} -> {:ok, nil}
      {:ok, record} -> Ash.destroy(record, domain: __MODULE__, actor: actor, tenant: tenant)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Syncs the default_tags for a SeasonRules record.
  Replaces the full set of SeasonRulesDefaultTag records with the provided tag_id list,
  creating new records for added tags and destroying records for removed tags.
  """
  def sync_season_rules_default_tags(season_rules_id, tag_ids, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    existing =
      SeasonRulesDefaultTag
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(season_rules_id == ^season_rules_id)
      |> Ash.read!(domain: __MODULE__, tenant: tenant)

    existing_tag_ids = Enum.map(existing, & &1.tag_id)
    desired_tag_ids = tag_ids

    to_add = desired_tag_ids -- existing_tag_ids
    to_remove = existing_tag_ids -- desired_tag_ids

    with :ok <- sync_add_default_tags(to_add, season_rules_id, tenant, actor) do
      sync_remove_default_tags(to_remove, existing, tenant, actor)
    end
  end

  @doc """
  Assigns a player to a lineup slot for a match.

  For :one_per_match teams: updates the player's existing assignment in place if found,
  otherwise creates a new one. This ensures only one assignment per player per match.

  For :one_per_column and :many_per_match teams: always creates a new assignment.
  The mode-aware validation in MatchLineupAssignment.create enforces the constraint.

  ## Mode-constraint enforcement layers

  Assignment mode constraints are enforced at three levels:

    1. **MatchLineupAssignment.create** (`apply_mode_constraint/5`) — authoritative DB-level
       enforcement. Runs inside a before_action and always rejects invalid assignments
       regardless of how they were submitted.

    2. **Tennis.assign_to_slot/4** (this function) — domain-level pre-check for
       :one_per_match. Issues an update instead of a create when the player already has an
       assignment, keeping the identity constraint clean.

    3. **LineupEditLive.do_slot_assignment/6** — UI-level pre-check. For :one_per_column,
       destroys the existing same-column assignment before creating the new one so the
       board reflects a clean move rather than an error. For :many_per_match, skips
       creation when the player is already in the target slot.

  Layers 2 and 3 are optimistic helpers; layer 1 is the enforcer.
  """
  def assign_to_slot(match_id, player_id, slot_id, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    match =
      Ash.get!(Match, match_id, domain: __MODULE__, tenant: tenant, actor: actor)

    team =
      Ash.get!(Team, match.team_id, domain: __MODULE__, tenant: tenant, actor: actor)

    case team.lineup_assignment_mode do
      :one_per_match ->
        existing =
          MatchLineupAssignment
          |> Ash.Query.filter(match_id == ^match_id and player_id == ^player_id)
          |> Ash.Query.load(:team_lineup_slot)
          |> Ash.read_one!(domain: __MODULE__, tenant: tenant, authorize?: false)

        if existing do
          target_slot =
            Ash.get!(TennisTracker.Tennis.TeamLineupSlot, slot_id,
              domain: __MODULE__,
              tenant: tenant,
              authorize?: false
            )

          if existing.team_lineup_slot.participation_type == :out &&
               target_slot.participation_type != :out do
            {:error, :player_excluded}
          else
            existing
            |> Ash.Changeset.for_update(:update, %{team_lineup_slot_id: slot_id},
              domain: __MODULE__,
              actor: actor,
              tenant: tenant
            )
            |> Ash.update()
          end
        else
          MatchLineupAssignment
          |> Ash.Changeset.for_create(
            :create,
            %{
              match_id: match_id,
              player_id: player_id,
              team_lineup_slot_id: slot_id,
              group_id: tenant
            },
            domain: __MODULE__,
            actor: actor,
            tenant: tenant
          )
          |> Ash.create()
        end

      _mode ->
        MatchLineupAssignment
        |> Ash.Changeset.for_create(
          :create,
          %{
            match_id: match_id,
            player_id: player_id,
            team_lineup_slot_id: slot_id,
            group_id: tenant
          },
          domain: __MODULE__,
          actor: actor,
          tenant: tenant
        )
        |> Ash.create()
    end
  end

  @doc """
  Removes a player's lineup assignment for a match.
  """
  def unassign_from_lineup(match_id, player_id, opts \\ []) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    assignments =
      MatchLineupAssignment
      |> Ash.Query.for_read(:read, %{}, actor: actor)
      |> Ash.Query.filter(match_id == ^match_id and player_id == ^player_id)
      |> Ash.read!(domain: __MODULE__, tenant: tenant)

    Enum.reduce_while(assignments, :ok, fn assignment, :ok ->
      case Ash.destroy(assignment, domain: __MODULE__, actor: actor, tenant: tenant) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def season_stats_for_team!(team_id, all_matches, opts) do
    tenant = Keyword.fetch!(opts, :tenant)
    actor = Keyword.fetch!(opts, :actor)

    now = DateTime.utc_now()
    total_matches = length(all_matches)
    matches_by_id = Map.new(all_matches, &{&1.id, &1})

    assignments =
      MatchLineupAssignment
      |> Ash.Query.filter(match.team_id == ^team_id)
      |> Ash.Query.load([:team_lineup_slot])
      |> Ash.read!(domain: __MODULE__, tenant: tenant, actor: actor)

    by_player =
      Enum.group_by(assignments, & &1.player_id)
      |> Map.new(fn {player_id, player_assignments} ->
        stats =
          Enum.reduce(
            player_assignments,
            %{played_past: 0, played_future: 0, out: 0, neutral: %{}},
            fn a, acc ->
              case Map.fetch(matches_by_id, a.match_id) do
                :error ->
                  acc

                {:ok, match} ->
                  past? = DateTime.before?(match.match_start_datetime, now)

                  case a.team_lineup_slot.participation_type do
                    :playing ->
                      if past? do
                        %{acc | played_past: acc.played_past + 1}
                      else
                        %{acc | played_future: acc.played_future + 1}
                      end

                    :out ->
                      %{acc | out: acc.out + 1}

                    :neutral ->
                      %{
                        acc
                        | neutral: Map.update(acc.neutral, a.team_lineup_slot.name, 1, &(&1 + 1))
                      }
                  end
              end
            end
          )

        {player_id, stats}
      end)

    %{total_matches: total_matches, by_player: by_player}
  end

  defp sync_add_default_tags(tag_ids, season_rules_id, tenant, actor) do
    Enum.reduce_while(tag_ids, :ok, fn tag_id, :ok ->
      result =
        SeasonRulesDefaultTag
        |> Ash.Changeset.for_create(
          :create,
          %{season_rules_id: season_rules_id, tag_id: tag_id, group_id: tenant},
          domain: __MODULE__,
          actor: actor,
          tenant: tenant
        )
        |> Ash.create(upsert?: true, upsert_identity: :unique_season_rules_tag)

      case result do
        {:ok, _} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp sync_remove_default_tags(tag_ids, existing, tenant, actor) do
    Enum.reduce_while(tag_ids, :ok, fn tag_id, :ok ->
      case Enum.find(existing, &(&1.tag_id == tag_id)) do
        nil ->
          {:cont, :ok}

        record ->
          case Ash.destroy(record, domain: __MODULE__, actor: actor, tenant: tenant) do
            :ok -> {:cont, :ok}
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end
    end)
  end

  resources do
    resource TennisTracker.Tennis.TagCategory do
      define(:list_tag_categories, action: :list)
      define(:create_tag_category, action: :create)
      define(:get_tag_category, action: :read, get_by: [:id])
      define(:update_tag_category, action: :update)
      define(:destroy_tag_category, action: :destroy)
    end

    resource TennisTracker.Tennis.Tag do
      define(:list_tags, action: :list)
      define(:list_tags_for_category, action: :list)
      define(:get_tag, action: :read, get_by: [:id])
      define(:create_tag, action: :create)
      define(:update_tag, action: :update)
      define(:destroy_tag, action: :destroy)
    end

    resource TennisTracker.Tennis.PlayerTag do
      define(:list_player_tags, action: :read)
      define(:create_player_tag, action: :create)
      define(:destroy_player_tag, action: :destroy)
    end

    resource TennisTracker.Tennis.SeasonRulesDefaultTag do
      define(:list_season_rules_default_tags, action: :read)
      define(:create_season_rules_default_tag, action: :create)
      define(:destroy_season_rules_default_tag, action: :destroy)
    end

    resource TennisTracker.Tennis.Location do
      define(:list_locations, action: :list_locations)
      define(:list_archived_locations, action: :archived)
      define(:get_location, action: :read, get_by: [:id])
      define(:get_archived_location, action: :archived, get_by: [:id])
      define(:create_location, action: :create)
      define(:update_location, action: :update)
      define(:archive_location, action: :archive)
      define(:unarchive_location, action: :unarchive)
    end

    resource TennisTracker.Tennis.Match do
      define(:create_match, action: :create)
      define(:update_match, action: :update)
      define(:destroy_match, action: :destroy)

      define(:list_upcoming_matches_for_team,
        action: :list_upcoming_matches_for_team,
        args: [:team_id]
      )

      define(:list_past_matches_for_team, action: :list_past_matches_for_team, args: [:team_id])

      define(:list_all_matches_for_team,
        action: :list_all_matches_for_team,
        args: [:team_id]
      )

      define(:get_next_upcoming_match_for_team,
        action: :next_upcoming_match_for_team,
        args: [:team_id]
      )
    end

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
      define(:list_season_rules, action: :read)
      define(:get_season_rules, action: :read, get_by: [:id])
      define(:create_season_rules, action: :create)
      define(:update_season_rules, action: :update)
      define(:destroy_season_rules, action: :destroy)
    end

    resource TennisTracker.Tennis.Team do
      define(:list_real_teams, action: :list_real)
      define(:get_team, action: :read, get_by: [:id])
      define(:create_team, action: :create)
      define(:update_team, action: :update)
      define(:update_team_assignment_mode, action: :update_assignment_mode)
      define(:destroy_team, action: :destroy)
    end

    resource TennisTracker.Tennis.TeamMembership do
      define(:list_real_memberships_for_player, action: :for_player, args: [:player_id])
      define(:list_memberships_for_team, action: :for_team, args: [:team_id])
      define(:create_team_membership, action: :create)
      define(:update_team_membership, action: :update)
      define(:destroy_team_membership, action: :destroy)
      define(:add_to_roster, action: :add_to_roster)
      define(:remove_from_roster, action: :remove_from_roster)
    end

    resource TennisTracker.Tennis.TeamLineupColumn do
      define(:list_lineup_columns_for_team, action: :for_team, args: [:team_id])
      define(:create_lineup_column, action: :create)
      define(:update_lineup_column, action: :update)
      define(:delete_lineup_column, action: :destroy)
    end

    resource TennisTracker.Tennis.TeamLineupSlot do
      define(:list_lineup_slots_for_team, action: :for_team, args: [:team_id])
      define(:create_lineup_slot, action: :create)
      define(:update_lineup_slot, action: :update)
      define(:delete_lineup_slot, action: :destroy)
    end

    resource TennisTracker.Tennis.MatchLineupAssignment do
      define(:list_assignments_for_match, action: :for_match, args: [:match_id])
      define(:create_lineup_assignment, action: :create)
      define(:update_lineup_assignment, action: :update)
      define(:destroy_lineup_assignment, action: :destroy)
    end

    resource TennisTracker.Tennis.TeamRole do
      define(:create_team_role, action: :create)
      define(:update_team_role_role, action: :update)
      define(:destroy_team_role, action: :destroy)
      define(:list_team_roles_for_team, action: :for_team, args: [:team_id])
      define(:list_captains_for_team, action: :captains_for_team, args: [:team_id])
      define(:list_team_roles_for_user, action: :for_user, args: [:user_id])
    end
  end
end
