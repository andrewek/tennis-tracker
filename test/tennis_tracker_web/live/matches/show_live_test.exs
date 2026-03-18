defmodule TennisTrackerWeb.Matches.ShowLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :setup_group_with_owner

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "match show page" do
    test "renders match details with location and map link", %{conn: conn, group: grp} do
      team = Factory.team(group: grp, name: "Westroads 3.5")

      location =
        Factory.location(
          group: grp,
          name: "Woods Tennis Center",
          address: "4701 Happy Hollow Blvd",
          google_maps_url: "https://maps.google.com/?q=woods"
        )

      match =
        Factory.match(
          group: grp,
          team: team,
          location: location,
          opponent: "Rival Team",
          home_or_away: :home
        )

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert html =~ "Rival Team"
      assert html =~ "HOME"
      assert html =~ "Woods Tennis Center"
      assert html =~ "4701 Happy Hollow Blvd"
      assert html =~ "https://maps.google.com/?q=woods"
      assert html =~ "Directions"
    end

    test "shows Location TBD when no location set", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team, opponent: "Someone")

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert html =~ "Location TBD"
    end

    test "shows no map link when location has no google_maps_url", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      location = Factory.location(group: grp, google_maps_url: nil)
      match = Factory.match(group: grp, team: team, location: location)

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}")

      refute html =~ "Directions"
    end

    test "links back to team page", %{conn: conn, group: grp} do
      team = Factory.team(group: grp, name: "My Team")
      match = Factory.match(group: grp, team: team)

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert html =~ "My Team"
      assert html =~ "/g/#{grp.slug}/teams/#{team.id}"
    end

    test "redirects to group teams with flash on non-existent match", %{conn: conn, group: grp} do
      fake_id = Ecto.UUID.generate()

      {:error, {:live_redirect, %{to: to, flash: flash}}} =
        live(conn, ~p"/g/#{grp.slug}/matches/#{fake_id}")

      assert flash["error"] =~ "not found"
      assert to =~ "/g/#{grp.slug}/teams"
    end
  end
end
