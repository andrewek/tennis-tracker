defmodule TennisTrackerWeb.PageControllerTest do
  use TennisTrackerWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Tennis Tracker"
  end

  test "home page shows Roster Planner card linking to /roster-planner", %{conn: conn} do
    conn = get(conn, ~p"/")
    body = html_response(conn, 200)
    assert body =~ "Roster Planner"
    assert body =~ "/roster-planner"
  end
end
