defmodule TennisTracker.Tennis.PlayerFiltersTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis.PlayerFilters

  setup :setup_group

  describe "parse_list_param/1" do
    test "returns [] for nil" do
      assert PlayerFilters.parse_list_param(nil) == []
    end

    test "returns [] for empty string" do
      assert PlayerFilters.parse_list_param("") == []
    end

    test "splits comma-separated values" do
      assert PlayerFilters.parse_list_param("3.5,4.0") == ["3.5", "4.0"]
    end

    test "returns single value in list" do
      assert PlayerFilters.parse_list_param("3.5") == ["3.5"]
    end
  end

  describe "fetch_players/4" do
    test "returns all players when no filters", %{group: grp, user: usr} do
      Factory.player(group: grp, name: "Alice", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Bob", ntrp_rating: Decimal.new("4.0"))

      players = PlayerFilters.fetch_players("", [], [], tenant: grp.id, actor: usr)
      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
    end

    test "filters by name (case-insensitive partial match)", %{group: grp, user: usr} do
      Factory.player(group: grp, name: "Alice Smith")
      Factory.player(group: grp, name: "Bob Jones")

      players = PlayerFilters.fetch_players("smith", [], [], tenant: grp.id, actor: usr)
      assert length(players) == 1
      assert hd(players).name == "Alice Smith"
    end

    test "filters by NTRP rating", %{group: grp, user: usr} do
      Factory.player(group: grp, name: "Alice", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Bob", ntrp_rating: Decimal.new("4.0"))
      Factory.player(group: grp, name: "Carol", ntrp_rating: Decimal.new("4.5"))

      players = PlayerFilters.fetch_players("", ["3.5", "4.0"], [], tenant: grp.id, actor: usr)
      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "filters by age bracket (55+)", %{group: grp, user: usr} do
      Factory.player(group: grp, name: "Alice", traits: [:eligible_55_plus])
      Factory.player(group: grp, name: "Bob")

      players = PlayerFilters.fetch_players("", [], ["55"], tenant: grp.id, actor: usr)
      assert length(players) == 1
      assert hd(players).name == "Alice"
    end

    test "filters by combined NTRP and bracket", %{group: grp, user: usr} do
      Factory.player(
        group: grp,
        name: "Alice",
        ntrp_rating: Decimal.new("3.5"),
        eligible_55_plus: true
      )

      Factory.player(
        group: grp,
        name: "Bob",
        ntrp_rating: Decimal.new("4.0"),
        eligible_55_plus: true
      )

      Factory.player(group: grp, name: "Carol", ntrp_rating: Decimal.new("3.5"))

      players =
        PlayerFilters.fetch_players("", ["3.5", "4.0"], ["55"], tenant: grp.id, actor: usr)

      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "returns players sorted by NTRP descending then name ascending, unrated last", %{
      group: grp,
      user: usr
    } do
      Factory.player(group: grp, name: "Zelda", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Alice", ntrp_rating: Decimal.new("4.0"))
      Factory.player(group: grp, name: "Mike", ntrp_rating: Decimal.new("4.0"))
      Factory.player(group: grp, name: "Bob", ntrp_rating: Decimal.new("3.0"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      players = PlayerFilters.fetch_players("", [], [], tenant: grp.id, actor: usr)
      names = Enum.map(players, & &1.name)

      assert names == ["Alice", "Mike", "Zelda", "Bob", "Unrated"]
    end

    test "returns players sorted by NTRP ascending then name ascending, unrated first", %{
      group: grp,
      user: usr
    } do
      Factory.player(group: grp, name: "Zelda", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Alice", ntrp_rating: Decimal.new("4.0"))
      Factory.player(group: grp, name: "Bob", ntrp_rating: Decimal.new("3.0"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      players =
        PlayerFilters.fetch_players("", [], [],
          ntrp_sort: :asc_nils_first,
          tenant: grp.id,
          actor: usr
        )

      names = Enum.map(players, & &1.name)

      assert names == ["Unrated", "Bob", "Zelda", "Alice"]
    end

    test "filters to only unrated players when ntrp_filter is [\"none\"]", %{
      group: grp,
      user: usr
    } do
      Factory.player(group: grp, name: "Rated", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      players = PlayerFilters.fetch_players("", ["none"], [], tenant: grp.id, actor: usr)
      names = Enum.map(players, & &1.name)

      assert names == ["Unrated"]
    end

    test "includes unrated players alongside rated when \"none\" is combined with rated values",
         %{group: grp, user: usr} do
      Factory.player(group: grp, name: "Rated35", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Rated40", ntrp_rating: Decimal.new("4.0"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      players = PlayerFilters.fetch_players("", ["3.5", "none"], [], tenant: grp.id, actor: usr)
      names = Enum.map(players, & &1.name)

      assert "Rated35" in names
      assert "Unrated" in names
      refute "Rated40" in names
    end

    test "excludes unrated players when only rated NTRP values are selected", %{
      group: grp,
      user: usr
    } do
      Factory.player(group: grp, name: "Rated", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      players = PlayerFilters.fetch_players("", ["3.5"], [], tenant: grp.id, actor: usr)
      names = Enum.map(players, & &1.name)

      assert "Rated" in names
      refute "Unrated" in names
    end
  end
end
