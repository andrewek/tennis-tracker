defmodule TennisTrackerWeb.Teams.ShowLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  defp create_team_type(attrs) do
    defaults = %{
      name: "18+ 3.5",
      age_group: "18_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    }

    Tennis.create_team_type!(Map.merge(defaults, attrs))
  end

  defp create_team(team_type, attrs) do
    defaults = %{name: "Westroads 3.5", season_year: 2025, team_type_id: team_type.id}
    Tennis.create_team!(Map.merge(defaults, attrs))
  end

  defp create_player(attrs) do
    defaults = %{name: "Alice Smith", eligible_18_plus: true, eligible_40_plus: false}
    Tennis.create_player!(Map.merge(defaults, attrs))
  end

  describe "team with players" do
    test "renders team name and player names", %{conn: conn} do
      tt = create_team_type(%{})
      team = create_team(tt, %{name: "Westroads 3.5"})
      player_a = create_player(%{name: "Alice Smith"})
      player_b = create_player(%{name: "Beth Jones"})
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
      tt = create_team_type(%{})
      {:ok, pseudo_team} = Tennis.ensure_pseudo_team(tt.id, 2025)

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
