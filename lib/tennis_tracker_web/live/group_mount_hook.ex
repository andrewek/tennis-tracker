defmodule TennisTrackerWeb.GroupMountHook do
  @moduledoc """
  on_mount hook that resolves the group from the URL slug, verifies group
  membership, and assigns current_group, current_group_id, and current_group_role
  to the socket. Redirects to /groups on failure.
  """

  import Phoenix.Component
  use TennisTrackerWeb, :verified_routes

  alias TennisTracker.Groups
  alias TennisTracker.Groups.GroupMembership

  require Ash.Query

  def on_mount(:require_group_member, params, _session, socket) do
    current_user = socket.assigns.current_user
    group_slug = params["group_slug"]

    case resolve_group(group_slug, current_user) do
      {:ok, group} ->
        group_role = resolve_group_role(group.id, current_user)

        {:cont,
         socket
         |> assign(:current_group, group)
         |> assign(:current_group_id, group.id)
         |> assign(:current_group_role, group_role)}

      {:error, _} ->
        {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/groups")}
    end
  end

  defp resolve_group(nil, _user), do: {:error, :no_slug}

  defp resolve_group(slug, user) do
    group = Groups.get_group_by_slug!(slug, actor: user, authorize?: true)
    {:ok, group}
  rescue
    _ -> {:error, :not_found_or_unauthorized}
  end

  defp resolve_group_role(_group_id, %{role: :admin}), do: :admin

  defp resolve_group_role(group_id, user) do
    membership =
      GroupMembership
      |> Ash.Query.filter(user_id == ^user.id and group_id == ^group_id)
      |> Ash.read_one(domain: Groups, actor: user, authorize?: false)

    case membership do
      {:ok, %GroupMembership{role: role}} -> role
      _ -> :member
    end
  end
end
