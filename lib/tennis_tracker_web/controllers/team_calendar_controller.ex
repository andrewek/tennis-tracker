defmodule TennisTrackerWeb.TeamCalendarController do
  use TennisTrackerWeb, :controller

  alias TennisTracker.Tennis

  def export(conn, %{"group_slug" => group_slug, "team_id" => team_id}) do
    current_user = conn.assigns.current_user
    group = conn.assigns.current_group

    with {:ok, team} <- load_team(team_id, group, current_user),
         {:ok, matches} <- load_matches(team_id, group, current_user) do
      ical = build_ical(team, matches)

      conn
      |> put_resp_content_type("text/calendar")
      |> put_resp_header("content-disposition", ~s(attachment; filename="calendar.ics"))
      |> send_resp(200, ical)
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Team not found.")
        |> redirect(to: ~p"/g/#{group_slug}/teams")

      {:error, :pseudo_team} ->
        conn
        |> put_flash(:error, "Team not found.")
        |> redirect(to: ~p"/g/#{group_slug}/teams")

      _ ->
        conn
        |> put_flash(:error, "Something went wrong.")
        |> redirect(to: ~p"/g/#{group_slug}/teams")
    end
  end

  defp load_team(team_id, group, current_user) do
    team =
      Tennis.get_team!(team_id,
        tenant: group.id,
        actor: current_user,
        load: [:display_label, :short_display_label]
      )

    if team.is_pseudo do
      {:error, :pseudo_team}
    else
      {:ok, team}
    end
  rescue
    _ -> {:error, :not_found}
  end

  defp load_matches(team_id, group, current_user) do
    matches =
      Tennis.list_all_matches_for_team!(team_id,
        tenant: group.id,
        actor: current_user,
        load: [location: [:formatted_address]]
      )

    {:ok, matches}
  rescue
    _ -> {:error, :load_failed}
  end

  defp build_ical(team, matches) do
    now_stamp = format_dtstamp(DateTime.utc_now())

    header = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//TennisTracker//EN",
      "X-WR-CALNAME:#{team.display_label}",
      "CALSCALE:GREGORIAN"
    ]

    events = Enum.flat_map(matches, &build_vevent_lines(&1, team, now_stamp))

    (header ++ events ++ ["END:VCALENDAR"])
    |> Enum.join("\r\n")
    |> then(&(&1 <> "\r\n"))
  end

  defp build_vevent_lines(match, team, dtstamp) do
    uid = "match-#{match.id}@tennis-tracker"
    summary = "#{team.short_display_label} v. #{match.opponent}"
    description = build_description(match)
    dtstart = format_local_datetime(match.match_start_datetime, match.timezone)

    dtend =
      match.match_start_datetime
      |> DateTime.add(match.duration_minutes * 60, :second)
      |> format_local_datetime(match.timezone)

    lines = [
      "BEGIN:VEVENT",
      "UID:#{uid}",
      "DTSTAMP:#{dtstamp}",
      "DTSTART;TZID=#{match.timezone}:#{dtstart}",
      "DTEND;TZID=#{match.timezone}:#{dtend}",
      "SUMMARY:#{summary}",
      "DESCRIPTION:#{description}"
    ]

    location_line = build_location_line(match)

    if location_line do
      lines ++ [location_line, "END:VEVENT"]
    else
      lines ++ ["END:VEVENT"]
    end
  end

  defp build_description(match) do
    home_away = if match.home_or_away == :home, do: "Home", else: "Away"

    case match.location do
      nil -> home_away
      location -> "#{home_away} | #{location.name}"
    end
  end

  defp build_location_line(match) do
    case match.location do
      nil ->
        nil

      location ->
        text =
          case location.formatted_address do
            nil ->
              location.name

            addr ->
              escaped_addr = String.replace(addr, ",", "\\,")
              "#{location.name}\\n#{escaped_addr}"
          end

        case location.google_maps_url do
          nil -> "LOCATION:#{text}"
          url -> ~s(LOCATION;ALTREP="#{url}":#{text})
        end
    end
  end

  defp format_dtstamp(dt) do
    Calendar.strftime(dt, "%Y%m%dT%H%M%SZ")
  end

  defp format_local_datetime(utc_dt, timezone) do
    local_dt = DateTime.shift_zone!(utc_dt, timezone, Tzdata.TimeZoneDatabase)
    Calendar.strftime(local_dt, "%Y%m%dT%H%M%S")
  end
end
