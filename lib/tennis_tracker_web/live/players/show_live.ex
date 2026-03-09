defmodule TennisTrackerWeb.Players.ShowLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :player, nil)}
  end

  def handle_params(%{"id" => id}, _url, socket) do
    player = Tennis.get_player!(id)
    {:noreply, assign(socket, :player, player)}
  end

  def handle_event("delete", _params, socket) do
    Tennis.destroy_player!(socket.assigns.player)

    {:noreply,
     socket
     |> put_flash(:info, "Player deleted.")
     |> push_navigate(to: ~p"/players")}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@player.name}
        <:actions>
          <.button navigate={~p"/players/#{@player.id}/edit"}>Edit</.button>
          <.link
            phx-click="delete"
            data-confirm="Delete this player?"
            class="btn btn-error btn-soft"
          >
            Delete
          </.link>
        </:actions>
      </.header>

      <.list>
        <:item title="Email">{@player.email || "—"}</:item>
        <:item title="Phone">{@player.phone_number || "—"}</:item>
        <:item title="NTRP Rating">{@player.ntrp_rating || "—"}</:item>
        <:item title="18+ Eligible?">{if @player.eligible_18_plus, do: "Yes", else: "No"}</:item>
        <:item title="40+ Eligible?">{if @player.eligible_40_plus, do: "Yes", else: "No"}</:item>
        <:item title="55+ Eligible?">{if @player.eligible_55_plus, do: "Yes", else: "No"}</:item>
      </.list>

      <div class="mt-6">
        <.link navigate={~p"/players"} class="text-sm text-base-content/70 hover:text-base-content">
          ← Back to players
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
