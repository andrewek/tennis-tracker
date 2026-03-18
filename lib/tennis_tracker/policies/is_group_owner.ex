defmodule TennisTracker.Policies.IsGroupOwner do
  @moduledoc """
  FilterCheck that passes (and restricts results) to records belonging to groups
  where the actor is an owner.
  """
  use Ash.Policy.FilterCheck

  require Ash.Query

  def describe(_opts), do: "actor is an owner of the record's group"

  def filter(actor, _authorizer, _opts) when not is_nil(actor) do
    owned_group_ids =
      TennisTracker.Groups.GroupMembership
      |> Ash.Query.filter(user_id == ^actor.id and role == :owner)
      |> Ash.read!(domain: TennisTracker.Groups, authorize?: false)
      |> Enum.map(& &1.group_id)

    case owned_group_ids do
      [] -> expr(false)
      ids -> expr(group_id in ^ids)
    end
  end

  def filter(nil, _authorizer, _opts), do: expr(false)
end
