defmodule TennisTrackerWeb.Teams.ShowLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "team with players" do
    test "renders team name and player names", %{conn: conn, group: grp, user: usr} do
      tt = Factory.team_type(group: grp)
      team = Factory.team(group: grp, team_type: tt, name: "Westroads 3.5")
      player_a = Factory.player(group: grp, name: "Alice Smith")
      player_b = Factory.player(group: grp, name: "Beth Jones")

      Tennis.assign_player(player_a.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      Tennis.assign_player(player_b.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}")

      assert has_element?(view, "h1", "Westroads 3.5")
      assert has_element?(view, "#player-#{player_a.id}")
      assert has_element?(view, "#player-#{player_b.id}")
    end
  end

  describe "team with matches" do
    test "renders upcoming and past matches in separate sections", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)
      now = DateTime.utc_now()
      location = Factory.location(group: grp, name: "Test Court")

      Factory.match(
        group: grp,
        team: team,
        opponent: "Past Opponent",
        match_start_datetime: DateTime.add(now, -3, :day) |> DateTime.truncate(:second),
        home_or_away: :away
      )

      Factory.match(
        group: grp,
        team: team,
        opponent: "Future Opponent",
        match_start_datetime: DateTime.add(now, 5, :day) |> DateTime.truncate(:second),
        location: location,
        home_or_away: :home
      )

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}")

      assert has_element?(view, "h2", "Upcoming Matches")
      assert has_element?(view, "h2", "Past Matches")
      assert has_element?(view, "#upcoming-matches", "Future Opponent")
      assert has_element?(view, "#past-matches", "Past Opponent")
      assert has_element?(view, "#upcoming-matches", "Test Court")
    end

    test "shows empty state when no matches", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}")

      assert has_element?(view, "p", "No upcoming matches scheduled")
      assert has_element?(view, "p", "No past matches")
    end
  end

  describe "edit team link and read-only state" do
    test "shows Edit Team link and no Add Match button", %{conn: conn, group: grp} do
      team = Factory.team(group: grp)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/teams/#{team.id}")

      assert has_element?(view, "a", "Team Settings")
      refute has_element?(view, "a", "Add Match")
    end
  end

  describe "invalid team IDs" do
    test "redirects to / with a flash error for a pseudo-team", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      tt = Factory.team_type(group: grp)

      {:ok, pseudo_team} =
        Tennis.ensure_pseudo_team(tt.id, Date.utc_today().year, tenant: grp.id, actor: usr)

      {:error, {:live_redirect, %{to: _to, flash: flash}}} =
        live(conn, ~p"/g/#{grp.slug}/teams/#{pseudo_team.id}")

      assert flash["error"] =~ "not found"
    end

    test "redirects to / with a flash error for a non-existent ID", %{conn: conn, group: grp} do
      fake_id = Ecto.UUID.generate()

      {:error, {:live_redirect, %{to: _to, flash: flash}}} =
        live(conn, ~p"/g/#{grp.slug}/teams/#{fake_id}")

      assert flash["error"] =~ "not found"
    end
  end
end
