defmodule TennisTracker.Policies.IsGroupMember do
  @moduledoc """
  FilterCheck that passes (and restricts results) to records belonging to groups
  where the actor has any membership (owner or member).
  """
  use Ash.Policy.FilterCheck

  require Ash.Query

  def describe(_opts), do: "actor is a member of the record's group"

  def filter(actor, _authorizer, _opts) when not is_nil(actor) do
    member_group_ids =
      TennisTracker.Groups.GroupMembership
      |> Ash.Query.filter(user_id == ^actor.id)
      |> Ash.read!(domain: TennisTracker.Groups, authorize?: false)
      |> Enum.map(& &1.group_id)

    case member_group_ids do
      [] -> expr(false)
      ids -> expr(group_id in ^ids)
    end
  end

  def filter(nil, _authorizer, _opts), do: expr(false)
end
