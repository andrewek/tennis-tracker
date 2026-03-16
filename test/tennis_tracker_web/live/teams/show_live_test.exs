defmodule TennisTrackerWeb.Teams.ShowLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  describe "team with players" do
    test "renders team name and player names", %{conn: conn} do
      tt = Factory.team_type()
      team = Factory.team(team_type: tt, name: "Westroads 3.5")
      player_a = Factory.player(name: "Alice Smith")
      player_b = Factory.player(name: "Beth Jones")
      Tennis.assign_player(player_a.id, team.id, tt.id, team.season_year)
      Tennis.assign_player(player_b.id, team.id, tt.id, team.season_year)

      {:ok, _view, html} = live(conn, ~p"/teams/#{team.id}")

      assert html =~ "Westroads 3.5"
      assert html =~ "Alice Smith"
      assert html =~ "Beth Jones"
    end
  end

  describe "team with matches" do
    test "renders upcoming and past matches in separate sections", %{conn: conn} do
      team = Factory.team()
      today = Date.utc_today()
      location = Factory.location(name: "Test Court")

      Factory.match(team: team, opponent: "Past Opponent", match_date: Date.add(today, -3), home_or_away: :away)
      Factory.match(team: team, opponent: "Future Opponent", match_date: Date.add(today, 5), location: location, home_or_away: :home)

      {:ok, _view, html} = live(conn, ~p"/teams/#{team.id}")

      assert html =~ "Upcoming Matches"
      assert html =~ "Past Matches"
      assert html =~ "Future Opponent"
      assert html =~ "Past Opponent"
      assert html =~ "Test Court"
    end

    test "shows empty state when no matches", %{conn: conn} do
      team = Factory.team()

      {:ok, _view, html} = live(conn, ~p"/teams/#{team.id}")

      assert html =~ "No upcoming matches scheduled"
      assert html =~ "No past matches"
    end
  end

  describe "match creation form" do
    test "submitting valid form adds match to upcoming", %{conn: conn} do
      team = Factory.team()
      today = Date.utc_today()
      future_date = Date.add(today, 10)

      {:ok, view, _html} = live(conn, ~p"/teams/#{team.id}")

      view |> element("button", "Add Match") |> render_click()

      assert has_element?(view, "form")

      view
      |> form("form", %{
        "form" => %{
          "opponent" => "New Rival",
          "home_or_away" => "home",
          "match_date" => Date.to_iso8601(future_date),
          "match_time" => "10:00"
        }
      })
      |> render_submit()

      html = render(view)
      assert html =~ "New Rival"
    end

    test "invalid form submission shows errors", %{conn: conn} do
      team = Factory.team()

      {:ok, view, _html} = live(conn, ~p"/teams/#{team.id}")

      view |> element("button", "Add Match") |> render_click()

      view
      |> form("form", %{"form" => %{"opponent" => "", "home_or_away" => ""}})
      |> render_submit()

      assert has_element?(view, "form")
    end
  end

  describe "invalid team IDs" do
    test "redirects to / with a flash error for a pseudo-team", %{conn: conn} do
      tt = Factory.team_type()
      {:ok, pseudo_team} = Tennis.ensure_pseudo_team(tt.id, Date.utc_today().year)

      {:error, {:live_redirect, %{to: "/", flash: flash}}} =
        live(conn, ~p"/teams/#{pseudo_team.id}")

      assert flash["error"] =~ "not found"
    end

    test "redirects to / with a flash error for a non-existent ID", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      {:error, {:live_redirect, %{to: "/", flash: flash}}} =
        live(conn, ~p"/teams/#{fake_id}")

      assert flash["error"] =~ "not found"
    end
  end
end
