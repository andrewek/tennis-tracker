defmodule TennisTrackerWeb.AccountSettingsMountHook do
  @moduledoc """
  on_mount hook for account settings pages. Loads the last-visited group from
  the session (stored by StoreLastGroup plug) so the sidebar retains group
  context when the user navigates into account settings.
  """

  import Phoenix.Component

  use TennisTrackerWeb, :verified_routes

  alias TennisTracker.Groups
  alias TennisTracker.Groups.GroupMembership

  require Ash.Query

  def on_mount(:load_last_group, _params, session, socket) do
    user = socket.assigns.current_user

    case Map.get(session, "last_group_slug") do
      nil ->
        {:cont, socket |> assign(:current_group, nil) |> assign(:current_group_role, nil)}

      slug ->
        case load_group(slug, user) do
          {:ok, group} ->
            role = resolve_group_role(group.id, user)

            {:cont,
             socket
             |> assign(:current_group, group)
             |> assign(:current_group_role, role)}

          _ ->
            {:cont, socket |> assign(:current_group, nil) |> assign(:current_group_role, nil)}
        end
    end
  end

  defp load_group(slug, user) do
    try do
      group = Groups.get_group_by_slug!(slug, actor: user, authorize?: true)
      {:ok, group}
    rescue
      _ -> {:error, :not_found}
    end
  end

  defp resolve_group_role(_group_id, %{role: :admin}), do: :admin

  defp resolve_group_role(group_id, user) do
    case GroupMembership
         |> Ash.Query.filter(user_id == ^user.id and group_id == ^group_id)
         |> Ash.read_one(domain: Groups, actor: user, authorize?: false) do
      {:ok, %GroupMembership{role: role}} -> role
      _ -> :member
    end
  end
end
