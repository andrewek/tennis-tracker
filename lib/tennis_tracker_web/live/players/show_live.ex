defmodule TennisTrackerWeb.Players.ShowLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis

  def mount(_params, _session, socket) do
    socket
    |> assign(:player, nil)
    |> assign(:memberships, [])
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    player = Tennis.get_player!(id)
    memberships = Tennis.list_real_memberships_for_player!(id, load: [:display_label])

    socket
    |> assign(:player, player)
    |> assign(:memberships, memberships)
    |> noreply()
  end

  def handle_event("delete", _params, socket) do
    Tennis.destroy_player!(socket.assigns.player)

    socket
    |> put_flash(:info, "Player deleted.")
    |> push_navigate(to: ~p"/players")
    |> noreply()
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
        <h2 class="text-lg font-semibold mb-2">Team Memberships</h2>
        <%= if @memberships == [] do %>
          <p class="text-base-content/60 text-sm">No team memberships.</p>
        <% else %>
          <ul class="space-y-1">
            <%= for membership <- @memberships do %>
              <li class="text-sm">
                {membership.display_label}
              </li>
            <% end %>
          </ul>
        <% end %>
      </div>

      <div class="mt-6">
        <.link navigate={~p"/players"} class="text-sm text-base-content/70 hover:text-base-content">
          <.icon name="hero-arrow-left" class="size-4 inline" /> Back to players
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
