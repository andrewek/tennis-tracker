defmodule TennisTracker.Tennis.LocationTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  describe "create" do
    test "creates with required fields", %{group: grp} do
      location =
        Factory.location(
          group: grp,
          name: "Woods Tennis Center",
          address: "4701 Happy Hollow Blvd, Omaha, NE 68132"
        )

      assert location.name == "Woods Tennis Center"
      assert location.address == "4701 Happy Hollow Blvd, Omaha, NE 68132"
      assert is_nil(location.google_maps_url)
    end

    test "creates with google_maps_url", %{group: grp} do
      location = Factory.location(group: grp, google_maps_url: "https://maps.google.com/?q=test")
      assert location.google_maps_url == "https://maps.google.com/?q=test"
    end
  end

  describe "update" do
    test "updates name and address", %{group: grp, user: usr} do
      location = Factory.location(group: grp, name: "Old Name", address: "Old Address")

      {:ok, updated} =
        Tennis.update_location(location, %{name: "New Name", address: "New Address"},
          tenant: grp.id,
          actor: usr
        )

      assert updated.name == "New Name"
      assert updated.address == "New Address"
    end
  end

  describe "list_locations/1" do
    test "returns locations sorted alphabetically by name", %{group: grp, user: usr} do
      n = System.unique_integer([:positive])
      Factory.location(group: grp, name: "Zeta Courts #{n}")
      Factory.location(group: grp, name: "Alpha Courts #{n}")
      Factory.location(group: grp, name: "Mira Courts #{n}")

      locations = Tennis.list_locations!(tenant: grp.id, actor: usr)
      names = locations |> Enum.map(& &1.name) |> Enum.filter(&String.contains?(&1, to_string(n)))
      assert names == Enum.sort(names)
    end

    test "excludes archived locations", %{group: grp, user: usr} do
      active = Factory.location(group: grp)
      archived = Factory.location(group: grp)
      Tennis.archive_location!(archived, tenant: grp.id, actor: usr)

      locations = Tennis.list_locations!(tenant: grp.id, actor: usr)
      ids = Enum.map(locations, & &1.id)
      assert active.id in ids
      refute archived.id in ids
    end
  end

  describe "archive and restore" do
    test "archive removes location from list_locations", %{group: grp, user: usr} do
      location = Factory.location(group: grp)
      Tennis.archive_location!(location, tenant: grp.id, actor: usr)

      locations = Tennis.list_locations!(tenant: grp.id, actor: usr)
      refute Enum.any?(locations, &(&1.id == location.id))
    end

    test "list_archived_locations returns archived locations sorted by name", %{
      group: grp,
      user: usr
    } do
      n = System.unique_integer([:positive])
      loc_a = Factory.location(group: grp, name: "Archived Zeta #{n}")
      loc_b = Factory.location(group: grp, name: "Archived Alpha #{n}")
      Tennis.archive_location!(loc_a, tenant: grp.id, actor: usr)
      Tennis.archive_location!(loc_b, tenant: grp.id, actor: usr)

      archived = Tennis.list_archived_locations!(tenant: grp.id, actor: usr)
      names = archived |> Enum.map(& &1.name) |> Enum.filter(&String.contains?(&1, to_string(n)))
      assert names == Enum.sort(names)
    end

    test "unarchive restores location to list_locations", %{group: grp, user: usr} do
      location = Factory.location(group: grp)
      Tennis.archive_location!(location, tenant: grp.id, actor: usr)
      archived = Tennis.get_archived_location!(location.id, tenant: grp.id, actor: usr)
      Tennis.unarchive_location!(archived, tenant: grp.id, actor: usr)

      locations = Tennis.list_locations!(tenant: grp.id, actor: usr)
      assert Enum.any?(locations, &(&1.id == location.id))
    end

    # CRITICAL VERIFICATION (task 7.3):
    # AshArchival filters all read actions. When a match references an archived location,
    # loading the relationship via the primary :read action will return nil.
    # This test documents the actual behavior so we can decide on a mitigation if needed.
    test "match referencing an archived location — relationship load behavior", %{
      group: grp,
      user: usr
    } do
      location = Factory.location(group: grp)
      match = Factory.match(group: grp, location: location)
      Tennis.archive_location!(location, tenant: grp.id, actor: usr)

      {:ok, loaded} =
        Ash.load(match, [:location],
          domain: Tennis,
          tenant: grp.id,
          actor: usr
        )

      # If this assertion fails, AshArchival IS filtering relationship loads.
      # Mitigation required: add a read action excluded from AshArchival's filter
      # and configure the belongs_to to use read_action: that action.
      assert loaded.location != nil,
             "AshArchival is filtering relationship loads — mitigation needed. " <>
               "See design.md 'AshArchival filters all reads' risk."
    end
  end
end
