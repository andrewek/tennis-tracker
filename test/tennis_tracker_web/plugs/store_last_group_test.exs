defmodule TennisTrackerWeb.Plugs.StoreLastGroupTest do
  use TennisTrackerWeb.ConnCase, async: true

  alias TennisTrackerWeb.Plugs.StoreLastGroup

  defp call(conn), do: StoreLastGroup.call(conn, StoreLastGroup.init([]))

  describe "when group_slug is present in params" do
    test "stores the slug in the session", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Map.put(:params, %{"group_slug" => "my-org"})
        |> call()

      assert get_session(conn, "last_group_slug") == "my-org"
    end

    test "overwrites a previously stored slug", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{"last_group_slug" => "old-org"})
        |> Map.put(:params, %{"group_slug" => "new-org"})
        |> call()

      assert get_session(conn, "last_group_slug") == "new-org"
    end
  end

  describe "when group_slug is absent from params" do
    test "does not modify the session", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{"last_group_slug" => "existing-org"})
        |> Map.put(:params, %{})
        |> call()

      assert get_session(conn, "last_group_slug") == "existing-org"
    end

    test "leaves session empty when it was empty", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Map.put(:params, %{})
        |> call()

      assert get_session(conn, "last_group_slug") == nil
    end
  end
end
