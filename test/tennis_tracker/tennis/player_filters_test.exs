defmodule TennisTracker.Tennis.PlayerFiltersTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{PlayerFilters, TagCategory, Tag}

  require Ash.Query

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

      players =
        PlayerFilters.fetch_players("", [], %{include: %{}, show_untagged: []},
          tenant: grp.id,
          actor: usr
        )

      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
    end

    test "filters by name (case-insensitive partial match)", %{group: grp, user: usr} do
      Factory.player(group: grp, name: "Alice Smith")
      Factory.player(group: grp, name: "Bob Jones")

      players =
        PlayerFilters.fetch_players("smith", [], %{include: %{}, show_untagged: []},
          tenant: grp.id,
          actor: usr
        )

      assert length(players) == 1
      assert hd(players).name == "Alice Smith"
    end

    test "filters by NTRP rating", %{group: grp, user: usr} do
      Factory.player(group: grp, name: "Alice", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Bob", ntrp_rating: Decimal.new("4.0"))
      Factory.player(group: grp, name: "Carol", ntrp_rating: Decimal.new("4.5"))

      players =
        PlayerFilters.fetch_players("", ["3.5", "4.0"], %{include: %{}, show_untagged: []},
          tenant: grp.id,
          actor: usr
        )

      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "filters by tag (single category)", %{group: grp, user: usr} do
      category =
        Ash.create!(TagCategory, %{name: "Age Group", group_id: grp.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      tag =
        Ash.create!(Tag, %{name: "40+", group_id: grp.id, tag_category_id: category.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      alice = Factory.player(group: grp, name: "Alice")
      _bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      tag_filter = %{include: %{category.id => [tag.id]}, show_untagged: []}

      players =
        PlayerFilters.fetch_players("", [], tag_filter, tenant: grp.id, actor: usr)

      names = Enum.map(players, & &1.name)
      assert names == ["Alice"]
    end

    test "tag filter uses OR within category (multiple tags)", %{group: grp, user: usr} do
      category =
        Ash.create!(TagCategory, %{name: "League", group_id: grp.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      men_tag =
        Ash.create!(Tag, %{name: "Men's", group_id: grp.id, tag_category_id: category.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      women_tag =
        Ash.create!(Tag, %{name: "Women's", group_id: grp.id, tag_category_id: category.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      alice = Factory.player(group: grp, name: "Alice")
      bob = Factory.player(group: grp, name: "Bob")
      _carol = Factory.player(group: grp, name: "Carol")

      Tennis.add_player_tag(alice.id, women_tag.id, tenant: grp.id, actor: usr)
      Tennis.add_player_tag(bob.id, men_tag.id, tenant: grp.id, actor: usr)

      tag_filter = %{include: %{category.id => [men_tag.id, women_tag.id]}, show_untagged: []}

      players = PlayerFilters.fetch_players("", [], tag_filter, tenant: grp.id, actor: usr)
      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "tag filter uses AND between categories", %{group: grp, user: usr} do
      age_cat =
        Ash.create!(TagCategory, %{name: "Age Group", group_id: grp.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      gender_cat =
        Ash.create!(TagCategory, %{name: "Gender", group_id: grp.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      age_tag =
        Ash.create!(Tag, %{name: "40+", group_id: grp.id, tag_category_id: age_cat.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      gender_tag =
        Ash.create!(Tag, %{name: "Women's", group_id: grp.id, tag_category_id: gender_cat.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      # Alice: both tags
      alice = Factory.player(group: grp, name: "Alice")
      # Bob: only age tag
      bob = Factory.player(group: grp, name: "Bob")
      # Carol: only gender tag
      carol = Factory.player(group: grp, name: "Carol")

      Tennis.add_player_tag(alice.id, age_tag.id, tenant: grp.id, actor: usr)
      Tennis.add_player_tag(alice.id, gender_tag.id, tenant: grp.id, actor: usr)
      Tennis.add_player_tag(bob.id, age_tag.id, tenant: grp.id, actor: usr)
      Tennis.add_player_tag(carol.id, gender_tag.id, tenant: grp.id, actor: usr)

      tag_filter = %{
        include: %{age_cat.id => [age_tag.id], gender_cat.id => [gender_tag.id]},
        show_untagged: []
      }

      players = PlayerFilters.fetch_players("", [], tag_filter, tenant: grp.id, actor: usr)
      names = Enum.map(players, & &1.name)

      assert names == ["Alice"]
    end

    test "show_untagged includes players with no tag in that category", %{group: grp, user: usr} do
      category =
        Ash.create!(TagCategory, %{name: "Age Group", group_id: grp.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      tag =
        Ash.create!(Tag, %{name: "40+", group_id: grp.id, tag_category_id: category.id},
          domain: Tennis,
          tenant: grp.id,
          authorize?: false
        )

      alice = Factory.player(group: grp, name: "Alice")
      _bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      # Both Alice (has tag) and Bob (no tag in category) should match
      tag_filter = %{include: %{category.id => [tag.id]}, show_untagged: [category.id]}

      players = PlayerFilters.fetch_players("", [], tag_filter, tenant: grp.id, actor: usr)
      names = Enum.map(players, & &1.name)

      assert "Alice" in names
      assert "Bob" in names
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

      players =
        PlayerFilters.fetch_players("", [], %{include: %{}, show_untagged: []},
          tenant: grp.id,
          actor: usr
        )

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
        PlayerFilters.fetch_players("", [], %{include: %{}, show_untagged: []},
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

      players =
        PlayerFilters.fetch_players("", ["none"], %{include: %{}, show_untagged: []},
          tenant: grp.id,
          actor: usr
        )

      names = Enum.map(players, & &1.name)

      assert names == ["Unrated"]
    end

    test "includes unrated players alongside rated when \"none\" is combined with rated values",
         %{group: grp, user: usr} do
      Factory.player(group: grp, name: "Rated35", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Rated40", ntrp_rating: Decimal.new("4.0"))
      Factory.player(group: grp, traits: [:unrated], name: "Unrated")

      players =
        PlayerFilters.fetch_players("", ["3.5", "none"], %{include: %{}, show_untagged: []},
          tenant: grp.id,
          actor: usr
        )

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

      players =
        PlayerFilters.fetch_players("", ["3.5"], %{include: %{}, show_untagged: []},
          tenant: grp.id,
          actor: usr
        )

      names = Enum.map(players, & &1.name)

      assert "Rated" in names
      refute "Unrated" in names
    end
  end
end
