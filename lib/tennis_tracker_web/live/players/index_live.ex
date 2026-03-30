defmodule TennisTrackerWeb.Players.IndexLive do
  use TennisTrackerWeb, :live_view

  require Ash.Query

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Player, PlayerFilters}

  @ntrp_ratings [
    {"2.5", "2.5"},
    {"3.0", "3.0"},
    {"3.5", "3.5"},
    {"4.0", "4.0"},
    {"4.5", "4.5"},
    {"5.0", "5.0"},
    {"No rating", "none"}
  ]

  def mount(_params, _session, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    total_count =
      Player
      |> Ash.Query.for_read(:read, %{}, actor: current_user)
      |> Ash.count!(domain: Tennis, tenant: group_id)

    tag_categories =
      Tennis.list_tag_categories!(load: [:tags], tenant: group_id, actor: current_user)

    socket
    |> stream(:players, [])
    |> assign(:total_count, total_count)
    |> assign(:player_count, 0)
    |> assign(:name_search, "")
    |> assign(:ntrp_filter, [])
    |> assign(:tag_filter, %{include: %{}, show_untagged: []})
    |> assign(:ntrp_sort, "desc")
    |> assign(:ntrp_ratings, @ntrp_ratings)
    |> assign(:tag_categories, tag_categories)
    |> ok()
  end

  def handle_params(params, _url, socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user
    group_slug = socket.assigns.current_group.slug

    name_search = params["name"] || ""
    ntrp_filter = parse_list_param(params["ntrp"])
    ntrp_sort = if params["ntrp_sort"] == "asc", do: "asc", else: "desc"
    ntrp_sort_atom = if ntrp_sort == "asc", do: :asc_nils_first, else: :desc_nils_last

    # Parse tags[] param into tag_filter include map
    # show_untagged is not URL-encoded — reset to [] on page load
    tag_ids = params["tags"] || []
    tag_ids = if is_list(tag_ids), do: tag_ids, else: [tag_ids]

    tag_filter =
      if tag_ids == [] do
        %{include: %{}, show_untagged: []}
      else
        # Resolve IDs against loaded tag_categories, silently ignore unknowns
        all_tags =
          socket.assigns.tag_categories
          |> Enum.flat_map(& &1.tags)

        valid_tag_ids = MapSet.new(all_tags, & &1.id)

        include =
          tag_ids
          |> Enum.filter(&MapSet.member?(valid_tag_ids, &1))
          |> Enum.reduce(%{}, fn tag_id, acc ->
            tag = Enum.find(all_tags, &(&1.id == tag_id))
            category_id = tag && tag.tag_category_id

            if category_id do
              Map.update(acc, category_id, [tag_id], &[tag_id | &1])
            else
              acc
            end
          end)

        %{include: include, show_untagged: []}
      end

    players =
      PlayerFilters.fetch_players(name_search, ntrp_filter, tag_filter,
        ntrp_sort: ntrp_sort_atom,
        tenant: group_id,
        actor: current_user,
        load: [:tags]
      )

    socket
    |> assign(:name_search, name_search)
    |> assign(:ntrp_filter, ntrp_filter)
    |> assign(:tag_filter, tag_filter)
    |> assign(:ntrp_sort, ntrp_sort)
    |> assign(:export_url, export_url(group_slug, name_search, ntrp_filter, tag_filter))
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

        <%!-- NTRP filter pills --%>
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

        <%!-- Tag category facets --%>
        <.tag_filter_facets
          tag_categories={@tag_categories}
          tag_filter={@tag_filter}
          on_toggle_tag="toggle_tag"
          on_toggle_untagged="toggle_show_untagged"
        />

        <button
          :if={
            @name_search != "" or @ntrp_filter != [] or
              map_size(@tag_filter.include) > 0
          }
          phx-click="clear_filter"
          class="btn btn-xs btn-ghost text-base-content/40"
        >
          <.icon name="hero-x-mark" class="size-3.5" /> Clear all filters
        </button>
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
                  <.tag_chips tags={player.tags} />
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

  def handle_event("toggle_tag", %{"category_id" => category_id, "tag_id" => tag_id}, socket) do
    tag_filter = socket.assigns.tag_filter

    updated_include =
      tag_filter.include
      |> Map.update(category_id, [tag_id], fn tags ->
        if tag_id in tags, do: List.delete(tags, tag_id), else: [tag_id | tags]
      end)
      |> Map.reject(fn {_, v} -> v == [] end)

    new_filter = %{tag_filter | include: updated_include}

    socket
    |> push_patch(to: filter_url(socket, tag_filter: new_filter))
    |> noreply()
  end

  def handle_event("toggle_show_untagged", %{"category_id" => category_id}, socket) do
    tag_filter = socket.assigns.tag_filter

    updated_show =
      if category_id in tag_filter.show_untagged,
        do: List.delete(tag_filter.show_untagged, category_id),
        else: [category_id | tag_filter.show_untagged]

    new_filter = %{tag_filter | show_untagged: updated_show}

    # show_untagged is NOT URL-encoded — update socket assign directly
    socket
    |> assign(:tag_filter, new_filter)
    |> handle_params_reload()
    |> noreply()
  end

  def handle_event("toggle_ntrp_sort", _params, socket) do
    new_sort = if socket.assigns.ntrp_sort == "desc", do: "asc", else: "desc"

    socket
    |> push_patch(to: filter_url(socket, ntrp_sort: new_sort))
    |> noreply()
  end

  # Reload players using current assigns (for show_untagged toggle which isn't URL-encoded)
  defp handle_params_reload(socket) do
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    ntrp_sort_atom =
      if socket.assigns.ntrp_sort == "asc", do: :asc_nils_first, else: :desc_nils_last

    players =
      PlayerFilters.fetch_players(
        socket.assigns.name_search,
        socket.assigns.ntrp_filter,
        socket.assigns.tag_filter,
        ntrp_sort: ntrp_sort_atom,
        tenant: group_id,
        actor: current_user,
        load: [:tags]
      )

    socket
    |> assign(:player_count, length(players))
    |> stream(:players, players, reset: true)
  end

  defp filter_url(socket, overrides) do
    group_slug = socket.assigns.current_group.slug
    name = Keyword.get(overrides, :name_search, socket.assigns.name_search)
    ntrp = Keyword.get(overrides, :ntrp_filter, socket.assigns.ntrp_filter)
    ntrp_sort = Keyword.get(overrides, :ntrp_sort, socket.assigns.ntrp_sort)
    tag_filter = Keyword.get(overrides, :tag_filter, socket.assigns.tag_filter)

    # Encode selected tag IDs as tags[]
    tag_ids = tag_filter.include |> Map.values() |> List.flatten()

    params =
      [
        {"name", name},
        {"ntrp", Enum.join(ntrp, ",")},
        {"ntrp_sort", if(ntrp_sort == "asc", do: "asc", else: "")}
      ]
      |> Enum.reject(fn {_, v} -> v == "" end)
      |> Map.new()

    tag_params = Enum.map(tag_ids, &{"tags[]", &1})

    base = ~p"/g/#{group_slug}/players"

    all_params = Map.to_list(params) ++ tag_params

    if all_params == [] do
      base
    else
      "#{base}?#{URI.encode_query(all_params)}"
    end
  end

  defp parse_list_param(s), do: PlayerFilters.parse_list_param(s)

  defp export_url(group_slug, name_search, ntrp_filter, tag_filter) do
    tag_ids = tag_filter.include |> Map.values() |> List.flatten()
    tag_params = Enum.map(tag_ids, &{"tags[]", &1})

    params =
      [{"name", name_search}, {"ntrp", Enum.join(ntrp_filter, ",")}]
      |> Enum.reject(fn {_, v} -> v == "" end)
      |> Map.new()

    base = ~p"/g/#{group_slug}/players/export.csv"
    all_params = Map.to_list(params) ++ tag_params

    if all_params == [], do: base, else: "#{base}?#{URI.encode_query(all_params)}"
  end
end
