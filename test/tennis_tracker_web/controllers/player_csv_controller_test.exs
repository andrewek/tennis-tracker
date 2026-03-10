defmodule TennisTrackerWeb.PlayerCSVControllerTest do
  use TennisTrackerWeb.ConnCase, async: true

  alias TennisTracker.Tennis

  defp create_player(attrs) do
    defaults = %{
      name: "Player",
      eligible_18_plus: true,
      eligible_40_plus: false,
      eligible_55_plus: false
    }

    Tennis.create_player!(Map.merge(defaults, attrs))
  end

  defp parse_csv(body) do
    [header | rows] = String.split(String.trim(body), "\n")
    headers = String.split(header, ",")

    Enum.map(rows, fn row ->
      row
      |> String.split(",")
      |> then(&Enum.zip(headers, &1))
      |> Map.new()
    end)
  end

  describe "GET /players/export.csv" do
    test "returns correct content-type and content-disposition headers", %{conn: conn} do
      conn = get(conn, ~p"/players/export.csv")

      assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="players.csv")
             ]
    end

    test "returns header row with correct columns", %{conn: conn} do
      conn = get(conn, ~p"/players/export.csv")

      [header_line | _] = String.split(conn.resp_body, "\n")

      assert header_line ==
               "name,ntrp_rating,email,phone_number,eligible_18_plus,eligible_40_plus,eligible_55_plus"
    end

    test "returns all players when no filters", %{conn: conn} do
      create_player(%{name: "Alice", ntrp_rating: "3.5"})
      create_player(%{name: "Bob", ntrp_rating: "4.0"})

      conn = get(conn, ~p"/players/export.csv")
      rows = parse_csv(conn.resp_body)
      names = Enum.map(rows, & &1["name"])

      assert "Alice" in names
      assert "Bob" in names
    end

    test "returns only header row when no players match filters", %{conn: conn} do
      create_player(%{name: "Alice", ntrp_rating: "3.5"})

      conn = get(conn, ~p"/players/export.csv?ntrp=4.0")
      rows = parse_csv(conn.resp_body)

      assert rows == []
    end

    test "filters by NTRP and bracket", %{conn: conn} do
      create_player(%{name: "Alice", ntrp_rating: "3.5", eligible_55_plus: true})
      create_player(%{name: "Bob", ntrp_rating: "4.0", eligible_55_plus: true})
      create_player(%{name: "Carol", ntrp_rating: "3.5", eligible_55_plus: false})

      conn = get(conn, ~p"/players/export.csv?ntrp=3.5,4.0&bracket=55")
      rows = parse_csv(conn.resp_body)
      names = Enum.map(rows, & &1["name"])

      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "rows are sorted by name ascending", %{conn: conn} do
      create_player(%{name: "Zelda"})
      create_player(%{name: "Alice"})
      create_player(%{name: "Mike"})

      conn = get(conn, ~p"/players/export.csv")
      rows = parse_csv(conn.resp_body)
      names = Enum.map(rows, & &1["name"])

      assert names == Enum.sort(names)
    end
  end
end
