defmodule TennisTracker.Policies.IsTeamCaptainForMatch do
  @moduledoc """
  FilterCheck for Match resources that passes when the actor is a captain of the
  match's team.

  Task 4.2 spike result: `exists(team.team_roles, ...)` two-level traversal is not
  natively supported in Ash exists expressions. Workaround: use unrelated exists
  with parent(team_id) to directly query TeamRole without multi-hop traversal.
  """
  use Ash.Policy.FilterCheck

  def describe(_opts), do: "actor is a captain of the match's team"

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
