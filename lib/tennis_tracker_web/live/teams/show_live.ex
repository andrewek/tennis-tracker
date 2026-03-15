defmodule TennisTrackerWeb.Teams.ShowLive do
  use TennisTrackerWeb, :live_view

  import TennisTrackerWeb.BoardComponents

  alias TennisTracker.Tennis

  @placeholder_matches [
    %{
      date: ~D[2025-04-05],
      time: ~T[10:00:00],
      day_of_week: "Saturday",
      location: "Woods Tennis Center",
      home_or_away: :home,
      opponent: "Ronhovde"
    },
    %{
      date: ~D[2025-04-12],
      time: ~T[09:00:00],
      day_of_week: "Saturday",
      location: "Genesis Westroads",
      home_or_away: :away,
      opponent: "Timan"
    },
    %{
      date: ~D[2025-04-19],
      time: ~T[10:00:00],
      day_of_week: "Saturday",
      location: "Woods Tennis Center",
      home_or_away: :home,
      opponent: "Stiles"
    }
  ]

  def mount(_params, _session, socket) do
    socket
    |> assign(:team, nil)
    |> assign(:players, [])
    |> assign(:matches, @placeholder_matches)
    |> assign(:selected_player, nil)
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    case Tennis.get_team_with_roster(id) do
      {:ok, team} ->
        players = team.memberships |> Enum.map(& &1.player) |> Enum.sort_by(& &1.name)

        socket
        |> assign(:team, team)
        |> assign(:players, players)
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

  defp format_age_group("18_plus"), do: "18+"
  defp format_age_group("40_plus"), do: "40+"
  defp format_age_group("55_plus"), do: "55+"
  defp format_age_group(other), do: other

  defp format_match_time(%Time{hour: h, minute: m}) do
    {hour, ampm} = if h >= 12, do: {rem(h, 12) |> then(&if(&1 == 0, do: 12, else: &1)), "PM"}, else: {if(h == 0, do: 12, else: h), "AM"}
    minute_str = m |> Integer.to_string() |> String.pad_leading(2, "0")
    "#{hour}:#{minute_str} #{ampm}"
  end

  defp format_match_date(%Date{} = date) do
    Calendar.strftime(date, "%b %-d")
  end

  defp format_opponent(:home, opponent), do: "HOME v. #{opponent}"
  defp format_opponent(:away, opponent), do: "AWAY v. #{opponent}"

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <%!-- Back link (TODO: update to ~p"/teams" once the teams index page exists) --%>
      <div class="mb-6">
        <.link navigate={~p"/"} class="text-sm text-base-content/70 hover:text-base-content">
          <.icon name="hero-arrow-left" class="size-4 inline" /> Back to Teams
        </.link>
      </div>

      <%!-- Team header --%>
      <div class="mb-8">
        <h1 class="text-4xl font-bold tracking-tight">{@team.name}</h1>
        <p class="mt-1 text-base-content/60">
          {@team.team_type.name}
          <span :if={@team.team_type.age_group}>
            · {format_age_group(@team.team_type.age_group)}
          </span>
          <span :if={@team.team_type.ntrp_level}>
            · {@team.team_type.ntrp_level}
          </span>
          · {@team.season_year}
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
        <div class="bg-base-200 rounded-lg p-4 w-full max-w-sm">
          <h2 class="font-semibold mb-3">Match Schedule</h2>
          <div class="space-y-3">
            <div :for={match <- @matches} class="bg-base-100 rounded px-3 py-2 text-sm">
              <p class="font-medium">
                {format_opponent(match.home_or_away, match.opponent)}
              </p>
              <p class="text-base-content/60">
                {match.day_of_week}, {format_match_date(match.date)} · {format_match_time(match.time)}
              </p>
              <p class="text-base-content/60">{match.location}</p>
            </div>
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
    </Layouts.app>
    """
  end
end
