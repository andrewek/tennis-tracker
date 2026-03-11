defmodule TennisTrackerWeb.Players.ShowLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  defp create_player(attrs) do
    defaults = %{name: "Test Player", eligible_18_plus: true, eligible_40_plus: false}
    Tennis.create_player!(Map.merge(defaults, attrs))
  end

  defp create_team_type(attrs) do
    defaults = %{
      name: "18+ 4.0",
      age_group: "18_plus",
      ntrp_level: Decimal.new("4.0"),
      allowed_ntrp_levels: [Decimal.new("3.5"), Decimal.new("4.0")]
    }

    Tennis.create_team_type!(Map.merge(defaults, attrs))
  end

  defp create_team(team_type, attrs) do
    defaults = %{name: "Team Alpha", season_year: 2026, team_type_id: team_type.id}
    Tennis.create_team!(Map.merge(defaults, attrs))
  end

  defp assign_player(player, team, team_type) do
    {:ok, _} = Tennis.assign_player(player.id, team.id, team_type.id, team.season_year)
  end

  describe "team memberships section" do
    test "shows no memberships message when player has none", %{conn: conn} do
      player = create_player(%{name: "Solo Player"})
      {:ok, _view, html} = live(conn, ~p"/players/#{player.id}")

      assert html =~ "No team memberships"
    end

    test "shows a real team membership", %{conn: conn} do
      player = create_player(%{name: "Active Player"})
      tt = create_team_type(%{name: "18+ 4.0"})
      team = create_team(tt, %{name: "Team Alpha", season_year: 2026})
      assign_player(player, team, tt)

      {:ok, _view, html} = live(conn, ~p"/players/#{player.id}")

      assert html =~ "2026"
      assert html =~ "18+ 4.0"
      assert html =~ "Team Alpha"
    end

    test "does not show pseudo team memberships", %{conn: conn} do
      player = create_player(%{name: "Bench Player", eligible_18_plus: true})
      tt = create_team_type(%{name: "18+ 4.0"})
      {:ok, pseudo_team} = Tennis.ensure_pseudo_team(tt.id, 2026)
      {:ok, _} = Tennis.assign_player(player.id, pseudo_team.id, tt.id, 2026)

      {:ok, _view, html} = live(conn, ~p"/players/#{player.id}")

      assert html =~ "No team memberships"
    end

    test "shows memberships across multiple seasons, newest first", %{conn: conn} do
      player = create_player(%{name: "Veteran Player"})
      tt = create_team_type(%{name: "18+ 4.0"})
      team_2024 = create_team(tt, %{name: "Old Team", season_year: 2024})
      team_2026 = create_team(tt, %{name: "New Team", season_year: 2026})
      assign_player(player, team_2026, tt)
      {:ok, _} = Tennis.assign_player(player.id, team_2024.id, tt.id, 2024)

      {:ok, _view, html} = live(conn, ~p"/players/#{player.id}")

      pos_2026 = :binary.match(html, "New Team") |> elem(0)
      pos_2024 = :binary.match(html, "Old Team") |> elem(0)

      assert pos_2026 < pos_2024
    end
  end
end
