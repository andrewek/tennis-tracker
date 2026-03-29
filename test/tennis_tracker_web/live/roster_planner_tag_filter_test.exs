defmodule TennisTrackerWeb.RosterPlannerTagFilterTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Tag, TagCategory}

  require Ash.Query

  setup :setup_group_with_owner

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

  describe "initial state from season rules default tags" do
    test "unassigned pool is pre-filtered by season rules default tags on load", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      tt = Factory.team_type(group: grp)
      sr = Factory.season_rules(group: grp, team_type: tt)
      Tennis.sync_season_rules_default_tags(sr.id, [tag.id], tenant: grp.id, actor: usr)

      alice = Factory.player(group: grp, name: "Alice")
      _bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, _view, html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      assert html =~ "Alice"
      refute html =~ "Bob"
    end

    test "when no default tags set, all players appear in unassigned", %{
      conn: conn,
      group: grp
    } do
      tt = Factory.team_type(group: grp)
      alice = Factory.player(group: grp, name: "Alice")
      bob = Factory.player(group: grp, name: "Bob")

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      assert has_element?(view, "#col-unassigned #player-#{alice.id}")
      assert has_element?(view, "#col-unassigned #player-#{bob.id}")
    end
  end

  describe "toggle tag filter" do
    test "toggling a tag shows only players with that tag in unassigned", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      tt = Factory.team_type(group: grp)
      alice = Factory.player(group: grp, name: "Alice")
      bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      render_click(view, "toggle_planner_tag", %{
        "category_id" => category.id,
        "tag_id" => tag.id
      })

      assert has_element?(view, "#col-unassigned #player-#{alice.id}")
      refute has_element?(view, "#col-unassigned #player-#{bob.id}")
    end

    test "toggling the same tag twice deactivates the filter", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      tt = Factory.team_type(group: grp)
      alice = Factory.player(group: grp, name: "Alice")
      bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      render_click(view, "toggle_planner_tag", %{
        "category_id" => category.id,
        "tag_id" => tag.id
      })

      render_click(view, "toggle_planner_tag", %{
        "category_id" => category.id,
        "tag_id" => tag.id
      })

      assert has_element?(view, "#col-unassigned #player-#{alice.id}")
      assert has_element?(view, "#col-unassigned #player-#{bob.id}")
    end
  end

  describe "show_untagged toggle" do
    test "show_untagged includes players with no tag in that category", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      tt = Factory.team_type(group: grp)
      alice = Factory.player(group: grp, name: "Alice")
      bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      # Activate the tag facet first
      render_click(view, "toggle_planner_tag", %{
        "category_id" => category.id,
        "tag_id" => tag.id
      })

      # Then toggle show_untagged for that category
      render_click(view, "toggle_planner_show_untagged", %{"category_id" => category.id})

      assert has_element?(view, "#col-unassigned #player-#{alice.id}")
      assert has_element?(view, "#col-unassigned #player-#{bob.id}")
    end

    test "show_untagged persists when the tag facet is deactivated and reactivated", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      tt = Factory.team_type(group: grp)
      alice = Factory.player(group: grp, name: "Alice")
      _bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      {:ok, view, _html} =
        live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{Date.utc_today().year}")

      # Activate facet, then show_untagged
      render_click(view, "toggle_planner_tag", %{
        "category_id" => category.id,
        "tag_id" => tag.id
      })

      render_click(view, "toggle_planner_show_untagged", %{"category_id" => category.id})

      # Deactivate tag facet (removing the tag from include)
      render_click(view, "toggle_planner_tag", %{
        "category_id" => category.id,
        "tag_id" => tag.id
      })

      # Reactivate
      render_click(view, "toggle_planner_tag", %{
        "category_id" => category.id,
        "tag_id" => tag.id
      })

      # show_untagged is still active — Bob still appears
      assert has_element?(view, "#col-unassigned #player-#{alice.id}")
    end
  end

  describe "session isolation" do
    test "tag filter state is independent between two sessions on the same board", %{
      conn: conn,
      group: grp,
      user: usr
    } do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")
      tt = Factory.team_type(group: grp)
      alice = Factory.player(group: grp, name: "Alice")
      bob = Factory.player(group: grp, name: "Bob")

      Tennis.add_player_tag(alice.id, tag.id, tenant: grp.id, actor: usr)

      year = Date.utc_today().year
      {:ok, view1, _} = live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{year}")
      {:ok, view2, _} = live(conn, ~p"/g/#{grp.slug}/roster-planner/#{tt.id}/#{year}")

      # Enable filter on view1 only
      render_click(view1, "toggle_planner_tag", %{
        "category_id" => category.id,
        "tag_id" => tag.id
      })

      # view1 filters; view2 still shows all players
      assert has_element?(view1, "#col-unassigned #player-#{alice.id}")
      refute has_element?(view1, "#col-unassigned #player-#{bob.id}")

      assert has_element?(view2, "#col-unassigned #player-#{alice.id}")
      assert has_element?(view2, "#col-unassigned #player-#{bob.id}")
    end
  end
end
