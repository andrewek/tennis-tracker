defmodule TennisTrackerWeb.Players.IndexLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.Player
  alias TennisTracker.Tennis.PlayerFilters

  @ntrp_ratings [
    {"2.5", "2.5"},
    {"3.0", "3.0"},
    {"3.5", "3.5"},
    {"4.0", "4.0"},
    {"4.5", "4.5"},
    {"5.0", "5.0"},
    {"No rating", "none"}
  ]

  @bracket_options [
    {"18+ eligible", "18"},
    {"40+ eligible", "40"},
    {"55+ eligible", "55"}
  ]

  def mount(_params, _session, socket) do
    total_count = Ash.count!(Player, domain: Tennis)

    {:ok,
     socket
     |> stream(:players, [])
     |> assign(:total_count, total_count)
     |> assign(:player_count, 0)
     |> assign(:name_search, "")
     |> assign(:ntrp_filter, [])
     |> assign(:bracket_filter, [])
     |> assign(:ntrp_sort, "desc")
     |> assign(:ntrp_ratings, @ntrp_ratings)
     |> assign(:bracket_options, @bracket_options)}
  end

  def handle_params(params, _url, socket) do
    name_search = params["name"] || ""
    ntrp_filter = parse_list_param(params["ntrp"])
    bracket_filter = parse_list_param(params["bracket"])
    ntrp_sort = if params["ntrp_sort"] == "asc", do: "asc", else: "desc"
    ntrp_sort_atom = if ntrp_sort == "asc", do: :asc_nils_first, else: :desc_nils_last

    players = fetch_players(name_search, ntrp_filter, bracket_filter, ntrp_sort_atom)

    {:noreply,
     socket
     |> assign(:name_search, name_search)
     |> assign(:ntrp_filter, ntrp_filter)
     |> assign(:bracket_filter, bracket_filter)
     |> assign(:ntrp_sort, ntrp_sort)
     |> assign(:export_url, export_url(name_search, ntrp_filter, bracket_filter))
     |> assign(:player_count, length(players))
     |> stream(:players, players, reset: true)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Players
        <:subtitle>
          Showing {@player_count} of {@total_count}
        </:subtitle>
        <:actions>
          <.button href={@export_url}>Export CSV</.button>
          <.button navigate={~p"/players/import"}>Import CSV</.button>
          <.button navigate={~p"/players/new"}>New Player</.button>
        </:actions>
      </.header>

      <div class="mb-4 space-y-3">
        <form phx-change="search_name">
          <input
            type="text"
            name="name_search"
            value={@name_search}
            placeholder="Search by name…"
            phx-debounce="200"
            class="input input-sm w-full max-w-sm"
          />
        </form>

        <div class="flex flex-wrap gap-6">
          <div>
            <div class="flex items-center gap-2 mb-1">
              <p class="text-xs text-base-content/60">NTRP Rating</p>
              <button
                phx-click="toggle_ntrp_sort"
                class="text-xs text-base-content/50 hover:text-base-content transition-colors"
                title={"Sort #{if @ntrp_sort == "desc", do: "ascending", else: "descending"}"}
              >
                <%= if @ntrp_sort == "desc" do %>
                  <.icon name="hero-arrow-down" class="size-3.5 inline" /> Desc
                <% else %>
                  <.icon name="hero-arrow-up" class="size-3.5 inline" /> Asc
                <% end %>
              </button>
            </div>
            <div class="flex gap-4 flex-wrap">
              <%= for {label, value} <- @ntrp_ratings do %>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    class="checkbox checkbox-sm"
                    checked={value in @ntrp_filter}
                    phx-click="toggle_ntrp"
                    phx-value-rating={value}
                  />
                  <span class="text-sm">{label}</span>
                </label>
              <% end %>
            </div>
          </div>

          <div>
            <p class="text-xs text-base-content/60 mb-1">Age Bracket</p>
            <div class="flex gap-4 flex-wrap">
              <%= for {label, value} <- @bracket_options do %>
                <label class="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    class="checkbox checkbox-sm"
                    checked={value in @bracket_filter}
                    phx-click="toggle_bracket"
                    phx-value-bracket={value}
                  />
                  <span class="text-sm">{label}</span>
                </label>
              <% end %>
            </div>
          </div>
        </div>

        <.button
          :if={@name_search != "" or @ntrp_filter != [] or @bracket_filter != []}
          phx-click="clear_filter"
          class="btn btn-sm btn-ghost text-base-content/50"
        >
          <.icon name="hero-x-mark" class="size-4 inline" /> Clear filters
        </.button>
      </div>

      <.table id="players" rows={@streams.players}>
        <:col :let={{_id, player}} label="Name">
          <div class="flex items-center gap-2 flex-wrap">
            <.link navigate={~p"/players/#{player.id}"}>{player.name}</.link>
            <.age_bracket_chips player={player} />
          </div>
        </:col>
        <:col :let={{_id, player}} label="NTRP">{player.ntrp_rating}</:col>
      </.table>
    </Layouts.app>
    """
  end

  def handle_event("clear_filter", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/players")}
  end

  def handle_event("search_name", %{"name_search" => value}, socket) do
    {:noreply, push_patch(socket, to: filter_url(socket, name_search: value))}
  end

  def handle_event("toggle_ntrp", %{"rating" => rating}, socket) do
    current = socket.assigns.ntrp_filter
    updated = if rating in current, do: List.delete(current, rating), else: [rating | current]
    {:noreply, push_patch(socket, to: filter_url(socket, ntrp_filter: updated))}
  end

  def handle_event("toggle_bracket", %{"bracket" => bracket}, socket) do
    current = socket.assigns.bracket_filter
    updated = if bracket in current, do: List.delete(current, bracket), else: [bracket | current]
    {:noreply, push_patch(socket, to: filter_url(socket, bracket_filter: updated))}
  end

  def handle_event("toggle_ntrp_sort", _params, socket) do
    new_sort = if socket.assigns.ntrp_sort == "desc", do: "asc", else: "desc"
    {:noreply, push_patch(socket, to: filter_url(socket, ntrp_sort: new_sort))}
  end

  defp filter_url(socket, overrides) do
    name = Keyword.get(overrides, :name_search, socket.assigns.name_search)
    ntrp = Keyword.get(overrides, :ntrp_filter, socket.assigns.ntrp_filter)
    bracket = Keyword.get(overrides, :bracket_filter, socket.assigns.bracket_filter)
    ntrp_sort = Keyword.get(overrides, :ntrp_sort, socket.assigns.ntrp_sort)

    params =
      [
        {"name", name},
        {"ntrp", Enum.join(ntrp, ",")},
        {"bracket", Enum.join(bracket, ",")},
        {"ntrp_sort", if(ntrp_sort == "asc", do: "asc", else: "")}
      ]
      |> Enum.reject(fn {_, v} -> v == "" end)
      |> Map.new()

    if map_size(params) > 0, do: ~p"/players?#{params}", else: ~p"/players"
  end

  defp parse_list_param(s), do: PlayerFilters.parse_list_param(s)

  defp fetch_players(name_search, ntrp_filter, bracket_filter, ntrp_sort) do
    PlayerFilters.fetch_players(name_search, ntrp_filter, bracket_filter, ntrp_sort)
  end

  defp export_url(name_search, ntrp_filter, bracket_filter) do
    params =
      [
        {"name", name_search},
        {"ntrp", Enum.join(ntrp_filter, ",")},
        {"bracket", Enum.join(bracket_filter, ",")}
      ]
      |> Enum.reject(fn {_, v} -> v == "" end)
      |> Map.new()

    if map_size(params) > 0,
      do: ~p"/players/export.csv?#{params}",
      else: ~p"/players/export.csv"
  end
end
