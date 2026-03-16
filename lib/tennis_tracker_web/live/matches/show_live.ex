defmodule TennisTrackerWeb.Matches.ShowLive do
  use TennisTrackerWeb, :live_view

  alias TennisTracker.Tennis

  def mount(_params, _session, socket) do
    socket
    |> assign(:match, nil)
    |> ok()
  end

  def handle_params(%{"id" => id}, _url, socket) do
    case Ash.get(Tennis.Match, id, domain: Tennis) do
      {:ok, match} ->
        case Ash.load(match, [:team, :location], domain: Tennis) do
          {:ok, match} ->
            socket |> assign(:match, match) |> noreply()

          {:error, _} ->
            socket
            |> put_flash(:error, "Match not found.")
            |> push_navigate(to: ~p"/")
            |> noreply()
        end

      {:error, _} ->
        socket
        |> put_flash(:error, "Match not found.")
        |> push_navigate(to: ~p"/")
        |> noreply()
    end
  end

  defp format_match_datetime(%DateTime{} = utc_dt, timezone) do
    tz = timezone || "America/Chicago"
    local = DateTime.shift_zone!(utc_dt, tz)
    date_str = Calendar.strftime(local, "%A, %B %-d, %Y")

    %DateTime{hour: h, minute: m} = local

    {hour, ampm} =
      if h >= 12,
        do: {rem(h, 12) |> then(&if(&1 == 0, do: 12, else: &1)), "PM"},
        else: {if(h == 0, do: 12, else: h), "AM"}

    minute_str = m |> Integer.to_string() |> String.pad_leading(2, "0")
    time_str = "#{hour}:#{minute_str} #{ampm}"
    {date_str, time_str}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mb-6">
        <.link
          navigate={~p"/teams/#{@match.team.id}"}
          class="text-sm text-base-content/70 hover:text-base-content"
        >
          <.icon name="hero-arrow-left" class="size-4 inline" />
          Back to <span class="font-medium">{@match.team.name}</span>
        </.link>
      </div>

      <div class="max-w-lg">
        <h1 class="text-3xl font-bold tracking-tight mb-1">
          <%= if @match.home_or_away == :home do %>
            HOME vs. {@match.opponent}
          <% else %>
            AWAY vs. {@match.opponent}
          <% end %>
        </h1>
        <p class="text-base-content/60 mb-6">
          <.link navigate={~p"/teams/#{@match.team.id}"} class="hover:underline">
            {@match.team.name}
          </.link>
        </p>

        <div class="bg-base-200 rounded-lg p-5 space-y-4">
          <div>
            <p class="text-xs text-base-content/50 uppercase tracking-wide mb-1">Date & Time</p>
            <% {date_str, time_str} =
              format_match_datetime(@match.match_start_datetime, @match.timezone) %>
            <p class="font-medium">{date_str}</p>
            <p class="text-base-content/70">
              {time_str} ({@match.timezone})
            </p>
          </div>

          <div>
            <p class="text-xs text-base-content/50 uppercase tracking-wide mb-1">Location</p>
            <%= if @match.location do %>
              <p class="font-medium">{@match.location.name}</p>
              <p class="text-base-content/70">{@match.location.address}</p>
              <a
                :if={@match.location.google_maps_url}
                href={@match.location.google_maps_url}
                target="_blank"
                rel="noopener noreferrer"
                class="text-sm text-primary hover:underline inline-flex items-center gap-1 mt-1"
              >
                <.icon name="hero-map-pin" class="size-3" /> Directions
              </a>
            <% else %>
              <p class="text-base-content/50">Location TBD</p>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
