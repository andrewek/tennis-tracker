defmodule TennisTrackerWeb.TeamCalendarControllerTest do
  use TennisTrackerWeb.ConnCase, async: true

  setup :setup_group

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "GET /g/:group_slug/teams/:team_id/calendar.ics — access control" do
    test "authenticated member can download", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/calendar; charset=utf-8"]

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="calendar.ics")
             ]
    end

    test "unauthenticated user is redirected", %{group: grp} do
      conn = build_conn()
      team = Factory.team(group: grp)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert redirected_to(conn) =~ "/sign-in"
    end

    test "authenticated user not in the group is redirected", %{group: grp} do
      other_user = Factory.user()
      conn = log_in_user(build_conn(), other_user)
      team = Factory.team(group: grp)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert redirected_to(conn) =~ "/groups"
    end

    test "invalid team_id redirects with error", %{conn: conn, group: grp} do
      fake_id = Ecto.UUID.generate()

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{fake_id}/calendar.ics")

      assert redirected_to(conn) =~ "/teams"
    end

    test "pseudo-team is rejected with redirect", %{conn: conn, group: grp} do
      pseudo = Factory.team(group: grp, traits: [:pseudo])

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{pseudo.id}/calendar.ics")

      assert redirected_to(conn) =~ "/teams"
    end
  end

  describe "GET /g/:group_slug/teams/:team_id/calendar.ics — iCal content" do
    test "SUMMARY uses short_display_label and opponent", %{conn: conn, group: grp} do
      tt = Factory.team_type(group: grp, name: "40+ 4.0")
      team = Factory.team(group: grp, team_type: tt, name: "River Hawks", season_year: 2026)
      Factory.match(group: grp, team: team, opponent: "Springfield")

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.resp_body =~ "SUMMARY:40+ 4.0 - River Hawks v. Springfield"
    end

    test "DTSTART uses TZID parameter with local time", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)

      # 2026-04-01 15:00:00 UTC = 10:00:00 America/Chicago (UTC-5 in April)
      utc_dt = ~U[2026-04-01 15:00:00Z]

      Factory.match(
        group: grp,
        team: team,
        match_start_datetime: utc_dt,
        timezone: "America/Chicago"
      )

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.resp_body =~ "DTSTART;TZID=America/Chicago:20260401T100000"
    end

    test "DTEND reflects start + duration_minutes", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      utc_dt = ~U[2026-04-01 15:00:00Z]

      Factory.match(
        group: grp,
        team: team,
        match_start_datetime: utc_dt,
        timezone: "America/Chicago",
        duration_minutes: 90
      )

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      # 15:00 UTC + 90min = 16:30 UTC = 11:30 America/Chicago
      assert conn.resp_body =~ "DTEND;TZID=America/Chicago:20260401T113000"
    end

    test "DESCRIPTION is 'Home | Venue Name' when location assigned and home", %{
      conn: conn,
      group: grp
    } do
      team = Factory.team(group: grp)
      loc = Factory.location(group: grp, name: "West Side TC")
      Factory.match(group: grp, team: team, location: loc, home_or_away: :home)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.resp_body =~ "DESCRIPTION:Home | West Side TC"
    end

    test "DESCRIPTION is 'Away | Venue Name' when location assigned and away", %{
      conn: conn,
      group: grp
    } do
      team = Factory.team(group: grp)
      loc = Factory.location(group: grp, name: "East Side Courts")
      Factory.match(group: grp, team: team, location: loc, home_or_away: :away)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.resp_body =~ "DESCRIPTION:Away | East Side Courts"
    end

    test "DESCRIPTION is 'Home' when no location assigned and home", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      Factory.match(group: grp, team: team, home_or_away: :home)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.resp_body =~ "DESCRIPTION:Home\r\n"
    end

    test "DESCRIPTION is 'Away' when no location assigned and away", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      Factory.match(group: grp, team: team, home_or_away: :away)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.resp_body =~ "DESCRIPTION:Away\r\n"
    end

    test "LOCATION includes formatted address when present", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)

      loc =
        Factory.location(
          group: grp,
          name: "West Side TC",
          street_address: "123 Main St",
          city: "Springfield",
          state: "IL",
          postal_code: "62701",
          google_maps_url: nil
        )

      Factory.match(group: grp, team: team, location: loc)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.resp_body =~
               "LOCATION:West Side TC\\n123 Main St\\, Springfield\\, IL 62701"
    end

    test "LOCATION includes ALTREP when google_maps_url is present", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)

      loc =
        Factory.location(
          group: grp,
          name: "West Side TC",
          street_address: "123 Main St",
          city: "Springfield",
          state: "IL",
          postal_code: "62701",
          google_maps_url: "https://maps.google.com/?q=test"
        )

      Factory.match(group: grp, team: team, location: loc)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.resp_body =~
               ~s(LOCATION;ALTREP="https://maps.google.com/?q=test":West Side TC\\n123 Main St\\, Springfield\\, IL 62701)
    end

    test "LOCATION is venue name only when formatted_address is nil", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)

      loc =
        Factory.location(
          group: grp,
          name: "Mystery Courts",
          street_address: nil,
          city: nil,
          state: nil,
          postal_code: nil
        )

      Factory.match(group: grp, team: team, location: loc)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.resp_body =~ "LOCATION:Mystery Courts\r\n"
      refute conn.resp_body =~ "LOCATION:Mystery Courts\\n"
    end

    test "LOCATION is omitted when no location assigned", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      Factory.match(group: grp, team: team)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      refute conn.resp_body =~ "LOCATION:"
    end

    test "UID is stable across downloads", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team)

      conn1 = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")
      conn2 = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn1.resp_body =~ "UID:match-#{match.id}@tennis-tracker"
      assert conn2.resp_body =~ "UID:match-#{match.id}@tennis-tracker"
    end

    test "includes all matches (past and upcoming)", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)

      # 3 past, 2 future
      Enum.each(1..3, fn i ->
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime:
            DateTime.utc_now() |> DateTime.add(-i * 7, :day) |> DateTime.truncate(:second)
        )
      end)

      Enum.each(1..2, fn i ->
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime:
            DateTime.utc_now() |> DateTime.add(i * 7, :day) |> DateTime.truncate(:second)
        )
      end)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      vevent_count =
        conn.resp_body
        |> String.split("BEGIN:VEVENT")
        |> length()
        |> then(&(&1 - 1))

      assert vevent_count == 5
    end

    test "empty team produces valid calendar with no VEVENTs", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)

      conn = get(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/calendar.ics")

      assert conn.resp_body =~ "BEGIN:VCALENDAR"
      assert conn.resp_body =~ "END:VCALENDAR"
      refute conn.resp_body =~ "BEGIN:VEVENT"
    end
  end
end
