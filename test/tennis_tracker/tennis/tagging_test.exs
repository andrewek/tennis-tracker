defmodule TennisTracker.Tennis.TaggingTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{Tag, TagCategory, PlayerTag, SeasonRulesDefaultTag}

  require Ash.Query

  setup :setup_group_with_owner

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

  # ---------------------------------------------------------------------------
  # TagCategory tests
  # ---------------------------------------------------------------------------

  describe "TagCategory" do
    test "owner can create a tag category", %{group: grp, user: usr} do
      assert {:ok, _category} =
               Ash.create(TagCategory, %{name: "League Gender", group_id: grp.id},
                 domain: Tennis,
                 tenant: grp.id,
                 actor: usr
               )
    end

    test "rejects duplicate category name within same group", %{group: grp} do
      create_category(grp, "Skills")

      assert {:error, _} =
               Ash.create(TagCategory, %{name: "Skills", group_id: grp.id},
                 domain: Tennis,
                 tenant: grp.id,
                 authorize?: false
               )
    end

    test "allows same category name in different groups", %{group: grp} do
      grp2 = Factory.group()
      create_category(grp, "Skills")

      assert {:ok, _} =
               Ash.create(TagCategory, %{name: "Skills", group_id: grp2.id},
                 domain: Tennis,
                 tenant: grp2.id,
                 authorize?: false
               )
    end

    test "owner can rename a category", %{group: grp, user: usr} do
      category = create_category(grp)

      assert {:ok, updated} =
               Ash.update(category, %{name: "Renamed"},
                 domain: Tennis,
                 actor: usr,
                 tenant: grp.id
               )

      assert updated.name == "Renamed"
    end

    test "owner can delete a category", %{group: grp, user: usr} do
      category = create_category(grp)

      assert :ok = Ash.destroy(category, domain: Tennis, actor: usr, tenant: grp.id)
    end

    test "group member can read categories", %{group: grp} do
      member_user = Factory.user()
      Factory.group_membership(group: grp, user: member_user, role: :member)
      create_category(grp)

      categories =
        TagCategory
        |> Ash.Query.for_read(:read, %{}, actor: member_user)
        |> Ash.read!(domain: Tennis, tenant: grp.id)

      assert length(categories) == 1
    end

    test "member cannot create a category", %{group: grp} do
      member_user = Factory.user()
      Factory.group_membership(group: grp, user: member_user, role: :member)

      assert {:error, _} =
               Ash.create(TagCategory, %{name: "Test", group_id: grp.id},
                 domain: Tennis,
                 tenant: grp.id,
                 actor: member_user
               )
    end

    test "deleting a category cascades to its tags", %{group: grp, user: usr} do
      category = create_category(grp)
      tag = create_tag(grp, category, "Senior")

      :ok = Ash.destroy(category, domain: Tennis, actor: usr, tenant: grp.id)

      result =
        Tag
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(id == ^tag.id)
        |> Ash.read_one!(domain: Tennis, tenant: grp.id, authorize?: false)

      assert result == nil
    end
  end

  # ---------------------------------------------------------------------------
  # Tag tests
  # ---------------------------------------------------------------------------

  describe "Tag" do
    test "owner can create a tag", %{group: grp, user: usr} do
      category = create_category(grp)

      assert {:ok, _tag} =
               Ash.create(
                 Tag,
                 %{name: "40+", group_id: grp.id, tag_category_id: category.id},
                 domain: Tennis,
                 tenant: grp.id,
                 actor: usr
               )
    end

    test "rejects duplicate tag name (case-insensitive) within same category", %{group: grp} do
      category = create_category(grp)
      create_tag(grp, category, "Active")

      assert {:error, _} =
               Ash.create(Tag, %{name: "active", group_id: grp.id, tag_category_id: category.id},
                 domain: Tennis,
                 tenant: grp.id,
                 authorize?: false
               )
    end

    test "allows same tag name in different categories", %{group: grp} do
      cat1 = create_category(grp, "Category A")
      cat2 = create_category(grp, "Category B")
      create_tag(grp, cat1, "Active")

      assert {:ok, _} =
               Ash.create(Tag, %{name: "Active", group_id: grp.id, tag_category_id: cat2.id},
                 domain: Tennis,
                 tenant: grp.id,
                 authorize?: false
               )
    end

    test "owner can rename a tag", %{group: grp, user: usr} do
      category = create_category(grp)
      tag = create_tag(grp, category)

      assert {:ok, updated} =
               Ash.update(tag, %{name: "Renamed"}, domain: Tennis, actor: usr, tenant: grp.id)

      assert updated.name == "Renamed"
    end

    test "owner can delete a tag", %{group: grp, user: usr} do
      category = create_category(grp)
      tag = create_tag(grp, category)

      assert :ok = Ash.destroy(tag, domain: Tennis, actor: usr, tenant: grp.id)
    end
  end

  # ---------------------------------------------------------------------------
  # PlayerTag tests
  # ---------------------------------------------------------------------------

  describe "PlayerTag" do
    test "add_player_tag creates a PlayerTag record", %{group: grp, user: usr} do
      player = Factory.player(group: grp, name: "Alice")
      category = create_category(grp)
      tag = create_tag(grp, category)

      assert {:ok, _} = Tennis.add_player_tag(player.id, tag.id, tenant: grp.id, actor: usr)

      result =
        PlayerTag
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(player_id == ^player.id and tag_id == ^tag.id)
        |> Ash.read_one!(domain: Tennis, tenant: grp.id, authorize?: false)

      assert result != nil
    end

    test "remove_player_tag destroys the PlayerTag record", %{group: grp, user: usr} do
      player = Factory.player(group: grp, name: "Bob")
      category = create_category(grp)
      tag = create_tag(grp, category)

      Tennis.add_player_tag(player.id, tag.id, tenant: grp.id, actor: usr)
      assert :ok = Tennis.remove_player_tag(player.id, tag.id, tenant: grp.id, actor: usr)

      result =
        PlayerTag
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(player_id == ^player.id and tag_id == ^tag.id)
        |> Ash.read_one!(domain: Tennis, tenant: grp.id, authorize?: false)

      assert result == nil
    end

    test "deleting a tag cascades to PlayerTag records", %{group: grp, user: usr} do
      player = Factory.player(group: grp, name: "Carol")
      category = create_category(grp)
      tag = create_tag(grp, category)

      Tennis.add_player_tag(player.id, tag.id, tenant: grp.id, actor: usr)

      :ok = Ash.destroy(tag, domain: Tennis, actor: usr, tenant: grp.id)

      result =
        PlayerTag
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(player_id == ^player.id)
        |> Ash.read!(domain: Tennis, tenant: grp.id, authorize?: false)

      assert result == []
    end
  end

  # ---------------------------------------------------------------------------
  # SeasonRulesDefaultTag tests
  # ---------------------------------------------------------------------------

  describe "SeasonRulesDefaultTag" do
    test "sync_season_rules_default_tags sets default tags", %{group: grp, user: usr} do
      category = create_category(grp)
      tag = create_tag(grp, category)
      tt = Factory.team_type(group: grp)
      sr = Factory.season_rules(group: grp, team_type: tt)

      Tennis.sync_season_rules_default_tags(sr.id, [tag.id], tenant: grp.id, actor: usr)

      result =
        SeasonRulesDefaultTag
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(season_rules_id == ^sr.id)
        |> Ash.read!(domain: Tennis, tenant: grp.id, authorize?: false)

      assert length(result) == 1
      assert hd(result).tag_id == tag.id
    end

    test "sync_season_rules_default_tags replaces existing tags", %{group: grp, user: usr} do
      category = create_category(grp)
      tag1 = create_tag(grp, category, "Tag 1")
      tag2 = create_tag(grp, category, "Tag 2")
      tt = Factory.team_type(group: grp)
      sr = Factory.season_rules(group: grp, team_type: tt)

      Tennis.sync_season_rules_default_tags(sr.id, [tag1.id], tenant: grp.id, actor: usr)
      Tennis.sync_season_rules_default_tags(sr.id, [tag2.id], tenant: grp.id, actor: usr)

      result =
        SeasonRulesDefaultTag
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(season_rules_id == ^sr.id)
        |> Ash.read!(domain: Tennis, tenant: grp.id, authorize?: false)

      tag_ids = Enum.map(result, & &1.tag_id)
      assert tag_ids == [tag2.id]
    end

    test "deleting a tag cascades to SeasonRulesDefaultTag records", %{group: grp, user: usr} do
      category = create_category(grp)
      tag = create_tag(grp, category)
      tt = Factory.team_type(group: grp)
      sr = Factory.season_rules(group: grp, team_type: tt)

      Tennis.sync_season_rules_default_tags(sr.id, [tag.id], tenant: grp.id, actor: usr)

      :ok = Ash.destroy(tag, domain: Tennis, actor: usr, tenant: grp.id)

      result =
        SeasonRulesDefaultTag
        |> Ash.Query.for_read(:read, %{}, authorize?: false)
        |> Ash.Query.filter(season_rules_id == ^sr.id)
        |> Ash.read!(domain: Tennis, tenant: grp.id, authorize?: false)

      assert result == []
    end
  end

end
