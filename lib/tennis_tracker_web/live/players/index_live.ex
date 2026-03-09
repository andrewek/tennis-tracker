defmodule TennisTrackerWeb.Players.IndexLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis

  def mount(_params, _session, socket) do
    players = Tennis.list_players!()
    {:ok, stream(socket, :players, players)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Players
        <:actions>
          <.button navigate={~p"/players/new"}>New Player</.button>
        </:actions>
      </.header>

      <.table id="players" rows={@streams.players}>
        <:col :let={{_id, player}} label="Name">
          <.link navigate={~p"/players/#{player.id}"}>{player.name}</.link>
        </:col>
        <:col :let={{_id, player}} label="NTRP">{player.ntrp_rating}</:col>
        <:col :let={{_id, player}} label="18+ Eligible?">
          {if player.eligible_18_plus, do: "Yes", else: "No"}
        </:col>
        <:col :let={{_id, player}} label="40+ Eligible?">
          {if player.eligible_40_plus, do: "Yes", else: "No"}
        </:col>
        <:col :let={{_id, player}} label="55+ Eligible?">
          {if player.eligible_55_plus, do: "Yes", else: "No"}
        </:col>
      </.table>
    </Layouts.app>
    """
  end
end
