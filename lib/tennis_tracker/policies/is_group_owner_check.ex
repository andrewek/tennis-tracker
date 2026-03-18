defmodule TennisTracker.Policies.IsGroupOwnerCheck do
  @moduledoc """
  SimpleCheck for create actions. Verifies the actor is an owner of the group
  referenced in the changeset's group_id attribute.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  def describe(_opts), do: "actor is an owner of the changeset's group"

  def match?(actor, context, _opts) when not is_nil(actor) do
    group_id =
      case context do
        %{changeset: %Ash.Changeset{} = changeset} ->
          Ash.Changeset.get_attribute(changeset, :group_id)

        _ ->
          nil
      end

    if group_id do
      case TennisTracker.Groups.GroupMembership
           |> Ash.Query.filter(user_id == ^actor.id and role == :owner and group_id == ^group_id)
           |> Ash.read_one(domain: TennisTracker.Groups, authorize?: false) do
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
