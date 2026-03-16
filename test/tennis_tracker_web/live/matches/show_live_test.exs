defmodule TennisTrackerWeb.Matches.ShowLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  describe "match show page" do
    test "renders match details with location and map link", %{conn: conn} do
      team = Factory.team(name: "Westroads 3.5")
      location = Factory.location(name: "Woods Tennis Center", address: "4701 Happy Hollow Blvd", google_maps_url: "https://maps.google.com/?q=woods")
      match = Factory.match(team: team, location: location, opponent: "Rival Team", home_or_away: :home)

      {:ok, _view, html} = live(conn, ~p"/matches/#{match.id}")

      assert html =~ "Rival Team"
      assert html =~ "HOME"
      assert html =~ "Woods Tennis Center"
      assert html =~ "4701 Happy Hollow Blvd"
      assert html =~ "https://maps.google.com/?q=woods"
      assert html =~ "Directions"
    end

    test "shows Location TBD when no location set", %{conn: conn} do
      team = Factory.team()
      match = Factory.match(team: team, opponent: "Someone")

      {:ok, _view, html} = live(conn, ~p"/matches/#{match.id}")

      assert html =~ "Location TBD"
    end

    test "shows no map link when location has no google_maps_url", %{conn: conn} do
      team = Factory.team()
      location = Factory.location(google_maps_url: nil)
      match = Factory.match(team: team, location: location)

      {:ok, _view, html} = live(conn, ~p"/matches/#{match.id}")

      refute html =~ "Directions"
    end

    test "links back to team page", %{conn: conn} do
      team = Factory.team(name: "My Team")
      match = Factory.match(team: team)

      {:ok, _view, html} = live(conn, ~p"/matches/#{match.id}")

      assert html =~ "My Team"
      assert html =~ "/teams/#{team.id}"
    end

    test "redirects to / with flash on non-existent match", %{conn: conn} do
      fake_id = Ecto.UUID.generate()

      {:error, {:live_redirect, %{to: "/", flash: flash}}} =
        live(conn, ~p"/matches/#{fake_id}")

      assert flash["error"] =~ "not found"
    end
  end
end
