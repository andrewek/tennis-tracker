defmodule TennisTrackerWeb.Teams.Settings.Helpers do
  @moduledoc """
  Shared helper for loading a team and deriving permissions in team settings LiveViews.
  Called in `handle_params/3` once the team ID from params is available.
  """

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Team, TeamLineupSlot, TeamRole}

  @doc """
  Loads the team by ID and checks the current user's permissions.

  Returns `{:ok, assigns_map}` on success, where assigns_map contains:
  - `:team` — the loaded Team struct (with `:team_type` preloaded)
  - `:can_update_team` — boolean
  - `:can_manage_slots` — boolean
  - `:can_manage_captains` — boolean

  Returns `{:error, :not_found}` if the team doesn't exist or is a pseudo-team.
  Returns `{:error, :unauthorized}` if the user has no permission to manage any aspect.
  """
  def load_team_settings(id, group_id, current_user) do
    case Ash.get(Team, id, domain: Tennis, tenant: group_id, actor: current_user) do
      {:ok, team} when team.is_pseudo ->
        {:error, :not_found}

      {:ok, team} ->
        can_update_team =
          Ash.can?({team, :update}, current_user, tenant: group_id, domain: Tennis)

        can_manage_slots =
          Ash.can?(
            {TeamLineupSlot, :create,
             %{team_id: team.id, group_id: group_id, name: "placeholder"}},
            current_user,
            domain: Tennis,
            tenant: group_id
          )

        can_manage_captains =
          Ash.can?(
            {TeamRole, :create, %{team_id: team.id, group_id: group_id}},
            current_user,
            domain: Tennis,
            tenant: group_id
          )

        if can_update_team or can_manage_slots or can_manage_captains do
          {:ok, team} =
            Ash.load(team, [:team_type], domain: Tennis, tenant: group_id, actor: current_user)

          {:ok,
           %{
             team: team,
             can_update_team: can_update_team,
             can_manage_slots: can_manage_slots,
             can_manage_captains: can_manage_captains
           }}
        else
          {:error, :unauthorized}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  end

  def load_lineup_columns(team_id, group_id, current_user) do
    Tennis.list_lineup_columns_for_team!(team_id, tenant: group_id, actor: current_user)
  end

  def load_lineup_slots(team_id, group_id, current_user) do
    Tennis.list_lineup_slots_for_team!(team_id, tenant: group_id, actor: current_user)
  end
end
