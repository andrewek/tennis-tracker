defmodule TennisTrackerWeb.Players.IndexLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Tag, TagCategory}

  require Ash.Query

  setup :setup_group

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  defp create_category(grp, name) do
    Ash.create!(TagCategory, %{name: name, group_id: grp.id},
      domain: Tennis,
      tenant: grp.id,
      authorize?: false
    )
  end

  defp create_tag(grp, category, name) do
    Ash.create!(Tag, %{name: name, group_id: grp.id, tag_category_id: category.id},
      domain: Tennis,
      tenant: grp.id,
      authorize?: false
    )
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

  describe "tag filter" do
    test "toggling a tag shows only players with that tag", %{conn: conn, group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      alice = Factory.player(group: grp, name: "Alice")
      _bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players")

      html =
        render_click(view, "toggle_tag", %{
          "category_id" => category.id,
          "tag_id" => tag.id
        })

      assert html =~ "Alice"
      refute html =~ "Bob"
    end

    test "clear all filters resets tag filter", %{conn: conn, group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      alice = Factory.player(group: grp, name: "Alice")
      _bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players")

      render_click(view, "toggle_tag", %{"category_id" => category.id, "tag_id" => tag.id})
      html = render_click(view, "clear_filter", %{})

      assert html =~ "Alice"
      assert html =~ "Bob"
    end

    test "tag IDs are URL-encoded as tags[] params", %{conn: conn, group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      alice = Factory.player(group: grp, name: "Alice")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      # Load page with tag param in URL
      {:ok, _view, html} =
        live(conn, ~p"/g/#{grp.slug}/players?tags[]=#{tag.id}")

      assert html =~ "Alice"
    end

    test "show_untagged toggle includes players without that category tag", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      alice = Factory.player(group: grp, name: "Alice")
      _bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players")

      # First activate the facet
      render_click(view, "toggle_tag", %{"category_id" => category.id, "tag_id" => tag.id})

      # Then toggle show_untagged
      html = render_click(view, "toggle_show_untagged", %{"category_id" => category.id})

      assert html =~ "Alice"
      assert html =~ "Bob"
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

  # ---------------------------------------------------------------------------
  # Task 2.7 — Export link encodes filter params
  # ---------------------------------------------------------------------------

  describe "Export CSV link href" do
    test "export link with no active filters has no query params", %{conn: conn, group: grp} do
      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/players")

      expected_href = "/g/#{grp.slug}/players/export.csv"
      assert html =~ ~s(href="#{expected_href}")
    end

    test "export link encodes active tag filter params", %{conn: conn, group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      alice = Factory.player(group: grp, name: "Alice")
      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players")

      html = render_click(view, "toggle_tag", %{"category_id" => category.id, "tag_id" => tag.id})

      # tags[] is URL-encoded as tags%5B%5D
      assert html =~ "tags%5B%5D=#{tag.id}"
    end

    test "export link encodes combined name, NTRP, and tag filters", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      alice = Factory.player(group: grp, name: "Alice", ntrp_rating: Decimal.new("3.5"))
      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      # Load with all three filters active via URL
      {:ok, _view, html} =
        live(
          conn,
          ~p"/g/#{grp.slug}/players?name=Alice&ntrp=3.5&tags[]=#{tag.id}"
        )

      assert html =~ "name=Alice"
      assert html =~ "ntrp=3.5"
      assert html =~ "tags%5B%5D=#{tag.id}"
    end
  end
end
