defmodule TennisTrackerWeb.GroupHomeLive do
  use TennisTrackerWeb, :live_view

  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Home")
    |> ok()
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_group={@current_group}
      current_group_role={@current_group_role}
    >
      <.page_header title="Home" />
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        <.link
          navigate={~p"/g/#{@current_group.slug}/players"}
          class="group relative rounded-box px-6 py-8 text-center font-semibold leading-6 block"
        >
          <span class="absolute inset-0 rounded-box bg-base-200 transition-all duration-200 group-hover:bg-base-300 group-hover:scale-105 group-hover:shadow-lg">
          </span>
          <span class="relative flex flex-col items-center gap-3">
            <.icon name="hero-user" class="h-8 w-8" />
            <span class="text-base">Players</span>
            <span class="text-xs font-normal text-base-content/60">
              View and manage your roster
            </span>
          </span>
        </.link>

        <.link
          navigate={~p"/g/#{@current_group.slug}/teams"}
          class="group relative rounded-box px-6 py-8 text-center font-semibold leading-6 block"
        >
          <span class="absolute inset-0 rounded-box bg-base-200 transition-all duration-200 group-hover:bg-base-300 group-hover:scale-105 group-hover:shadow-lg">
          </span>
          <span class="relative flex flex-col items-center gap-3">
            <.icon name="hero-user-group" class="h-8 w-8" />
            <span class="text-base">Teams</span>
            <span class="text-xs font-normal text-base-content/60">
              Organize players into teams
            </span>
          </span>
        </.link>

        <.link
          navigate={~p"/g/#{@current_group.slug}/roster-planner"}
          class="group relative rounded-box px-6 py-8 text-center font-semibold leading-6 block"
        >
          <span class="absolute inset-0 rounded-box bg-base-200 transition-all duration-200 group-hover:bg-base-300 group-hover:scale-105 group-hover:shadow-lg">
          </span>
          <span class="relative flex flex-col items-center gap-3">
            <.icon name="hero-clipboard-document-list" class="h-8 w-8" />
            <span class="text-base">Roster Planner</span>
            <span class="text-xs font-normal text-base-content/60">Plan and assign team rosters</span>
          </span>
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
