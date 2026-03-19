defmodule TennisTrackerWeb.HomeLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Groups

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    case Groups.list_groups_for_user(current_user.id, actor: current_user) do
      {:ok, [single_group]} ->
        socket
        |> push_navigate(to: ~p"/g/#{single_group.slug}/teams")
        |> ok()

      _ ->
        socket
        |> push_navigate(to: ~p"/groups")
        |> ok()
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Tennis Tracker" />
      <p class="text-base-content/60">Loading…</p>
    </Layouts.app>
    """
  end
end
