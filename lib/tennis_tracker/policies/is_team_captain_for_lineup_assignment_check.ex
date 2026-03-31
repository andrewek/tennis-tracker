defmodule TennisTracker.Policies.IsTeamCaptainForLineupAssignmentCheck do
  @moduledoc """
  SimpleCheck for create actions on MatchLineupAssignment.
  Looks up the match from the changeset's match_id, then checks if the actor
  is a captain of that match's team.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  def describe(_opts), do: "actor is a captain of the lineup assignment's match's team"

  def match?(actor, context, _opts) when not is_nil(actor) do
    {match_id, group_id} =
      case context do
        %{changeset: %Ash.Changeset{} = changeset} ->
          {
            Ash.Changeset.get_attribute(changeset, :match_id),
            Ash.Changeset.get_attribute(changeset, :group_id)
          }

        _ ->
          {nil, nil}
      end

    if match_id && group_id do
      case Ash.get(TennisTracker.Tennis.Match, match_id,
             domain: TennisTracker.Tennis,
             tenant: group_id,
             authorize?: false
           ) do
        {:ok, match} ->
          case TennisTracker.Tennis.TeamRole
               |> Ash.Query.filter(
                 team_id == ^match.team_id and user_id == ^actor.id and role == :captain
               )
               |> Ash.read_one(domain: TennisTracker.Tennis, tenant: group_id, authorize?: false) do
            {:ok, nil} -> false
            {:ok, _} -> true
            _ -> false
          end

        _ ->
          false
      end
    else
      false
    end
  end

  def match?(_actor, _context, _opts), do: false
end
