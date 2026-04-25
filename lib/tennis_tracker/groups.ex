defmodule TennisTracker.Groups do
  @moduledoc false

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

      define(:update_group_membership_role, action: :update_role)
    end
  end

  @doc """
  Finds or creates a user by email and creates a GroupMembership.

  Returns `{:ok, %{membership: m, new_user?: bool, temp_password: string | nil}}`
  or `{:error, reason}`.
  """
  def add_member_by_email(email, role, opts \\ []) do
    actor = Keyword.fetch!(opts, :actor)
    tenant = Keyword.fetch!(opts, :tenant)

    case find_user_by_email(email) do
      {:ok, nil} ->
        invite_and_add_member(email, role, actor, tenant)

      {:ok, user} ->
        add_existing_member(user, role, actor, tenant)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_user_by_email(email) do
    TennisTracker.Accounts.User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one(domain: TennisTracker.Accounts, authorize?: false)
  end

  defp invite_and_add_member(email, role, actor, tenant) do
    temp_password = Base.encode64(:crypto.strong_rand_bytes(16))

    case Ash.create(
           TennisTracker.Accounts.User,
           %{email: email, password: temp_password},
           action: :invite,
           domain: TennisTracker.Accounts,
           authorize?: false
         ) do
      {:ok, user} ->
        case create_membership(user, role, actor, tenant) do
          {:ok, membership} ->
            {:ok, %{membership: membership, new_user?: true, temp_password: temp_password}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, %Ash.Error.Invalid{} = error} ->
        if unique_identity_error?(error) do
          case find_user_by_email(email) do
            {:ok, nil} -> {:error, error}
            {:ok, user} -> add_existing_member(user, role, actor, tenant)
            {:error, reason} -> {:error, reason}
          end
        else
          {:error, error}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_existing_member(user, role, actor, tenant) do
    case create_membership(user, role, actor, tenant) do
      {:ok, membership} ->
        {:ok, %{membership: membership, new_user?: false, temp_password: nil}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_membership(user, role, actor, tenant) do
    case create_group_membership(
           %{user_id: user.id, group_id: tenant, role: role},
           actor: actor,
           tenant: tenant
         ) do
      {:ok, membership} ->
        Ash.load(membership, :user, domain: __MODULE__, authorize?: false)

      error ->
        error
    end
  end

  defp unique_identity_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidAttribute{field: :email} -> true
      %Ash.Error.Changes.InvalidChanges{fields: fields} -> :email in (fields || [])
      _ -> false
    end)
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
