defmodule TennisTrackerWeb.PageControllerTest do
  use TennisTrackerWeb.ConnCase

  test "GET / redirects unauthenticated users to sign-in", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/sign-in"
  end

  test "GET / renders home page for authenticated users", %{conn: conn} do
    conn = log_in_user(conn)
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Tennis Tracker"
  end

  test "home page shows Roster Planner card linking to /roster-planner", %{conn: conn} do
    conn = log_in_user(conn)
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Roster Planner"
    assert body =~ "/roster-planner"
  end

  test "home page Teams card links to /teams", %{conn: conn} do
    conn = log_in_user(conn)
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Teams"
    assert body =~ ~p"/teams"
  end
end
