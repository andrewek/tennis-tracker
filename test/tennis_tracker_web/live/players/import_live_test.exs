defmodule TennisTrackerWeb.Players.ImportLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis

  setup :setup_group

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "ImportLive" do
    test "renders the import form", %{conn: conn, group: grp} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players/import")
      assert has_element?(view, "h1", "Import Players")
      assert has_element?(view, "button[type='submit']", "Import")
    end

    test "successful CSV upload redirects to players index with flash", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players/import")

      csv = "name,ntrp_rating\nAlice,3.5\nBob,4.0\n"

      view
      |> file_input("#upload-form", :csv_file, [
        %{name: "players.csv", content: csv, type: "text/csv", last_modified: 1_000}
      ])
      |> render_upload("players.csv")

      render_submit(view, "import", %{})
      assert_redirected(view, ~p"/g/#{grp.slug}/players")

      assert length(Tennis.list_players!(tenant: grp.id, actor: usr)) == 2
    end

    test "unknown headers shows error and imports nothing", %{conn: conn, group: grp, user: usr} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players/import")

      csv = "name,bad_column\nAlice,value\n"

      view
      |> file_input("#upload-form", :csv_file, [
        %{name: "players.csv", content: csv, type: "text/csv", last_modified: 1_000}
      ])
      |> render_upload("players.csv")

      render_submit(view, "import", %{})

      assert has_element?(view, "#import-error", "bad_column")
      assert has_element?(view, "#import-error", "Import cancelled")
      assert Tennis.list_players!(tenant: grp.id, actor: usr) == []
    end

    test "row error shows error with line number and imports nothing", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players/import")

      csv = "name,ntrp_rating\nAlice,3.5\n,4.0\n"

      view
      |> file_input("#upload-form", :csv_file, [
        %{name: "players.csv", content: csv, type: "text/csv", last_modified: 1_000}
      ])
      |> render_upload("players.csv")

      render_submit(view, "import", %{})

      assert has_element?(view, "#import-error", "line 3")
      assert Tennis.list_players!(tenant: grp.id, actor: usr) == []
    end
  end
end
