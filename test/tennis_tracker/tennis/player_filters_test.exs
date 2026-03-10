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

    test "returns players sorted by name ascending" do
      create_player(%{name: "Zelda"})
      create_player(%{name: "Alice"})
      create_player(%{name: "Mike"})

      players = PlayerFilters.fetch_players("", [], [])
      names = Enum.map(players, & &1.name)

      assert names == Enum.sort(names)
    end
  end
end
