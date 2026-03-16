defmodule TennisTrackerWeb.Teams.IndexLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis

  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Teams")
    |> assign(:team_count, 0)
    |> stream(:teams, [])
    |> ok()
  end

  def handle_params(_params, _url, socket) do
    teams = Tennis.list_real_teams!(load: [:team_type_name, :next_match_date, :next_match_time])

    socket
    |> assign(:team_count, length(teams))
    |> stream(:teams, teams, reset: true)
    |> noreply()
  end

  defp format_next_match(nil, _time), do: "Next match: TBD"

  defp format_next_match(date, time) do
    "Next match: #{Calendar.strftime(date, "%a, %b %-d")} · #{format_time(time)}"
  end

  defp format_time(%Time{hour: h, minute: m}) do
    {hour, ampm} =
      if h >= 12,
        do: {rem(h, 12) |> then(&if(&1 == 0, do: 12, else: &1)), "PM"},
        else: {if(h == 0, do: 12, else: h), "AM"}

    "#{hour}:#{m |> Integer.to_string() |> String.pad_leading(2, "0")} #{ampm}"
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} fluid={false}>
      <.header>
        Teams
      </.header>

      <%= if @team_count == 0 do %>
        <div class="mt-12 text-center">
          <p class="text-xl font-semibold">No teams yet</p>
          <p class="mt-2 text-base-content/60">Teams will appear here once they've been added.</p>
        </div>
      <% else %>
        <div class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2 xl:grid-cols-3">
          <.link
            :for={{dom_id, team} <- @streams.teams}
            id={dom_id}
            navigate={~p"/teams/#{team}"}
            class="group"
          >
            <div class="card bg-base-200 transition-all group-hover:bg-base-300 group-hover:scale-105 group-hover:shadow-lg">
              <div class="card-body gap-2">
                <h2 class="card-title block truncate">{team.name}</h2>
                <p class="text-sm text-base-content/60">
                  {team.team_type_name} · {team.season_year}
                </p>
                <p class="text-xs text-base-content/40">
                  {format_next_match(team.next_match_date, team.next_match_time)}
                </p>
              </div>
            </div>
          </.link>
        </div>
      <% end %>
    </Layouts.app>
    """
  end
end
