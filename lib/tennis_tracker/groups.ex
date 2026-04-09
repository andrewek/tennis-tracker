defmodule TennisTracker.Groups do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource TennisTracker.Groups.Group do
      define(:create_group, action: :create)
      define(:list_groups, action: :read)
      define(:get_group_by_slug, action: :read, get_by: [:slug])
    end

    resource TennisTracker.Groups.GroupMembership do
      define(:create_group_membership, action: :create)
      define(:list_group_memberships_for_user, action: :for_user, args: [:user_id])
      define(:list_group_memberships_for_group, action: :for_group, args: [:group_id])

      define(:list_candidate_members_for_team,
        action: :candidate_members_for_team,
        args: [:group_id, :team_id]
      )
    end
  end

  @doc """
  Returns all Groups that the given user belongs to, sorted alphabetically.
  """
  def list_groups_for_user(user_id, opts \\ []) do
    TennisTracker.Groups.GroupMembership
    |> Ash.Query.for_read(:for_user, %{user_id: user_id})
    |> Ash.Query.load(:group)
    |> Ash.read(Keyword.merge([domain: __MODULE__], opts))
    |> case do
      {:ok, memberships} -> {:ok, Enum.map(memberships, & &1.group) |> Enum.sort_by(& &1.name)}
      error -> error
    end
  end
end
