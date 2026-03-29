defmodule TennisTracker.Tennis.LocationTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  describe "create" do
    test "creates with name only (address fields optional)", %{group: grp} do
      location =
        Factory.location(
          group: grp,
          name: "Woods Tennis Center",
          street_address: nil,
          city: nil,
          state: nil,
          postal_code: nil
        )

      assert location.name == "Woods Tennis Center"
      assert is_nil(location.street_address)
      assert is_nil(location.city)
      assert is_nil(location.state)
      assert is_nil(location.postal_code)
      assert is_nil(location.google_maps_url)
    end

    test "creates with all structured address fields", %{group: grp} do
      location =
        Factory.location(
          group: grp,
          name: "Woods Tennis Center",
          street_address: "4701 Happy Hollow Blvd",
          city: "Omaha",
          state: "NE",
          postal_code: "68132"
        )

      assert location.street_address == "4701 Happy Hollow Blvd"
      assert location.city == "Omaha"
      assert location.state == "NE"
      assert location.postal_code == "68132"
    end

    test "creates with google_maps_url", %{group: grp} do
      location = Factory.location(group: grp, google_maps_url: "https://maps.google.com/?q=test")
      assert location.google_maps_url == "https://maps.google.com/?q=test"
    end

    test "rejects duplicate name within the same group", %{group: grp, user: usr} do
      Factory.location(group: grp, name: "Duplicate Court")

      assert {:error, %Ash.Error.Invalid{}} =
               Tennis.create_location(%{name: "Duplicate Court", group_id: grp.id},
                 tenant: grp.id,
                 actor: usr
               )
    end
  end

  describe "update" do
    test "updates name and address fields", %{group: grp, user: usr} do
      location =
        Factory.location(
          group: grp,
          name: "Old Name",
          street_address: "1 Old St",
          city: "Oldtown",
          state: "OL",
          postal_code: "00001"
        )

      {:ok, updated} =
        Tennis.update_location(
          location,
          %{
            name: "New Name",
            street_address: "2 New St",
            city: "Newtown",
            state: "NW",
            postal_code: "99999"
          },
          tenant: grp.id,
          actor: usr
        )

      assert updated.name == "New Name"
      assert updated.street_address == "2 New St"
      assert updated.city == "Newtown"
      assert updated.state == "NW"
      assert updated.postal_code == "99999"
    end
  end

  describe "formatted_address/1" do
    test "returns formatted address when all fields present", %{group: grp, user: usr} do
      location =
        Factory.location(
          group: grp,
          street_address: "123 Main St",
          city: "Springfield",
          state: "IL",
          postal_code: "62701"
        )

      {:ok, loaded} =
        Ash.load(location, [:formatted_address],
          domain: Tennis,
          tenant: grp.id,
          actor: usr
        )

      assert loaded.formatted_address == "123 Main St, Springfield, IL 62701"
    end

    test "returns nil when all address fields are nil", %{group: grp, user: usr} do
      location =
        Factory.location(
          group: grp,
          street_address: nil,
          city: nil,
          state: nil,
          postal_code: nil
        )

      {:ok, loaded} =
        Ash.load(location, [:formatted_address],
          domain: Tennis,
          tenant: grp.id,
          actor: usr
        )

      assert is_nil(loaded.formatted_address)
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
