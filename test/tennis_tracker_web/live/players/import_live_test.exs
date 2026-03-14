defmodule TennisTrackerWeb.Players.ImportLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  alias TennisTracker.Tennis

  describe "ImportLive" do
    test "renders the import form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/players/import")
      assert html =~ "Import Players"
      assert html =~ "Import"
    end

    test "successful CSV upload redirects to players index with flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/players/import")

      csv = "name,ntrp_rating\nAlice,3.5\nBob,4.0\n"

      view
      |> file_input("#upload-form", :csv_file, [
        %{name: "players.csv", content: csv, type: "text/csv", last_modified: 1_000}
      ])
      |> render_upload("players.csv")

      render_submit(view, "import", %{})
      assert_redirected(view, ~p"/players")

      assert length(Tennis.list_players!()) == 2
    end

    test "unknown headers shows error and imports nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/players/import")

      csv = "name,bad_column\nAlice,value\n"

      view
      |> file_input("#upload-form", :csv_file, [
        %{name: "players.csv", content: csv, type: "text/csv", last_modified: 1_000}
      ])
      |> render_upload("players.csv")

      html = render_submit(view, "import", %{})

      assert html =~ "bad_column"
      assert html =~ "Import cancelled"
      assert Tennis.list_players!() == []
    end

    test "row error shows error with line number and imports nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/players/import")

      csv = "name,ntrp_rating\nAlice,3.5\n,4.0\n"

      view
      |> file_input("#upload-form", :csv_file, [
        %{name: "players.csv", content: csv, type: "text/csv", last_modified: 1_000}
      ])
      |> render_upload("players.csv")

      html = render_submit(view, "import", %{})

      assert html =~ "line 3"
      assert Tennis.list_players!() == []
    end
  end
end
