defmodule TennisTrackerWeb.Teams.ShowLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.BoardComponents

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.Match

  def mount(_params, _session, socket) do
    socket
    |> assign(:team, nil)
    |> assign(:players, [])
    |> assign(:selected_player, nil)
    |> assign(:show_match_form, false)
    |> assign(:form, nil)
    |> assign(:locations, [])
    |> stream(:upcoming_matches, [])
    |> stream(:past_matches, [])
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    case Tennis.get_team_with_roster(id) do
      {:ok, team} ->
        players = team.memberships |> Enum.map(& &1.player) |> Enum.sort_by(& &1.name)
        upcoming = Tennis.list_upcoming_matches_for_team!(team.id, load: [:location])
        past = Tennis.list_past_matches_for_team!(team.id, load: [:location])

        socket
        |> assign(:team, team)
        |> assign(:players, players)
        |> stream(:upcoming_matches, upcoming, reset: true)
        |> stream(:past_matches, past, reset: true)
        |> noreply()

      {:error, _} ->
        socket
        |> put_flash(:error, "Team not found.")
        |> push_navigate(to: ~p"/")
        |> noreply()
    end
  end

  def handle_event("show_player", %{"player_id" => player_id}, socket) do
    player = Enum.find(socket.assigns.players, &(&1.id == player_id))
    socket |> assign(:selected_player, player) |> noreply()
  end

  def handle_event("close_player_modal", _params, socket) do
    socket |> assign(:selected_player, nil) |> noreply()
  end

  def handle_event("open_match_form", _params, socket) do
    form =
      AshPhoenix.Form.for_create(Match, :create,
        domain: Tennis,
        forms: [auto?: true]
      )
      |> to_form()

    locations = Tennis.list_locations!()

    socket
    |> assign(:show_match_form, true)
    |> assign(:form, form)
    |> assign(:locations, locations)
    |> noreply()
  end

  def handle_event("close_match_form", _params, socket) do
    socket |> assign(:show_match_form, false) |> assign(:form, nil) |> noreply()
  end

  def handle_event("validate_match", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    socket |> assign(:form, form) |> noreply()
  end

  def handle_event("save_match", %{"form" => params}, socket) do
    team = socket.assigns.team
    params_with_team = Map.put(params, "team_id", team.id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: params_with_team) do
      {:ok, _match} ->
        upcoming = Tennis.list_upcoming_matches_for_team!(team.id, load: [:location])
        past = Tennis.list_past_matches_for_team!(team.id, load: [:location])

        socket
        |> assign(:show_match_form, false)
        |> assign(:form, nil)
        |> stream(:upcoming_matches, upcoming, reset: true)
        |> stream(:past_matches, past, reset: true)
        |> put_flash(:info, "Match added.")
        |> noreply()

      {:error, form} ->
        socket |> assign(:form, form) |> noreply()
    end
  end

  defp format_match_time(%Time{hour: h, minute: m}) do
    {hour, ampm} =
      if h >= 12,
        do: {rem(h, 12) |> then(&if(&1 == 0, do: 12, else: &1)), "PM"},
        else: {if(h == 0, do: 12, else: h), "AM"}

    minute_str = m |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{hour}:#{minute_str} #{ampm}"
  end

  defp format_match_date(%Date{} = date) do
    Calendar.strftime(date, "%a, %b %-d")
  end

  defp format_home_or_away(:home, opponent), do: "HOME v. #{opponent}"
  defp format_home_or_away(:away, opponent), do: "AWAY v. #{opponent}"

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mb-6">
        <.link navigate={~p"/teams"} class="text-sm text-base-content/70 hover:text-base-content">
          <.icon name="hero-arrow-left" class="size-4 inline" /> Back to Teams
        </.link>
      </div>

      <%!-- Team header --%>
      <div class="mb-8">
        <h1 class="text-4xl font-bold tracking-tight">{@team.name}</h1>
        <p class="mt-1 text-base-content/60">
          {@team.team_type.name} · {@team.season_year}
        </p>
      </div>

      <%!-- Roster + schedule: flex wrap so each column only takes the space it needs --%>
      <div class="flex flex-wrap gap-6 items-start">
        <%!-- Roster card --%>
        <div class="bg-base-200 rounded-lg p-4 w-full max-w-64">
          <div class="flex items-center gap-2 mb-3">
            <h2 class="font-semibold">Roster</h2>
            <span class="badge badge-xs badge-ghost">{length(@players)}</span>
          </div>

          <%= if @players == [] do %>
            <p class="text-sm text-base-content/50">No players on this roster.</p>
          <% else %>
            <div class="space-y-1">
              <.player_card
                :for={player <- @players}
                player={player}
                readonly={true}
                on_click="show_player"
              />
            </div>
          <% end %>
        </div>

        <%!-- Match schedule card --%>
        <div class="bg-base-200 rounded-lg p-4 w-full max-w-md">
          <div class="flex items-center justify-between mb-3">
            <h2 class="font-semibold">Upcoming Matches</h2>
            <button class="btn btn-xs btn-ghost" phx-click="open_match_form">
              <.icon name="hero-plus" class="size-3 inline" /> Add Match
            </button>
          </div>

          <div id="upcoming-matches" phx-update="stream" class="space-y-3">
            <div
              :for={{dom_id, match} <- @streams.upcoming_matches}
              id={dom_id}
              class="bg-base-100 rounded px-3 py-2 text-sm"
            >
              <.link navigate={~p"/matches/#{match.id}"} class="hover:underline">
                <p class="font-medium">
                  {format_home_or_away(match.home_or_away, match.opponent)}
                </p>
              </.link>
              <p class="text-base-content/60">
                {format_match_date(match.match_date)} · {format_match_time(match.match_time)}
              </p>
              <p class="text-base-content/60">
                <%= if match.location do %>
                  {match.location.name}
                <% else %>
                  Location TBD
                <% end %>
              </p>
            </div>
          </div>

          <p
            :if={@streams.upcoming_matches.inserts == []}
            class="text-sm text-base-content/50"
          >
            No upcoming matches scheduled.
          </p>

          <%!-- Past matches --%>
          <div class="mt-6">
            <h2 class="font-semibold mb-3">Past Matches</h2>

            <div id="past-matches" phx-update="stream" class="space-y-3">
              <div
                :for={{dom_id, match} <- @streams.past_matches}
                id={dom_id}
                class="bg-base-100 rounded px-3 py-2 text-sm opacity-70"
              >
                <.link navigate={~p"/matches/#{match.id}"} class="hover:underline">
                  <p class="font-medium">
                    {format_home_or_away(match.home_or_away, match.opponent)}
                  </p>
                </.link>
                <p class="text-base-content/60">
                  {format_match_date(match.match_date)} · {format_match_time(match.match_time)}
                </p>
                <p class="text-base-content/60">
                  <%= if match.location do %>
                    {match.location.name}
                  <% else %>
                    Location TBD
                  <% end %>
                </p>
              </div>
            </div>

            <p
              :if={@streams.past_matches.inserts == []}
              class="text-sm text-base-content/50"
            >
              No past matches.
            </p>
          </div>
        </div>
      </div>

      <%!-- Player quick-look modal --%>
      <.player_detail_modal
        :if={@selected_player}
        player={@selected_player}
        current_team={@team.name}
        on_close={JS.push("close_player_modal")}
      />

      <%!-- Add Match modal --%>
      <.modal
        :if={@show_match_form}
        title="Add Match"
        on_close={JS.push("close_match_form")}
        max_width="max-w-lg"
      >
        <.form for={@form} phx-change="validate_match" phx-submit="save_match">
          <.input field={@form[:opponent]} type="text" label="Opponent" />
          <.input
            field={@form[:home_or_away]}
            type="select"
            label="Home or Away"
            options={[{"Home", "home"}, {"Away", "away"}]}
            prompt="Select..."
          />
          <.input field={@form[:match_date]} type="date" label="Match Date" />
          <.input field={@form[:match_time]} type="time" label="Match Time" />
          <.input
            field={@form[:location_id]}
            type="select"
            label="Location"
            options={Enum.map(@locations, &{&1.name, &1.id})}
            prompt="Location TBD"
          />
          <div class="mt-4 flex gap-2 justify-end">
            <button type="button" class="btn btn-ghost btn-sm" phx-click="close_match_form">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary btn-sm">Save Match</button>
          </div>
        </.form>
      </.modal>
    </Layouts.app>
    """
  end
end
