defmodule TennisTrackerWeb.Players.IndexLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :setup_group

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  describe "\"No rating\" filter" do
    test "unrated players appear when no filter is active", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "Rated", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/players")

      assert html =~ "Rated"
      assert html =~ "Unrated"
    end

    test "checking \"No rating\" shows only unrated players", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "Rated", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players")

      html = render_click(view, "toggle_ntrp", %{"rating" => "none"})

      assert html =~ "Unrated"
      refute html =~ "Rated"
    end

    test "combining \"No rating\" with a rated value shows both", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "Rated35", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Rated40", ntrp_rating: Decimal.new("4.0"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players")

      render_click(view, "toggle_ntrp", %{"rating" => "3.5"})
      html = render_click(view, "toggle_ntrp", %{"rating" => "none"})

      assert html =~ "Rated35"
      assert html =~ "Unrated"
      refute html =~ "Rated40"
    end

    test "clear filters removes \"No rating\" selection", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "Rated", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players")

      render_click(view, "toggle_ntrp", %{"rating" => "none"})
      html = render_click(view, "clear_filter", %{})

      assert html =~ "Rated"
      assert html =~ "Unrated"
    end
  end

  describe "NTRP sort direction toggle" do
    test "default sort is descending (higher NTRP first)", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "LowRated", ntrp_rating: Decimal.new("2.5"))
      Factory.player(group: grp, name: "HighRated", ntrp_rating: Decimal.new("5.0"))

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/players")

      high_pos = :binary.match(html, "HighRated") |> elem(0)
      low_pos = :binary.match(html, "LowRated") |> elem(0)

      assert high_pos < low_pos
    end

    test "toggling sort switches to ascending (lower NTRP first)", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "LowRated", ntrp_rating: Decimal.new("2.5"))
      Factory.player(group: grp, name: "HighRated", ntrp_rating: Decimal.new("5.0"))

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players")

      html = render_click(view, "toggle_ntrp_sort", %{})

      low_pos = :binary.match(html, "LowRated") |> elem(0)
      high_pos = :binary.match(html, "HighRated") |> elem(0)

      assert low_pos < high_pos
    end

    test "toggling sort twice returns to descending", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "LowRated", ntrp_rating: Decimal.new("2.5"))
      Factory.player(group: grp, name: "HighRated", ntrp_rating: Decimal.new("5.0"))

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players")

      render_click(view, "toggle_ntrp_sort", %{})
      html = render_click(view, "toggle_ntrp_sort", %{})

      high_pos = :binary.match(html, "HighRated") |> elem(0)
      low_pos = :binary.match(html, "LowRated") |> elem(0)

      assert high_pos < low_pos
    end

    test "unrated players appear below all rated players in default descending sort", %{
      conn: conn,
      group: grp
    } do
      Factory.player(group: grp, name: "HighRated", ntrp_rating: Decimal.new("5.0"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/players")

      high_pos = :binary.match(html, "HighRated") |> elem(0)
      unrated_pos = :binary.match(html, "Unrated") |> elem(0)

      assert high_pos < unrated_pos
    end

    test "unrated players appear above all rated players when sort is ascending", %{
      conn: conn,
      group: grp
    } do
      Factory.player(group: grp, name: "LowRated", ntrp_rating: Decimal.new("2.5"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players")

      html = render_click(view, "toggle_ntrp_sort", %{})

      unrated_pos = :binary.match(html, "Unrated") |> elem(0)
      low_pos = :binary.match(html, "LowRated") |> elem(0)

      assert unrated_pos < low_pos
    end
  end
end
