defmodule TennisTrackerWeb.Teams.IndexLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  defp create_team_type(attrs \\ %{}) do
    defaults = %{
      name: "18+ 3.5",
      age_group: "18_plus",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    }

    Tennis.create_team_type!(Map.merge(defaults, attrs))
  end

  defp create_team(team_type, attrs) do
    defaults = %{name: "Test Team", season_year: 2026, team_type_id: team_type.id}
    Tennis.create_team!(Map.merge(defaults, attrs))
  end

  describe "with teams" do
    test "renders each team name", %{conn: conn} do
      tt = create_team_type()
      create_team(tt, %{name: "Westroads 3.5"})
      create_team(tt, %{name: "Miracle Hills 3.5"})

      {:ok, _view, html} = live(conn, ~p"/teams")

      assert html =~ "Westroads 3.5"
      assert html =~ "Miracle Hills 3.5"
    end

    test "does not render pseudo-teams", %{conn: conn} do
      tt = create_team_type()
      create_team(tt, %{name: "Real Team"})

      _pseudo =
        Tennis.create_team!(%{
          name: "Not Participating",
          team_type_id: tt.id,
          season_year: 2026,
          is_pseudo: true
        })

      {:ok, _view, html} = live(conn, ~p"/teams")

      assert html =~ "Real Team"
      refute html =~ "Not Participating"
    end
  end

  describe "empty state" do
    test "shows empty state when no teams exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/teams")

      assert html =~ "No teams yet"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users", %{conn: _conn} do
      conn = Phoenix.ConnTest.build_conn()
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/teams")
      assert path =~ "/sign-in"
    end
  end
end
