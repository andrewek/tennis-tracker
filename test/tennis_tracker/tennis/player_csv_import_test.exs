defmodule TennisTracker.Tennis.PlayerCsvImportTest do
  use TennisTracker.DataCase, async: true

  require Ash.Query

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.{PlayerCsvImport, Tag, TagCategory}

  setup :setup_group

  # Helper to create tag category and tag bypassing auth for test setup
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

  describe "import_csv/2" do
    test "imports a CSV with all columns", %{group: grp, user: usr} do
      csv = """
      name,email,phone_number,ntrp_rating
      Alice,alice@example.com,555-1234,3.5
      Bob,bob@example.com,555-5678,4.0
      Carol,carol@example.com,,2.5
      """

      assert {:ok, %{players: 3}} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
      assert length(Tennis.list_players!(tenant: grp.id, actor: usr)) == 3
    end

    test "imports a CSV with only required and some optional columns", %{group: grp, user: usr} do
      csv = """
      name,ntrp_rating
      Alice,3.5
      Bob,4.0
      """

      assert {:ok, %{players: 2}} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
      assert length(Tennis.list_players!(tenant: grp.id, actor: usr)) == 2
    end

    test "returns error for unknown headers and imports nothing", %{group: grp, user: usr} do
      csv = """
      name,email,unknown_column
      Alice,alice@example.com,some_value
      """

      assert {:error, :invalid_headers, ["unknown_column"]} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert Tennis.list_players!(tenant: grp.id, actor: usr) == []
    end

    test "returns error when the required name header is absent", %{group: grp, user: usr} do
      csv = """
      email,ntrp_rating
      alice@example.com,3.5
      """

      assert {:error, :missing_required_headers, ["name"]} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert Tennis.list_players!(tenant: grp.id, actor: usr) == []
    end

    test "returns error with line number for blank name on first data row", %{
      group: grp,
      user: usr
    } do
      csv = """
      name,email
      ,alice@example.com
      """

      assert {:error, :row_error, 2, message} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert message =~ "name"
    end

    test "returns error with correct line number when blank name is not the first data row", %{
      group: grp,
      user: usr
    } do
      csv = """
      name,email
      Alice,alice@example.com
      ,bob@example.com
      Carol,carol@example.com
      """

      assert {:error, :row_error, 3, message} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert message =~ "name"
    end

    test "rolls back all inserts when a later row has a blank name", %{group: grp, user: usr} do
      csv = """
      name,ntrp_rating
      Alice,3.5
      Bob,3.0
      ,4.0
      """

      assert {:error, :row_error, 4, _message} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert Tennis.list_players!(tenant: grp.id, actor: usr) == []
    end

    test "returns error with line number for invalid ntrp_rating", %{group: grp, user: usr} do
      csv = """
      name,ntrp_rating
      Alice,not_a_rating
      """

      assert {:error, :row_error, 2, message} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert message =~ "ntrp_rating"
    end

    test "imports duplicate rows without error", %{group: grp, user: usr} do
      csv = """
      name,ntrp_rating
      Alice,3.5
      Alice,3.5
      """

      assert {:ok, %{players: 2}} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
      assert length(Tennis.list_players!(tenant: grp.id, actor: usr)) == 2
    end

    test "treats blank ntrp_rating as nil", %{group: grp, user: usr} do
      csv = """
      name,ntrp_rating
      Alice,
      """

      assert {:ok, %{players: 1}} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
      [player] = Tennis.list_players!(tenant: grp.id, actor: usr)
      assert player.ntrp_rating == nil
    end

    test "returns ok with count 0 for a CSV with headers but no data rows", %{
      group: grp,
      user: usr
    } do
      csv = "name,email\n"

      assert {:ok, %{players: 0, categories_created: 0, tags_created: 0}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 3.6 — Header validation for tag columns
  # ---------------------------------------------------------------------------

  describe "validate_headers/1 — tag column headers" do
    test "valid tag headers are accepted", %{group: grp, user: usr} do
      csv = "name,tag:Age Group:40+\nAlice,true\n"

      assert {:ok, %{players: 1}} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end

    test "tag header with missing tag name is rejected", %{group: grp, user: usr} do
      csv = "name,tag:Age Group:\nAlice,true\n"

      assert {:error, :invalid_headers, headers} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert "tag:Age Group:" in headers
    end

    test "tag header with missing category name is rejected", %{group: grp, user: usr} do
      csv = "name,tag::40+\nAlice,true\n"

      assert {:error, :invalid_headers, headers} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert "tag::40+" in headers
    end

    test "tag header with only one segment after 'tag:' is rejected", %{group: grp, user: usr} do
      csv = "name,tag:OnlyOneSegment\nAlice,true\n"

      assert {:error, :invalid_headers, headers} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert "tag:OnlyOneSegment" in headers
    end

    test "duplicate exact tag column header is rejected", %{group: grp, user: usr} do
      csv = "name,tag:Age Group:40+,tag:Age Group:40+\nAlice,true,true\n"

      assert {:error, :invalid_headers, _} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end

    test "case-insensitively equivalent tag headers are treated as duplicates", %{
      group: grp,
      user: usr
    } do
      csv = "name,tag:Age Group:40+,tag:age group:40+\nAlice,true,true\n"

      assert {:error, :invalid_headers, _} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end

    test "unknown non-tag headers are still rejected", %{group: grp, user: usr} do
      csv = "name,bad_column\nAlice,value\n"

      assert {:error, :invalid_headers, ["bad_column"]} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 4.5 — resolve_tag_columns via import_csv
  # ---------------------------------------------------------------------------

  describe "tag resolution (find-or-create)" do
    test "exact match reuses existing category and tag", %{group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      _tag = create_tag(grp, category, "40+")

      csv = "name,tag:Age Group:40+\nAlice,true\n"

      assert {:ok, %{players: 1, categories_created: 0, tags_created: 0}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end

    test "case-insensitive category match reuses existing category", %{group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      _tag = create_tag(grp, category, "40+")

      # lowercase "age group" should match existing "Age Group"
      csv = "name,tag:age group:40+\nAlice,true\n"

      assert {:ok, %{players: 1, categories_created: 0, tags_created: 0}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end

    test "case-insensitive tag match reuses existing tag", %{group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      _tag = create_tag(grp, category, "Senior")

      # lowercase "senior" should match existing "Senior"
      csv = "name,tag:Age Group:senior\nAlice,true\n"

      assert {:ok, %{players: 1, categories_created: 0, tags_created: 0}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end

    test "missing category and tag are auto-created", %{group: grp, user: usr} do
      csv = "name,tag:New Category:New Tag\nAlice,true\n"

      assert {:ok, %{players: 1, categories_created: 1, tags_created: 1}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      # Verify the category and tag were created
      categories = Tennis.list_tag_categories!(load: [:tags], tenant: grp.id, actor: usr)
      assert length(categories) == 1
      assert hd(categories).name == "New Category"
      assert length(hd(categories).tags) == 1
      assert hd(hd(categories).tags).name == "New Tag"
    end

    test "existing category with missing tag creates only the tag", %{group: grp, user: usr} do
      _category = create_category(grp, "Age Group")

      csv = "name,tag:Age Group:New Tag\nAlice,true\n"

      assert {:ok, %{players: 1, categories_created: 0, tags_created: 1}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end

    test "same-named tag under different category creates new category and tag", %{
      group: grp,
      user: usr
    } do
      existing_cat = create_category(grp, "NTRP")
      _existing_tag = create_tag(grp, existing_cat, "40+")

      # "Age Group:40+" - different category, tag with same name
      csv = "name,tag:Age Group:40+\nAlice,true\n"

      assert {:ok, %{players: 1, categories_created: 1, tags_created: 1}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end
  end

  # ---------------------------------------------------------------------------
  # Task 5.5 — Tag cell value parsing
  # ---------------------------------------------------------------------------

  describe "tag cell value coercion" do
    test "\"true\" cell assigns tag to the player", %{group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")

      csv = "name,tag:Age Group:40+\nAlice,true\n"

      assert {:ok, %{players: 1}} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      [player] = Tennis.list_players!(load: [:tags], tenant: grp.id, actor: usr)
      assert Enum.any?(player.tags, &(&1.id == tag.id))
    end

    test "empty cell skips tag assignment", %{group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      _tag = create_tag(grp, category, "40+")

      csv = "name,tag:Age Group:40+\nAlice,\n"

      assert {:ok, %{players: 1}} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      [player] = Tennis.list_players!(load: [:tags], tenant: grp.id, actor: usr)
      assert player.tags == []
    end

    test "\" true \" (trimmed) assigns tag", %{group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      tag = create_tag(grp, category, "40+")

      csv = "name,tag:Age Group:40+\nAlice, true \n"

      assert {:ok, %{players: 1}} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      [player] = Tennis.list_players!(load: [:tags], tenant: grp.id, actor: usr)
      assert Enum.any?(player.tags, &(&1.id == tag.id))
    end

    test "\"yes\" causes a row error", %{group: grp, user: usr} do
      category = create_category(grp, "Age Group")
      _tag = create_tag(grp, category, "40+")

      csv = "name,tag:Age Group:40+\nAlice,yes\n"

      assert {:error, :row_error, 2, message} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert message =~ "yes"
    end

    test "invalid tag value on row 5 prevents all players from being created", %{
      group: grp,
      user: usr
    } do
      category = create_category(grp, "Age Group")
      _tag = create_tag(grp, category, "40+")

      csv = """
      name,tag:Age Group:40+
      Alice,true
      Bob,
      Carol,true
      Dave,
      Eve,x
      """

      assert {:error, :row_error, 6, _} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert Tennis.list_players!(tenant: grp.id, actor: usr) == []
    end
  end

  # ---------------------------------------------------------------------------
  # Task 5.7 — Success result shape
  # ---------------------------------------------------------------------------

  describe "import_csv/2 success result shape" do
    test "no tag columns returns categories_created: 0, tags_created: 0", %{
      group: grp,
      user: usr
    } do
      csv = "name\nAlice\n"

      assert {:ok, %{players: 1, categories_created: 0, tags_created: 0}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end

    test "all tags reused returns categories_created: 0, tags_created: 0", %{
      group: grp,
      user: usr
    } do
      category = create_category(grp, "Age Group")
      _tag = create_tag(grp, category, "40+")

      csv = "name,tag:Age Group:40+\nAlice,true\n"

      assert {:ok, %{players: 1, categories_created: 0, tags_created: 0}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end

    test "new category and tag auto-created are counted independently", %{group: grp, user: usr} do
      csv = "name,tag:Cat A:Tag 1,tag:Cat B:Tag 2\nAlice,true,true\n"

      assert {:ok, %{players: 1, categories_created: 2, tags_created: 2}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end

    test "new tag under existing category increments only tags_created", %{group: grp, user: usr} do
      _category = create_category(grp, "Age Group")

      csv = "name,tag:Age Group:New Tag\nAlice,true\n"

      assert {:ok, %{players: 1, categories_created: 0, tags_created: 1}} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end
  end
end
