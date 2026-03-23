defmodule TennisTracker.Tennis.TeamDisplayLabelTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  describe "display_label calculation" do
    test "includes season year, team type name, and team name", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp, name: "18+ 3.5")
      team = Factory.team(group: grp, team_type: tt, name: "River Hawks", season_year: 2026)

      {:ok, loaded} =
        Ash.load(team, [:display_label], domain: Tennis, tenant: grp.id, actor: usr)

      assert loaded.display_label == "2026 18+ 3.5 - River Hawks"
    end
  end

  describe "short_display_label calculation" do
    test "includes team type name and team name without year", %{group: grp, user: usr} do
      tt = Factory.team_type(group: grp, name: "40+ 4.0")
      team = Factory.team(group: grp, team_type: tt, name: "Eagle Court", season_year: 2026)

      {:ok, loaded} =
        Ash.load(team, [:short_display_label], domain: Tennis, tenant: grp.id, actor: usr)

      assert loaded.short_display_label == "40+ 4.0 - Eagle Court"
    end
  end
end
