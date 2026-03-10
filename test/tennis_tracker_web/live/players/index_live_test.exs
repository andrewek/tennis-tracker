defmodule TennisTrackerWeb.Players.IndexLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

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

  describe "\"No rating\" filter" do
    test "unrated players appear when no filter is active", %{conn: conn} do
      create_player(%{name: "Rated", ntrp_rating: "3.5"})
      create_player(%{name: "Unrated"})

      {:ok, _view, html} = live(conn, ~p"/players")

      assert html =~ "Rated"
      assert html =~ "Unrated"
    end

    test "checking \"No rating\" shows only unrated players", %{conn: conn} do
      create_player(%{name: "Rated", ntrp_rating: "3.5"})
      create_player(%{name: "Unrated"})

      {:ok, view, _html} = live(conn, ~p"/players")

      html = render_click(view, "toggle_ntrp", %{"rating" => "none"})

      assert html =~ "Unrated"
      refute html =~ "Rated"
    end

    test "combining \"No rating\" with a rated value shows both", %{conn: conn} do
      create_player(%{name: "Rated35", ntrp_rating: "3.5"})
      create_player(%{name: "Rated40", ntrp_rating: "4.0"})
      create_player(%{name: "Unrated"})

      {:ok, view, _html} = live(conn, ~p"/players")

      render_click(view, "toggle_ntrp", %{"rating" => "3.5"})
      html = render_click(view, "toggle_ntrp", %{"rating" => "none"})

      assert html =~ "Rated35"
      assert html =~ "Unrated"
      refute html =~ "Rated40"
    end

    test "clear filters removes \"No rating\" selection", %{conn: conn} do
      create_player(%{name: "Rated", ntrp_rating: "3.5"})
      create_player(%{name: "Unrated"})

      {:ok, view, _html} = live(conn, ~p"/players")

      render_click(view, "toggle_ntrp", %{"rating" => "none"})
      html = render_click(view, "clear_filter", %{})

      assert html =~ "Rated"
      assert html =~ "Unrated"
    end
  end

  describe "NTRP sort direction toggle" do
    test "default sort is descending (higher NTRP first)", %{conn: conn} do
      create_player(%{name: "LowRated", ntrp_rating: "2.5"})
      create_player(%{name: "HighRated", ntrp_rating: "5.0"})

      {:ok, _view, html} = live(conn, ~p"/players")

      high_pos = :binary.match(html, "HighRated") |> elem(0)
      low_pos = :binary.match(html, "LowRated") |> elem(0)

      assert high_pos < low_pos
    end

    test "toggling sort switches to ascending (lower NTRP first)", %{conn: conn} do
      create_player(%{name: "LowRated", ntrp_rating: "2.5"})
      create_player(%{name: "HighRated", ntrp_rating: "5.0"})

      {:ok, view, _html} = live(conn, ~p"/players")

      html = render_click(view, "toggle_ntrp_sort", %{})

      low_pos = :binary.match(html, "LowRated") |> elem(0)
      high_pos = :binary.match(html, "HighRated") |> elem(0)

      assert low_pos < high_pos
    end

    test "toggling sort twice returns to descending", %{conn: conn} do
      create_player(%{name: "LowRated", ntrp_rating: "2.5"})
      create_player(%{name: "HighRated", ntrp_rating: "5.0"})

      {:ok, view, _html} = live(conn, ~p"/players")

      render_click(view, "toggle_ntrp_sort", %{})
      html = render_click(view, "toggle_ntrp_sort", %{})

      high_pos = :binary.match(html, "HighRated") |> elem(0)
      low_pos = :binary.match(html, "LowRated") |> elem(0)

      assert high_pos < low_pos
    end
  end
end
