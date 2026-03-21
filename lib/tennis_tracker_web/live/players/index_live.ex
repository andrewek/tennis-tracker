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
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    total_count =
      Player
      |> Ash.Query.for_read(:read, %{}, actor: current_user)
      |> Ash.count!(domain: Tennis, tenant: group_id)

    socket
    |> stream(:players, [])
    |> assign(:total_count, total_count)
    |> assign(:player_count, 0)
    |> assign(:name_search, "")
    |> assign(:ntrp_filter, [])
    |> assign(:bracket_filter, [])
    |> assign(:ntrp_sort, "desc")
    |> assign(:ntrp_ratings, @ntrp_ratings)
    |> assign(:bracket_options, @bracket_options)
    |> ok()
  end

  def handle_params(params, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    group_slug = socket.assigns.current_group.slug

    name_search = params["name"] || ""
    ntrp_filter = parse_list_param(params["ntrp"])
    bracket_filter = parse_list_param(params["bracket"])
    ntrp_sort = if params["ntrp_sort"] == "asc", do: "asc", else: "desc"
    ntrp_sort_atom = if ntrp_sort == "asc", do: :asc_nils_first, else: :desc_nils_last

    players =
      PlayerFilters.fetch_players(name_search, ntrp_filter, bracket_filter,
        ntrp_sort: ntrp_sort_atom,
        tenant: group_id,
        actor: current_user
      )

    socket
    |> assign(:name_search, name_search)
    |> assign(:ntrp_filter, ntrp_filter)
    |> assign(:bracket_filter, bracket_filter)
    |> assign(:ntrp_sort, ntrp_sort)
    |> assign(:export_url, export_url(group_slug, name_search, ntrp_filter, bracket_filter))
    |> assign(:player_count, length(players))
    |> stream(:players, players, reset: true)
    |> noreply()
  end

  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      current_group={@current_group}
      current_group_role={@current_group_role}
    >
      <.page_header title="Players">
        <:subtitle>Showing {@player_count} of {@total_count}</:subtitle>
        <:actions>
          <div class="flex gap-2 flex-wrap">
            <.button href={@export_url}>Export CSV</.button>
            <.button navigate={~p"/g/#{@current_group.slug}/players/import"}>Import CSV</.button>
            <.button navigate={~p"/g/#{@current_group.slug}/players/new"}>New Player</.button>
          </div>
        </:actions>
      </.page_header>

      <div class="mb-4 space-y-2">
        <%!-- Name search --%>
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

        <%!-- Compact filter pills --%>
        <div class="space-y-1">
          <div class="flex items-center gap-1">
            <span class="text-xs text-base-content/50 w-8">NTRP</span>
            <%= for {label, value} <- @ntrp_ratings do %>
              <button
                phx-click="toggle_ntrp"
                phx-value-rating={value}
                class={[
                  "btn btn-xs",
                  value in @ntrp_filter && "btn-neutral",
                  value not in @ntrp_filter && "btn-ghost"
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>

          <div class="flex items-center gap-1">
            <span class="text-xs text-base-content/50 w-8">Age</span>
            <%= for {label, value} <- @bracket_options do %>
              <button
                phx-click="toggle_bracket"
                phx-value-bracket={value}
                class={[
                  "btn btn-xs",
                  value in @bracket_filter && "btn-neutral",
                  value not in @bracket_filter && "btn-ghost"
                ]}
              >
                {label}
              </button>
            <% end %>
          </div>

          <button
            :if={@name_search != "" or @ntrp_filter != [] or @bracket_filter != []}
            phx-click="clear_filter"
            class="btn btn-xs btn-ghost text-base-content/40"
          >
            <.icon name="hero-x-mark" class="size-3.5" /> Clear all filters
          </button>
        </div>
      </div>

      <div class="max-w-2xl">
        <table class="table table-zebra">
          <thead>
            <tr>
              <th>Name</th>
              <th>
                <button
                  phx-click="toggle_ntrp_sort"
                  class="flex items-center gap-1 hover:text-base-content transition-colors"
                  title={"Sort #{if @ntrp_sort == "desc", do: "ascending", else: "descending"}"}
                >
                  NTRP
                  <%= if @ntrp_sort == "desc" do %>
                    <.icon name="hero-arrow-down" class="size-3.5" />
                  <% else %>
                    <.icon name="hero-arrow-up" class="size-3.5" />
                  <% end %>
                </button>
              </th>
            </tr>
          </thead>
          <tbody id="players" phx-update="stream">
            <tr :for={{dom_id, player} <- @streams.players} id={dom_id}>
              <td>
                <div class="flex items-center gap-2 flex-wrap">
                  <.link navigate={~p"/g/#{@current_group.slug}/players/#{player.id}"}>
                    {player.name}
                  </.link>
                  <.age_bracket_chips player={player} />
                </div>
              </td>
              <td>{player.ntrp_rating}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("clear_filter", _params, socket) do
    socket
    |> push_patch(to: ~p"/g/#{socket.assigns.current_group.slug}/players")
    |> noreply()
  end

  def handle_event("search_name", %{"name_search" => value}, socket) do
    socket
    |> push_patch(to: filter_url(socket, name_search: value))
    |> noreply()
  end

  def handle_event("toggle_ntrp", %{"rating" => rating}, socket) do
    current = socket.assigns.ntrp_filter
    updated = if rating in current, do: List.delete(current, rating), else: [rating | current]

    socket
    |> push_patch(to: filter_url(socket, ntrp_filter: updated))
    |> noreply()
  end

  def handle_event("toggle_bracket", %{"bracket" => bracket}, socket) do
    current = socket.assigns.bracket_filter
    updated = if bracket in current, do: List.delete(current, bracket), else: [bracket | current]

    socket
    |> push_patch(to: filter_url(socket, bracket_filter: updated))
    |> noreply()
  end

  def handle_event("toggle_ntrp_sort", _params, socket) do
    new_sort = if socket.assigns.ntrp_sort == "desc", do: "asc", else: "desc"

    socket
    |> push_patch(to: filter_url(socket, ntrp_sort: new_sort))
    |> noreply()
  end

  defp filter_url(socket, overrides) do
    group_slug = socket.assigns.current_group.slug
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

    base = ~p"/g/#{group_slug}/players"
    if map_size(params) > 0, do: "#{base}?#{URI.encode_query(params)}", else: base
  end

  defp parse_list_param(s), do: PlayerFilters.parse_list_param(s)

  defp export_url(group_slug, name_search, ntrp_filter, bracket_filter) do
    params =
      [
        {"name", name_search},
        {"ntrp", Enum.join(ntrp_filter, ",")},
        {"bracket", Enum.join(bracket_filter, ",")}
      ]
      |> Enum.reject(fn {_, v} -> v == "" end)
      |> Map.new()

    base = ~p"/g/#{group_slug}/players/export.csv"
    if map_size(params) > 0, do: "#{base}?#{URI.encode_query(params)}", else: base
  end
end
