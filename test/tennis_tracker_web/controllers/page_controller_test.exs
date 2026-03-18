defmodule TennisTrackerWeb.PageControllerTest do
  use TennisTrackerWeb.ConnCase

  test "GET / redirects unauthenticated users to sign-in", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/sign-in"
  end

  test "GET / redirects authenticated users to /groups", %{conn: conn} do
    conn = log_in_user(conn)
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/groups"
  end
end
