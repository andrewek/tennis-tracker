defmodule TennisTracker.Policies.IsTeamCaptainForTeamRoleCheck do
  @moduledoc """
  SimpleCheck for create actions on TeamRole.
  Reads `team_id` and `group_id` from the changeset and verifies the actor
  is already a :captain for that team.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  def describe(_opts), do: "actor is a captain of the team role's team"

  def match?(actor, context, _opts) when not is_nil(actor) do
    {team_id, group_id} =
      case context do
        %{changeset: %Ash.Changeset{} = changeset} ->
          {
            Ash.Changeset.get_attribute(changeset, :team_id),
            Ash.Changeset.get_attribute(changeset, :group_id)
          }

        _ ->
          {nil, nil}
      end

    if team_id && group_id do
      case TennisTracker.Tennis.TeamRole
           |> Ash.Query.filter(team_id == ^team_id and user_id == ^actor.id and role == :captain)
           |> Ash.read_one(domain: TennisTracker.Tennis, tenant: group_id, authorize?: false) do
        {:ok, nil} -> false
        {:ok, _} -> true
        _ -> false
      end
    else
      false
    end
  end

  def match?(_actor, _context, _opts), do: false
end
