defmodule TennisTrackerWeb.Plugs.RequireGroupMember do
  @moduledoc """
  Plug that enforces authentication and group membership for plain HTTP routes
  scoped under `/g/:group_slug`.

  On success, assigns `:current_group` and `:current_group_id` to the conn so
  downstream controllers can use them directly.

  Halts and redirects on:
  - Unauthenticated request (no current_user in assigns)
  - Unknown group slug
  - Authenticated user who is not a member of the group
  """

  import Plug.Conn
  import Phoenix.Controller

  use TennisTrackerWeb, :verified_routes

  alias TennisTracker.Groups

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = conn.assigns[:current_user]

    if is_nil(current_user) do
      conn
      |> put_flash(:error, "You must be logged in.")
      |> redirect(to: ~p"/sign-in")
      |> halt()
    else
      resolve_and_verify(conn, current_user)
    end
  end

  defp resolve_and_verify(conn, current_user) do
    group_slug = conn.params["group_slug"]

    with {:ok, group} <- resolve_group(group_slug, current_user),
         :ok <- verify_membership(group.id, current_user) do
      conn
      |> assign(:current_group, group)
      |> assign(:current_group_id, group.id)
    else
      {:error, :group_not_found} ->
        conn
        |> put_flash(:error, "Group not found.")
        |> redirect(to: ~p"/groups")
        |> halt()

      _ ->
        conn
        |> put_flash(:error, "Access denied.")
        |> redirect(to: ~p"/groups")
        |> halt()
    end
  end

  defp resolve_group(slug, user) do
    group = Groups.get_group_by_slug!(slug, actor: user, authorize?: true)
    {:ok, group}
  rescue
    _ -> {:error, :group_not_found}
  end

  defp verify_membership(_group_id, %{role: :admin}), do: :ok

  defp verify_membership(group_id, user) do
    case Groups.list_group_memberships_for_user(user.id, actor: user, authorize?: false) do
      {:ok, memberships} ->
        if Enum.any?(memberships, &(&1.group_id == group_id)), do: :ok, else: {:error, :forbidden}

      _ ->
        {:error, :forbidden}
    end
  end
end
