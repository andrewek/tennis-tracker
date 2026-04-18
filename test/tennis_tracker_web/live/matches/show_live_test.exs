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
          street_address: "4701 Happy Hollow Blvd",
          city: "Omaha",
          state: "NE",
          postal_code: "68132",
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

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "h1", "Rival Team")
      assert has_element?(view, "h1", "HOME")
      assert has_element?(view, "p", "Woods Tennis Center")
      assert has_element?(view, "p", "4701 Happy Hollow Blvd")
      assert has_element?(view, "a[href='https://maps.google.com/?q=woods']")
      assert has_element?(view, "a", "Directions")
    end

    test "shows Location TBD when no location set", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      match = Factory.match(group: grp, team: team, opponent: "Someone")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "p", "Location TBD")
    end

    test "shows no map link when location has no google_maps_url", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      location = Factory.location(group: grp, google_maps_url: nil)
      match = Factory.match(group: grp, team: team, location: location)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}")

      refute has_element?(view, "a", "Directions")
    end

    test "links back to team page", %{conn: conn, group: grp} do
      team = Factory.team(group: grp, name: "My Team")
      match = Factory.match(group: grp, team: team)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/matches/#{match.id}")

      assert has_element?(view, "a", "My Team")
      assert has_element?(view, "a[href='/g/#{grp.slug}/teams/#{team.id}']")
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
