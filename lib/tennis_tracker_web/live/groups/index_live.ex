defmodule TennisTrackerWeb.GroupsLive.Index do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Groups

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    groups = load_groups(current_user)

    socket
    |> assign(:page_title, "Groups")
    |> assign(:groups, groups)
    |> ok()
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Organizations" />

      <%= if @groups == [] do %>
        <div class="mt-12 text-center">
          <p class="text-xl font-semibold">No groups yet</p>
          <p class="mt-2 text-base-content/60">
            You are not yet a member of any group.
            A system administrator can add you to a group.
          </p>
        </div>
      <% else %>
        <div class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2 xl:grid-cols-3">
          <.link
            :for={group <- @groups}
            id={"group-#{group.id}"}
            navigate={~p"/g/#{group.slug}/teams"}
            class="group"
          >
            <div class="card bg-base-200 transition-all group-hover:bg-base-300 group-hover:scale-105 group-hover:shadow-lg">
              <div class="card-body gap-2">
                <h2 class="card-title block truncate">{group.name}</h2>
                <p class="text-sm text-base-content/60">{group.slug}</p>
              </div>
            </div>
          </.link>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  defp load_groups(%{role: :admin} = user) do
    case Groups.list_groups(actor: user, authorize?: true) do
      {:ok, groups} -> Enum.sort_by(groups, & &1.name)
      _ -> []
    end
  end

  defp load_groups(user) do
    case Groups.list_groups_for_user(user.id, actor: user) do
      {:ok, groups} -> groups
      _ -> []
    end
  end
end
