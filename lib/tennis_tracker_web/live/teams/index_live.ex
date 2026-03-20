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
    group_id = socket.assigns.current_group_id
    current_user = socket.assigns.current_user

    teams =
      Tennis.list_real_teams!(
        tenant: group_id,
        actor: current_user,
        load: [:team_type_name, :next_match_start_datetime, :default_timezone]
      )

    socket
    |> assign(:team_count, length(teams))
    |> stream(:teams, teams, reset: true)
    |> noreply()
  end

  defp format_next_match(nil, _timezone), do: "Next match: TBD"

  defp format_next_match(%DateTime{} = utc_dt, timezone) do
    tz = timezone || "America/Chicago"
    local = DateTime.shift_zone!(utc_dt, tz)
    date_str = Calendar.strftime(local, "%a, %b %-d")
    time_str = format_time(local)
    "Next match: #{date_str} · #{time_str}"
  end

  defp format_time(%DateTime{hour: h, minute: m}) do
    {hour, ampm} =
      if h >= 12,
        do: {rem(h, 12) |> then(&if(&1 == 0, do: 12, else: &1)), "PM"},
        else: {if(h == 0, do: 12, else: h), "AM"}

    "#{hour}:#{m |> Integer.to_string() |> String.pad_leading(2, "0")} #{ampm}"
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_group={@current_group}>
      <.page_header title="Teams" />

      <%= if @team_count == 0 do %>
        <div class="mt-12 text-center">
          <p class="text-xl font-semibold">No teams yet</p>
          <p class="mt-2 text-base-content/60">Teams will appear here once they've been added.</p>
        </div>
      <% else %>
        <div
          id="teams-grid"
          phx-update="stream"
          class="mt-6 grid grid-cols-1 gap-6 sm:grid-cols-2 xl:grid-cols-3"
        >
          <.link
            :for={{dom_id, team} <- @streams.teams}
            id={dom_id}
            navigate={~p"/g/#{@current_group.slug}/teams/#{team}"}
            class="group"
          >
            <div class="card bg-base-200 transition-all group-hover:bg-base-300 group-hover:scale-105 group-hover:shadow-lg">
              <div class="card-body gap-2">
                <h2 class="card-title block truncate">{team.name}</h2>
                <p class="text-sm text-base-content/60">
                  {team.team_type_name} · {team.season_year}
                </p>
                <p class="text-xs text-base-content/40">
                  {format_next_match(team.next_match_start_datetime, team.default_timezone)}
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
