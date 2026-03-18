defmodule TennisTracker.Tennis.PlayerCsvImportTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis
  alias TennisTracker.Tennis.PlayerCsvImport

  setup :setup_group

  describe "import_csv/2" do
    test "imports a CSV with all columns", %{group: grp, user: usr} do
      csv = """
      name,email,phone_number,ntrp_rating,eligible_18_plus,eligible_40_plus,eligible_55_plus
      Alice,alice@example.com,555-1234,3.5,true,false,false
      Bob,bob@example.com,555-5678,4.0,true,true,false
      Carol,carol@example.com,,2.5,true,false,false
      """

      assert {:ok, 3} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
      assert length(Tennis.list_players!(tenant: grp.id, actor: usr)) == 3
    end

    test "imports a CSV with only required and some optional columns", %{group: grp, user: usr} do
      csv = """
      name,ntrp_rating
      Alice,3.5
      Bob,4.0
      """

      assert {:ok, 2} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
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

    test "returns error with line number for invalid boolean value", %{group: grp, user: usr} do
      csv = """
      name,eligible_18_plus
      Alice,yes
      """

      assert {:error, :row_error, 2, message} =
               PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)

      assert message =~ "eligible_18_plus"
    end

    test "imports duplicate rows without error", %{group: grp, user: usr} do
      csv = """
      name,ntrp_rating
      Alice,3.5
      Alice,3.5
      """

      assert {:ok, 2} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
      assert length(Tennis.list_players!(tenant: grp.id, actor: usr)) == 2
    end

    test "applies schema defaults when optional boolean columns are absent", %{
      group: grp,
      user: usr
    } do
      csv = """
      name
      Alice
      """

      assert {:ok, 1} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
      [player] = Tennis.list_players!(tenant: grp.id, actor: usr)
      assert player.eligible_18_plus == true
      assert player.eligible_40_plus == false
      assert player.eligible_55_plus == false
    end

    test "applies schema defaults for blank boolean cells", %{group: grp, user: usr} do
      csv = """
      name,eligible_18_plus,eligible_40_plus,eligible_55_plus
      Alice,,,
      """

      assert {:ok, 1} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
      [player] = Tennis.list_players!(tenant: grp.id, actor: usr)
      assert player.eligible_18_plus == true
      assert player.eligible_40_plus == false
      assert player.eligible_55_plus == false
    end

    test "treats blank ntrp_rating as nil", %{group: grp, user: usr} do
      csv = """
      name,ntrp_rating
      Alice,
      """

      assert {:ok, 1} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
      [player] = Tennis.list_players!(tenant: grp.id, actor: usr)
      assert player.ntrp_rating == nil
    end

    test "returns ok with count 0 for a CSV with headers but no data rows", %{
      group: grp,
      user: usr
    } do
      csv = "name,email\n"
      assert {:ok, 0} = PlayerCsvImport.import_csv(csv, tenant: grp.id, actor: usr)
    end
  end
end
