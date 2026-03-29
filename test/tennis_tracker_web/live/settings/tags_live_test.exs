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

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      assert html =~ "Skill Level"
    end

    test "owner can create a new category", %{conn: conn, group: grp} do
      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_submit(view, "create_category", %{"name" => "Pipeline"})

      html = render(view)
      assert html =~ "Pipeline"
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

      html = render(view)
      assert html =~ "New Name"
      refute html =~ "Old Name"
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
      html = render_click(view, "delete_category", %{"category_id" => category.id})

      refute html =~ "Gone"
    end

    test "cancelling category delete keeps it in the list", %{conn: conn, group: grp} do
      category = create_category(grp, "Kept")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "confirm_delete_category", %{"category_id" => category.id})
      html = render_click(view, "cancel_delete_category", %{})

      assert html =~ "Kept"
    end
  end

  describe "tag management" do
    test "existing tags are listed under their category", %{conn: conn, group: grp} do
      category = create_category(grp, "Age Group")
      create_tag(grp, category, "40+")

      {:ok, _view, html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      assert html =~ "Age Group"
      assert html =~ "40+"
    end

    test "owner can create a new tag", %{conn: conn, group: grp} do
      category = create_category(grp, "Age Group")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_submit(view, "create_tag", %{
        "category_id" => category.id,
        "tag_name" => "55+"
      })

      html = render(view)
      assert html =~ "55+"
    end

    test "owner can rename a tag", %{conn: conn, group: grp} do
      category = create_category(grp)
      tag = create_tag(grp, category, "Old Tag")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "edit_tag", %{"tag_id" => tag.id, "name" => tag.name})

      render_submit(view, "save_tag_name", %{"tag_id" => tag.id, "name" => "New Tag"})

      html = render(view)
      assert html =~ "New Tag"
      refute html =~ "Old Tag"
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

      html = render_click(view, "delete_tag", %{"tag_id" => tag.id})

      refute html =~ "Remove Me"
    end

    test "cancelling tag delete keeps it in the list", %{conn: conn, group: grp} do
      category = create_category(grp)
      tag = create_tag(grp, category, "Stays")

      {:ok, view, _html} = live(conn, ~p"/g/#{grp.slug}/settings/tags")

      render_click(view, "confirm_delete_tag", %{
        "tag_id" => tag.id,
        "tag_name" => tag.name
      })

      html = render_click(view, "cancel_delete_tag", %{})

      assert html =~ "Stays"
    end
  end
end
