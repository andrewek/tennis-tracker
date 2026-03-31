defmodule TennisTracker.Policies.IsTeamCaptainForLineupAssignment do
  @moduledoc """
  FilterCheck for MatchLineupAssignment update/destroy actions.
  Passes when the actor is a captain of the team associated with the assignment's match.
  """
  use Ash.Policy.FilterCheck

  def describe(_opts), do: "actor is a captain of the assignment's match's team"

  def filter(actor, _authorizer, _opts) when not is_nil(actor) do
    actor_id = actor.id

    expr(
      exists(
        TennisTracker.Tennis.TeamRole,
        team_id == parent(match.team_id) and user_id == ^actor_id and role == :captain
      )
    )
  end

  def filter(nil, _authorizer, _opts), do: expr(false)
end
