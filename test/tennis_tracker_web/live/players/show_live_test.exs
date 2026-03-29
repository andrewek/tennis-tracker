defmodule TennisTrackerWeb.Players.ShowLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "team memberships section" do
    test "shows no memberships message when player has none", %{
      conn: conn,
      group: grp,
      user: _usr
    } do
      player = Factory.player(group: grp, name: "Solo Player")
      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/players/#{player.id}")

      assert html =~ "No team memberships"
    end

    test "shows a real team membership", %{conn: conn, group: grp, user: usr} do
      player = Factory.player(group: grp, name: "Active Player")
      tt = Factory.team_type(group: grp, name: "18+ 4.0")
      team = Factory.team(group: grp, team_type: tt, name: "Team Alpha", season_year: 2026)

      Tennis.assign_player(player.id, team.id, tt.id, team.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/players/#{player.id}")

      assert html =~ "2026"
      assert html =~ "18+ 4.0"
      assert html =~ "Team Alpha"
    end

    test "does not show pseudo team memberships", %{conn: conn, group: grp, user: usr} do
      player = Factory.player(group: grp, name: "Bench Player")
      tt = Factory.team_type(group: grp, name: "18+ 4.0")
      {:ok, pseudo_team} = Tennis.ensure_pseudo_team(tt.id, 2026, tenant: grp.id, actor: usr)

      {:ok, _} =
        Tennis.assign_player(player.id, pseudo_team.id, tt.id, 2026, tenant: grp.id, actor: usr)

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/players/#{player.id}")

      assert html =~ "No team memberships"
    end

    test "shows memberships across multiple seasons, newest first", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      player = Factory.player(group: grp, name: "Veteran Player")
      tt = Factory.team_type(group: grp, name: "18+ 4.0")
      team_2024 = Factory.team(group: grp, team_type: tt, name: "Old Team", season_year: 2024)
      team_2026 = Factory.team(group: grp, team_type: tt, name: "New Team", season_year: 2026)

      Tennis.assign_player(player.id, team_2026.id, tt.id, team_2026.season_year,
        tenant: grp.id,
        actor: usr
      )

      {:ok, _} =
        Tennis.assign_player(player.id, team_2024.id, tt.id, 2024, tenant: grp.id, actor: usr)

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/players/#{player.id}")

      pos_2026 = :binary.match(html, "New Team") |> elem(0)
      pos_2024 = :binary.match(html, "Old Team") |> elem(0)

      assert pos_2026 < pos_2024
    end
  end
end
