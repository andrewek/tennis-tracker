defmodule TennisTracker.Tennis.LocationTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group

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

    test "creates with google_maps_url", %{group: grp, user: _usr} do
      location = Factory.location(group: grp, google_maps_url: "https://maps.google.com/?q=test")
      assert location.google_maps_url == "https://maps.google.com/?q=test"
    end

    test "upserts on duplicate name (idempotent)", %{group: grp, user: usr} do
      n = System.unique_integer([:positive])
      name = "Idempotent Venue #{n}"

      Factory.location(group: grp, name: name, address: "First Address")
      Factory.location(group: grp, name: name, address: "Updated Address")

      locations = Tennis.list_locations!(tenant: grp.id, actor: usr)
      matching = Enum.filter(locations, &(&1.name == name))
      assert length(matching) == 1
      assert hd(matching).address == "Updated Address"
    end
  end

  describe "list_locations/0" do
    test "returns locations sorted alphabetically by name", %{group: grp, user: usr} do
      n = System.unique_integer([:positive])
      Factory.location(group: grp, name: "Zeta Courts #{n}")
      Factory.location(group: grp, name: "Alpha Courts #{n}")
      Factory.location(group: grp, name: "Mira Courts #{n}")

      locations = Tennis.list_locations!(tenant: grp.id, actor: usr)
      names = locations |> Enum.map(& &1.name) |> Enum.filter(&String.contains?(&1, to_string(n)))
      assert names == Enum.sort(names)
    end
  end
end
