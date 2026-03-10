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
      <div class="mb-6">
        <h1 class="text-4xl font-bold tracking-tight">
          {@player.name}
          <span class="text-3xl font-semibold text-base-content/60 ml-3">
            {if @player.ntrp_rating, do: @player.ntrp_rating, else: "—"}
          </span>
        </h1>
        <div class="mt-2">
          <.age_bracket_chips player={@player} />
        </div>
      </div>

      <div class="flex gap-3 mb-6">
        <.button navigate={~p"/players/#{@player.id}/edit"}>Edit</.button>
        <.link
          phx-click="delete"
          data-confirm="Delete this player?"
          class="btn btn-error btn-soft"
        >
          Delete
        </.link>
      </div>

      <.list>
        <:item title="Email">{@player.email || "—"}</:item>
        <:item title="Phone">{@player.phone_number || "—"}</:item>
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
