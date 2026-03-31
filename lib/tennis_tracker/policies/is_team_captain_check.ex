defmodule TennisTracker.Policies.IsTeamCaptainCheck do
  @moduledoc """
  SimpleCheck for create actions on resources with a `team_id` attribute.
  Verifies the actor is a captain of the team referenced in the changeset.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  def describe(_opts), do: "actor is a captain of the changeset's team"

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
