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
