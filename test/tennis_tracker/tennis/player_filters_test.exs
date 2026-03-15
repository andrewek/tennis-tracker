defmodule TennisTracker.Tennis.PlayerFiltersTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis.PlayerFilters

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

  describe "fetch_players/3" do
    test "returns all players when no filters" do
      Factory.player(name: "Alice", ntrp_rating: Decimal.new("3.5"))
      Factory.player(name: "Bob", ntrp_rating: Decimal.new("4.0"))

      players = PlayerFilters.fetch_players("", [], [])
      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
    end

    test "filters by name (case-insensitive partial match)" do
      Factory.player(name: "Alice Smith")
      Factory.player(name: "Bob Jones")

      players = PlayerFilters.fetch_players("smith", [], [])
      assert length(players) == 1
      assert hd(players).name == "Alice Smith"
    end

    test "filters by NTRP rating" do
      Factory.player(name: "Alice", ntrp_rating: Decimal.new("3.5"))
      Factory.player(name: "Bob", ntrp_rating: Decimal.new("4.0"))
      Factory.player(name: "Carol", ntrp_rating: Decimal.new("4.5"))

      players = PlayerFilters.fetch_players("", ["3.5", "4.0"], [])
      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "filters by age bracket (55+)" do
      Factory.player(name: "Alice", traits: [:eligible_55_plus])
      Factory.player(name: "Bob")

      players = PlayerFilters.fetch_players("", [], ["55"])
      assert length(players) == 1
      assert hd(players).name == "Alice"
    end

    test "filters by combined NTRP and bracket" do
      Factory.player(name: "Alice", ntrp_rating: Decimal.new("3.5"), eligible_55_plus: true)
      Factory.player(name: "Bob", ntrp_rating: Decimal.new("4.0"), eligible_55_plus: true)
      Factory.player(name: "Carol", ntrp_rating: Decimal.new("3.5"))

      players = PlayerFilters.fetch_players("", ["3.5", "4.0"], ["55"])
      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "returns players sorted by NTRP descending then name ascending, unrated last" do
      Factory.player(name: "Zelda", ntrp_rating: Decimal.new("3.5"))
      Factory.player(name: "Alice", ntrp_rating: Decimal.new("4.0"))
      Factory.player(name: "Mike", ntrp_rating: Decimal.new("4.0"))
      Factory.player(name: "Bob", ntrp_rating: Decimal.new("3.0"))
      Factory.player(traits: [:unrated], name: "Unrated")

      players = PlayerFilters.fetch_players("", [], [])
      names = Enum.map(players, & &1.name)

      assert names == ["Alice", "Mike", "Zelda", "Bob", "Unrated"]
    end

    test "returns players sorted by NTRP ascending then name ascending, unrated first" do
      Factory.player(name: "Zelda", ntrp_rating: Decimal.new("3.5"))
      Factory.player(name: "Alice", ntrp_rating: Decimal.new("4.0"))
      Factory.player(name: "Bob", ntrp_rating: Decimal.new("3.0"))
      Factory.player(traits: [:unrated], name: "Unrated")

      players = PlayerFilters.fetch_players("", [], [], :asc_nils_first)
      names = Enum.map(players, & &1.name)

      assert names == ["Unrated", "Bob", "Zelda", "Alice"]
    end

    test "filters to only unrated players when ntrp_filter is [\"none\"]" do
      Factory.player(name: "Rated", ntrp_rating: Decimal.new("3.5"))
      Factory.player(traits: [:unrated], name: "Unrated")

      players = PlayerFilters.fetch_players("", ["none"], [])
      names = Enum.map(players, & &1.name)

      assert names == ["Unrated"]
    end

    test "includes unrated players alongside rated when \"none\" is combined with rated values" do
      Factory.player(name: "Rated35", ntrp_rating: Decimal.new("3.5"))
      Factory.player(name: "Rated40", ntrp_rating: Decimal.new("4.0"))
      Factory.player(traits: [:unrated], name: "Unrated")

      players = PlayerFilters.fetch_players("", ["3.5", "none"], [])
      names = Enum.map(players, & &1.name)

      assert "Rated35" in names
      assert "Unrated" in names
      refute "Rated40" in names
    end

    test "excludes unrated players when only rated NTRP values are selected" do
      Factory.player(name: "Rated", ntrp_rating: Decimal.new("3.5"))
      Factory.player(traits: [:unrated], name: "Unrated")

      players = PlayerFilters.fetch_players("", ["3.5"], [])
      names = Enum.map(players, & &1.name)

      assert "Rated" in names
      refute "Unrated" in names
    end
  end
end
