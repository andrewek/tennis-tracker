defmodule TennisTrackerWeb.Teams.EditLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "page load" do
    test "loads pre-populated with team name and timezone", %{conn: conn, group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      team = Factory.team(group: grp, team_type: tt, name: "Westroads 3.5")
      Tennis.update_team!(team, %{default_timezone: "America/Denver"}, tenant: grp.id, actor: usr)

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      assert html =~ "Westroads 3.5"
      assert html =~ "America/Denver"
    end
  end

  describe "team settings form" do
    test "valid name + timezone update saves and shows flash", %{conn: conn, group: grp} do
      team = Factory.team(group: grp, name: "Old Name")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view
      |> form("form[phx-submit='save_team']", %{
        "team_form" => %{
          "name" => "New Name",
          "default_timezone" => "America/Los_Angeles"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "New Name"
      assert html =~ "Team updated"
    end

    test "blank name shows validation error and does not save", %{conn: conn, group: grp} do
      team = Factory.team(group: grp, name: "My Team")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view
      |> form("form[phx-submit='save_team']", %{
        "team_form" => %{"name" => "", "default_timezone" => "America/Chicago"}
      })
      |> render_submit()

      html = render(view)
      refute html =~ "Team updated"
      assert has_element?(view, "form")
    end
  end

  describe "invalid team IDs" do
    test "pseudo-team ID redirects to / with flash", %{conn: conn, group: grp, user: usr} do
      tt = Factory.team_type(group: grp)

      {:ok, pseudo_team} =
        Tennis.ensure_pseudo_team(tt.id, Date.utc_today().year, tenant: grp.id, actor: usr)

      {:error, {:live_redirect, %{to: _to, flash: flash}}} =
        live(conn, ~p"/g/#{grp.slug}/teams/#{pseudo_team.id}/edit")

      assert flash["error"] =~ "not found"
    end

    test "non-existent team ID redirects to / with flash", %{conn: conn, group: grp} do
      fake_id = Ecto.UUID.generate()

      {:error, {:live_redirect, %{to: _to, flash: flash}}} =
        live(conn, ~p"/g/#{grp.slug}/teams/#{fake_id}/edit")

      assert flash["error"] =~ "not found"
    end
  end

  describe "add match via modal" do
    test "adding a match via modal appears in upcoming list with flash", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      today = Date.utc_today()
      future_date = Date.add(today, 10)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")

      view |> element("button", "Add Match") |> render_click()

      assert has_element?(view, "form[phx-submit='save_match']")

      view
      |> form("form[phx-submit='save_match']", %{
        "match_form" => %{
          "opponent" => "New Rival",
          "home_or_away" => "home",
          "match_date" => Date.to_iso8601(future_date),
          "match_time" => "10:00"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "New Rival"
      assert html =~ "Match added"
    end
  end

  describe "delete match" do
    test "deleting a match removes it from the list and shows flash", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      now = DateTime.utc_now()

      match =
        Factory.match(
          group: grp,
          team: team,
          opponent: "To Delete",
          match_start_datetime: DateTime.add(now, 7, :day) |> DateTime.truncate(:second)
        )

      {:ok, view, html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}/edit")
      assert html =~ "To Delete"

      view
      |> element("button[phx-value-match_id='#{match.id}']")
      |> render_click()

      view |> element("button[phx-click='delete_match']") |> render_click()

      html = render(view)
      refute html =~ "To Delete"
      assert html =~ "Match deleted"
    end
  end
end
