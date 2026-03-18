defmodule TennisTrackerWeb.Matches.EditLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :setup_group_with_owner

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "page load" do
    test "loads pre-populated with match fields", %{conn: conn, group: grp} do
      team = Factory.team(group: grp, name: "My Team")
      location = Factory.location(group: grp, name: "City Courts")
      now = DateTime.utc_now()

      match =
        Factory.match(
          group: grp,
          team: team,
          location: location,
          opponent: "Rival Club",
          home_or_away: :home,
          match_start_datetime: DateTime.add(now, 7, :day) |> DateTime.truncate(:second),
          timezone: "America/Chicago"
        )

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}/edit")

      assert html =~ "Rival Club"
      assert html =~ "My Team"
    end

    test "non-existent match ID redirects to group teams with flash", %{conn: conn, group: grp} do
      fake_id = Ecto.UUID.generate()

      {:error, {:live_redirect, %{to: to, flash: flash}}} =
        live(conn, ~p"/g/#{grp.slug}/matches/#{fake_id}/edit")

      assert flash["error"] =~ "not found"
      assert to =~ "/g/#{grp.slug}/teams"
    end
  end

  describe "edit match" do
    test "valid update redirects to /g/:slug/teams/:id/edit with flash", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      now = DateTime.utc_now()
      future_date = Date.utc_today() |> Date.add(14)

      match =
        Factory.match(
          group: grp,
          team: team,
          opponent: "Old Rival",
          match_start_datetime: DateTime.add(now, 7, :day) |> DateTime.truncate(:second)
        )

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}/edit")

      view
      |> form("form", %{
        "form" => %{
          "opponent" => "Updated Rival",
          "home_or_away" => "away",
          "match_date" => Date.to_iso8601(future_date),
          "match_time" => "14:00"
        }
      })
      |> render_submit()

      assert_redirect(view, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")
    end

    test "invalid update (blank opponent) shows validation error", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      now = DateTime.utc_now()

      match =
        Factory.match(
          group: grp,
          team: team,
          opponent: "Rival",
          match_start_datetime: DateTime.add(now, 7, :day) |> DateTime.truncate(:second)
        )

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}/edit")

      view
      |> form("form", %{
        "form" => %{
          "opponent" => "",
          "home_or_away" => "home",
          "match_date" => Date.to_iso8601(Date.add(Date.utc_today(), 7)),
          "match_time" => "10:00"
        }
      })
      |> render_submit()

      assert has_element?(view, "form")
    end
  end

  describe "delete match" do
    test "delete redirects to /g/:slug/teams/:id/edit with flash", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      now = DateTime.utc_now()

      match =
        Factory.match(
          group: grp,
          team: team,
          opponent: "Doomed Rival",
          match_start_datetime: DateTime.add(now, 7, :day) |> DateTime.truncate(:second)
        )

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}/edit")

      view |> element("button[phx-click='show_delete_modal']") |> render_click()
      view |> element("button[phx-click='delete_match']") |> render_click()

      assert_redirect(view, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")
    end
  end
end
