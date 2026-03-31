defmodule TennisTracker.Policies.IsTeamCaptain do
  @moduledoc """
  FilterCheck for resources with a direct `team_id` attribute.
  Passes when the actor is a captain of that team.
  Used for update/destroy actions on TeamLineupSlot and similar resources.
  """
  use Ash.Policy.FilterCheck

  def describe(_opts), do: "actor is a captain of the record's team"

  def filter(actor, _authorizer, _opts) when not is_nil(actor) do
    actor_id = actor.id

    expr(
      exists(
        TennisTracker.Tennis.TeamRole,
        team_id == parent(team_id) and user_id == ^actor_id and role == :captain
      )
    )
  end

  def filter(nil, _authorizer, _opts), do: expr(false)
end
