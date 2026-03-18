defmodule TennisTrackerWeb.Teams.IndexLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest


  setup :setup_group_with_owner

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "next match on team card" do
    test "shows formatted date and time when team has an upcoming match", %{
      conn: conn,
      group: grp
    } do
      team = Factory.team(group: grp, name: "Schedule Team")

      Factory.match(
        group: grp,
        team: team,
        match_start_datetime:
          DateTime.utc_now() |> DateTime.add(5, :day) |> DateTime.truncate(:second)
      )

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/teams")

      refute html =~ "Next match: TBD"
      assert html =~ "Next match:"
    end

    test "shows TBD when team has no upcoming matches", %{conn: conn, group: grp} do
      Factory.team(group: grp, name: "No Schedule Team")

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/teams")

      assert html =~ "Next match: TBD"
    end
  end

  describe "with teams" do
    test "renders each team name", %{conn: conn, group: grp, user: _usr} do
      tt = Factory.team_type(group: grp)
      Factory.team(group: grp, team_type: tt, name: "Westroads 3.5")
      Factory.team(group: grp, team_type: tt, name: "Miracle Hills 3.5")

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/teams")

      assert html =~ "Westroads 3.5"
      assert html =~ "Miracle Hills 3.5"
    end

    test "does not render pseudo-teams", %{conn: conn, group: grp, user: _usr} do
      tt = Factory.team_type(group: grp)
      Factory.team(group: grp, team_type: tt, name: "Real Team")
      Factory.team(group: grp, team_type: tt, name: "Not Participating", traits: [:pseudo])

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/teams")

      assert html =~ "Real Team"
      refute html =~ "Not Participating"
    end
  end

  describe "empty state" do
    test "shows empty state when no teams exist", %{conn: conn, group: grp} do
      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/teams")

      assert html =~ "No teams yet"
    end
  end

  describe "authentication" do
    test "redirects unauthenticated users", %{group: grp} do
      conn = Phoenix.ConnTest.build_conn()
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/g/#{grp.slug}/teams")
      assert path =~ "/sign-in"
    end
  end
end
