defmodule TennisTrackerWeb.Settings.TagsLiveTest do
  use TennisTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Tag, TagCategory}

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

  defp create_tag(grp, category, name) do
    Ash.create!(Tag, %{name: name, group_id: grp.id, tag_category_id: category.id},
      domain: Tennis,
      tenant: grp.id,
      authorize?: false
    )
  end

  describe "category management" do
    test "existing categories are listed", %{conn: conn, group: grp} do
      create_category(grp, "Skill Level")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      assert has_element?(view, "h2", "Skill Level")
    end

    test "owner can create a new category", %{conn: conn, group: grp} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_submit(view, "create_category", %{"name" => "Pipeline"})

      assert has_element?(view, "h2", "Pipeline")
    end

    test "owner can rename a category", %{conn: conn, group: grp} do
      category = create_category(grp, "Old Name")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "edit_category", %{
        "category_id" => category.id,
        "name" => category.name
      })

      render_submit(view, "save_category_name", %{
        "category_id" => category.id,
        "name" => "New Name"
      })

      assert has_element?(view, "h2", "New Name")
      refute has_element?(view, "h2", "Old Name")
    end

    test "clicking Delete shows confirmation modal", %{conn: conn, group: grp} do
      category = create_category(grp, "To Delete")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "confirm_delete_category", %{"category_id" => category.id})

      assert has_element?(view, "h3", "Delete Tag Category")
    end

    test "confirming category delete removes it from the list", %{conn: conn, group: grp} do
      category = create_category(grp, "Gone")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "confirm_delete_category", %{"category_id" => category.id})
      render_click(view, "delete_category", %{"category_id" => category.id})

      refute has_element?(view, "h2", "Gone")
    end

    test "cancelling category delete keeps it in the list", %{conn: conn, group: grp} do
      category = create_category(grp, "Kept")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "confirm_delete_category", %{"category_id" => category.id})
      render_click(view, "cancel_delete_category", %{})

      assert has_element?(view, "h2", "Kept")
    end
  end

  describe "tag management" do
    test "existing tags are listed under their category", %{conn: conn, group: grp} do
      category = create_category(grp, "Age Group")
      create_tag(grp, category, "40+")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      assert has_element?(view, "h2", "Age Group")
      assert has_element?(view, "span", "40+")
    end

    test "owner can create a new tag", %{conn: conn, group: grp} do
      category = create_category(grp, "Age Group")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_submit(view, "create_tag", %{
        "category_id" => category.id,
        "tag_name" => "55+"
      })

      assert has_element?(view, "span", "55+")
    end

    test "owner can rename a tag", %{conn: conn, group: grp} do
      category = create_category(grp)
      tag = create_tag(grp, category, "Old Tag")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "edit_tag", %{"tag_id" => tag.id, "name" => tag.name})

      render_submit(view, "save_tag_name", %{"tag_id" => tag.id, "name" => "New Tag"})

      assert has_element?(view, "span", "New Tag")
      refute has_element?(view, "span", "Old Tag")
    end

    test "clicking tag delete shows confirmation modal", %{conn: conn, group: grp} do
      category = create_category(grp)
      tag = create_tag(grp, category, "Doomed Tag")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "confirm_delete_tag", %{
        "tag_id" => tag.id,
        "tag_name" => tag.name
      })

      assert has_element?(view, "h3", "Delete Tag")
    end

    test "confirming tag delete removes it from the list", %{conn: conn, group: grp} do
      category = create_category(grp)
      tag = create_tag(grp, category, "Remove Me")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "confirm_delete_tag", %{
        "tag_id" => tag.id,
        "tag_name" => tag.name
      })

      render_click(view, "delete_tag", %{"tag_id" => tag.id})

      refute has_element?(view, "span", "Remove Me")
    end

    test "cancelling tag delete keeps it in the list", %{conn: conn, group: grp} do
      category = create_category(grp)
      tag = create_tag(grp, category, "Stays")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "confirm_delete_tag", %{
        "tag_id" => tag.id,
        "tag_name" => tag.name
      })

      render_click(view, "cancel_delete_tag", %{})

      assert has_element?(view, "span", "Stays")
    end
  end
end
