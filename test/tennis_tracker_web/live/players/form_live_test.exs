defmodule TennisTrackerWeb.Players.FormLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Tag, TagCategory, PlayerTag}

  require Ash.Query

  setup :setup_group_with_owner

  setup %{conn: conn, user: user} do
    {:ok, conn: log_in_user(conn, user)}
  end

  defp create_category(grp, name \\ "Age Group") do
    Ash.create!(TagCategory, %{name: name, group_id: grp.id},
      domain: Tennis,
      tenant: grp.id,
      authorize?: false
    )
  end

  defp create_tag(grp, category, name \\ "18+") do
    Ash.create!(Tag, %{name: name, group_id: grp.id, tag_category_id: category.id},
      domain: Tennis,
      tenant: grp.id,
      authorize?: false
    )
  end

  describe "player edit — tag assignment" do
    test "existing tags are pre-checked on edit form", %{conn: conn, group: grp, user: usr} do
      category = create_category(grp)
      tag = create_tag(grp, category)
      player = Factory.player(group: grp, name: "Alice")
      Tennis.add_player_tag(player.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/players/#{player.id}/edit")

      assert html =~ tag.name
      # The checkbox with tag.id value should be checked
      assert html =~ ~s(value="#{tag.id}" checked)
    end

    test "adding a tag on save creates a PlayerTag record", %{
      conn: conn,
      group: grp,
      user: _usr
    } do
      category = create_category(grp)
      tag = create_tag(grp, category)
      player = Factory.player(group: grp, name: "Bob")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players/#{player.id}/edit")

      view
      |> form("#player-form", %{"form" => %{"name" => "Bob"}, "tag_ids" => [tag.id]})
      |> render_submit()

      player_tags =
        PlayerTag
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(player_id == ^player.id)
        |> Ash.read!(domain: Tennis, tenant: grp.id, authorize?: false)

      assert length(player_tags) == 1
      assert hd(player_tags).tag_id == tag.id
    end

    test "removing a tag on save destroys the PlayerTag record", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      category = create_category(grp)
      tag = create_tag(grp, category)
      player = Factory.player(group: grp, name: "Carol")
      Tennis.add_player_tag(player.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/players/#{player.id}/edit")

      # Submit without tag_ids — use render_submit directly to avoid the form/3
      # helper auto-including currently checked checkboxes from the rendered HTML
      render_submit(view, "save", %{"form" => %{"name" => "Carol"}})

      player_tags =
        PlayerTag
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(player_id == ^player.id)
        |> Ash.read!(domain: Tennis, tenant: grp.id, authorize?: false)

      assert player_tags == []
    end
  end
end
