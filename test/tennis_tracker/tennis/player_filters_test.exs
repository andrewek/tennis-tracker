defmodule TennisTracker.Tennis.PlayerFiltersTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.PlayerFilters

  defp create_player(attrs) do
    defaults = %{
      name: "Player",
      eligible_18_plus: true,
      eligible_40_plus: false,
      eligible_55_plus: false
    }

    Tennis.create_player!(Map.merge(defaults, attrs))
  end

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
      create_player(%{name: "Alice", ntrp_rating: "3.5"})
      create_player(%{name: "Bob", ntrp_rating: "4.0"})

      players = PlayerFilters.fetch_players("", [], [])
      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
    end

    test "filters by name (case-insensitive partial match)" do
      create_player(%{name: "Alice Smith"})
      create_player(%{name: "Bob Jones"})

      players = PlayerFilters.fetch_players("smith", [], [])
      assert length(players) == 1
      assert hd(players).name == "Alice Smith"
    end

    test "filters by NTRP rating" do
      create_player(%{name: "Alice", ntrp_rating: "3.5"})
      create_player(%{name: "Bob", ntrp_rating: "4.0"})
      create_player(%{name: "Carol", ntrp_rating: "4.5"})

      players = PlayerFilters.fetch_players("", ["3.5", "4.0"], [])
      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "filters by age bracket (55+)" do
      create_player(%{name: "Alice", eligible_55_plus: true})
      create_player(%{name: "Bob", eligible_55_plus: false})

      players = PlayerFilters.fetch_players("", [], ["55"])
      assert length(players) == 1
      assert hd(players).name == "Alice"
    end

    test "filters by combined NTRP and bracket" do
      create_player(%{name: "Alice", ntrp_rating: "3.5", eligible_55_plus: true})
      create_player(%{name: "Bob", ntrp_rating: "4.0", eligible_55_plus: true})
      create_player(%{name: "Carol", ntrp_rating: "3.5", eligible_55_plus: false})

      players = PlayerFilters.fetch_players("", ["3.5", "4.0"], ["55"])
      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "returns players sorted by NTRP descending then name ascending" do
      create_player(%{name: "Zelda", ntrp_rating: "3.5"})
      create_player(%{name: "Alice", ntrp_rating: "4.0"})
      create_player(%{name: "Mike", ntrp_rating: "4.0"})
      create_player(%{name: "Bob", ntrp_rating: "3.0"})

      players = PlayerFilters.fetch_players("", [], [])
      names = Enum.map(players, & &1.name)

      assert names == ["Alice", "Mike", "Zelda", "Bob"]
    end

    test "returns players sorted by NTRP ascending then name ascending when ntrp_sort is :asc" do
      create_player(%{name: "Zelda", ntrp_rating: "3.5"})
      create_player(%{name: "Alice", ntrp_rating: "4.0"})
      create_player(%{name: "Bob", ntrp_rating: "3.0"})

      players = PlayerFilters.fetch_players("", [], [], :asc)
      names = Enum.map(players, & &1.name)

      # Unrated (nil) sorts last with ascending; rated players: 3.0, 3.5, 4.0
      rated_names = Enum.filter(names, &(&1 in ["Bob", "Zelda", "Alice"]))
      assert rated_names == ["Bob", "Zelda", "Alice"]
    end

    test "filters to only unrated players when ntrp_filter is [\"none\"]" do
      create_player(%{name: "Rated", ntrp_rating: "3.5"})
      create_player(%{name: "Unrated"})

      players = PlayerFilters.fetch_players("", ["none"], [])
      names = Enum.map(players, & &1.name)

      assert names == ["Unrated"]
    end

    test "includes unrated players alongside rated when \"none\" is combined with rated values" do
      create_player(%{name: "Rated35", ntrp_rating: "3.5"})
      create_player(%{name: "Rated40", ntrp_rating: "4.0"})
      create_player(%{name: "Unrated"})

      players = PlayerFilters.fetch_players("", ["3.5", "none"], [])
      names = Enum.map(players, & &1.name)

      assert "Rated35" in names
      assert "Unrated" in names
      refute "Rated40" in names
    end

    test "excludes unrated players when only rated NTRP values are selected" do
      create_player(%{name: "Rated", ntrp_rating: "3.5"})
      create_player(%{name: "Unrated"})

      players = PlayerFilters.fetch_players("", ["3.5"], [])
      names = Enum.map(players, & &1.name)

      assert "Rated" in names
      refute "Unrated" in names
    end
  end
end
