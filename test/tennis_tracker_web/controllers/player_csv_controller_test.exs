defmodule TennisTrackerWeb.PlayerCSVControllerTest do
  use TennisTrackerWeb.ConnCase, async: true

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Tag, TagCategory}

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

  describe "GET /g/:group_slug/players/export.csv" do
    test "returns correct content-type and content-disposition headers", %{conn: conn, group: grp} do
      conn = get(conn, ~p"/g/#{grp.slug}/players/export.csv")

      assert get_resp_header(conn, "content-type") == ["text/csv; charset=utf-8"]

      assert get_resp_header(conn, "content-disposition") == [
               ~s(attachment; filename="players.csv")
             ]
    end

    test "returns header row with base columns when group has no tags", %{
      conn: conn,
      group: grp
    } do
      conn = get(conn, ~p"/g/#{grp.slug}/players/export.csv")

      [header_line | _] = String.split(conn.resp_body, "\n")

      assert header_line == "name,ntrp_rating,email,phone_number"
    end

    test "returns all players when no filters", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "Alice", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Bob", ntrp_rating: Decimal.new("4.0"))

      conn = get(conn, ~p"/g/#{grp.slug}/players/export.csv")
      rows = parse_csv(conn.resp_body)
      names = Enum.map(rows, & &1["name"])

      assert "Alice" in names
      assert "Bob" in names
    end

    test "returns only header row when no players match filters", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "Alice", ntrp_rating: Decimal.new("3.5"))

      conn = get(conn, ~p"/g/#{grp.slug}/players/export.csv?ntrp=4.0")
      rows = parse_csv(conn.resp_body)

      assert rows == []
    end

    test "filters by NTRP", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "Alice", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Bob", ntrp_rating: Decimal.new("4.0"))
      Factory.player(group: grp, name: "Carol", ntrp_rating: Decimal.new("4.5"))

      conn = get(conn, ~p"/g/#{grp.slug}/players/export.csv?ntrp=3.5,4.0")
      rows = parse_csv(conn.resp_body)
      names = Enum.map(rows, & &1["name"])

      assert "Alice" in names
      assert "Bob" in names
      refute "Carol" in names
    end

    test "rows are sorted by name ascending within same NTRP rating", %{conn: conn, group: grp} do
      Factory.player(group: grp, name: "Zelda", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Alice", ntrp_rating: Decimal.new("3.5"))
      Factory.player(group: grp, name: "Mike", ntrp_rating: Decimal.new("3.5"))

      conn = get(conn, ~p"/g/#{grp.slug}/players/export.csv")
      rows = parse_csv(conn.resp_body)
      names = Enum.map(rows, & &1["name"])

      assert names == Enum.sort(names)
    end

    test "export with tags produces correct tag columns in header", %{
      conn: conn,
      group: grp
    } do
      cat = create_category(grp, "Age Group")
      create_tag(grp, cat, "18+")
      create_tag(grp, cat, "40+")

      conn = get(conn, ~p"/g/#{grp.slug}/players/export.csv")
      [header_line | _] = String.split(conn.resp_body, "\n")

      assert header_line ==
               "name,ntrp_rating,email,phone_number,tag:Age Group:18+,tag:Age Group:40+"
    end

    test "player with a tag has \"true\" in the corresponding column", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      cat = create_category(grp, "Age Group")
      tag = create_tag(grp, cat, "40+")
      player = Factory.player(group: grp, name: "Alice")
      Tennis.add_player_tag(player.id, tag.id, tenant: grp.id, actor: usr)

      conn = get(conn, ~p"/g/#{grp.slug}/players/export.csv")
      rows = parse_csv(conn.resp_body)
      alice_row = Enum.find(rows, &(&1["name"] == "Alice"))

      assert alice_row["tag:Age Group:40+"] == "true"
    end

    test "player without a tag has empty string in the corresponding column", %{
      conn: conn,
      group: grp
    } do
      cat = create_category(grp, "Age Group")
      create_tag(grp, cat, "40+")
      _player = Factory.player(group: grp, name: "Alice")

      conn = get(conn, ~p"/g/#{grp.slug}/players/export.csv")
      rows = parse_csv(conn.resp_body)
      alice_row = Enum.find(rows, &(&1["name"] == "Alice"))

      assert alice_row["tag:Age Group:40+"] == ""
    end

    test "export with active tag filter returns only matching players", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      cat = create_category(grp, "Age Group")
      tag = create_tag(grp, cat, "40+")
      alice = Factory.player(group: grp, name: "Alice")
      _bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      conn = get(conn, ~p"/g/#{grp.slug}/players/export.csv?tags[]=#{tag.id}")
      rows = parse_csv(conn.resp_body)
      names = Enum.map(rows, & &1["name"])

      assert "Alice" in names
      refute "Bob" in names
    end
  end
end
