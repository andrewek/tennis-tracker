defmodule TennisTracker.Tennis.MatchTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup :setup_group_with_owner

  setup %{group: grp} do
    team = Factory.team(group: grp)
    {:ok, team: team}
  end

  describe "create" do
    test "creates with valid data", %{group: grp, user: _usr, team: team} do
      match = Factory.match(group: grp, team: team, opponent: "Rival Team", home_or_away: :away)
      assert match.opponent == "Rival Team"
      assert match.home_or_away == :away
      assert match.team_id == team.id
      assert is_nil(match.location_id)
    end

    test "creates without location", %{group: grp, team: team} do
      match = Factory.match(group: grp, team: team)
      assert is_nil(match.location_id)
    end

    test "creates with location", %{group: grp, team: team} do
      location = Factory.location(group: grp)
      match = Factory.match(group: grp, team: team, location: location)
      assert match.location_id == location.id
    end

    test "returns error for missing opponent", %{group: grp, user: usr, team: team} do
      result =
        Tennis.create_match(
          %{
            match_start_datetime: DateTime.utc_now(),
            home_or_away: :home,
            team_id: team.id,
            group_id: grp.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end

    test "returns error for missing team_id", %{group: grp, user: usr} do
      result =
        Tennis.create_match(
          %{
            match_start_datetime: DateTime.utc_now(),
            opponent: "Someone",
            home_or_away: :home,
            group_id: grp.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert {:error, _} = result
    end
  end

  describe "list_upcoming_matches_for_team/1" do
    test "returns only future matches sorted ascending by datetime", %{
      group: grp,
      user: usr,
      team: team
    } do
      now = DateTime.utc_now()

      _past1 =
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime: DateTime.add(now, -7, :day) |> DateTime.truncate(:second),
          opponent: "Past A"
        )

      _past2 =
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime: DateTime.add(now, -1, :day) |> DateTime.truncate(:second),
          opponent: "Past B"
        )

      future1 =
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime: DateTime.add(now, 1, :day) |> DateTime.truncate(:second),
          opponent: "Future A"
        )

      future2 =
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime: DateTime.add(now, 7, :day) |> DateTime.truncate(:second),
          opponent: "Future B"
        )

      future3 =
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime:
            DateTime.add(now, 1, :day) |> DateTime.add(5, :hour) |> DateTime.truncate(:second),
          opponent: "Future C"
        )

      results = Tennis.list_upcoming_matches_for_team!(team.id, tenant: grp.id, actor: usr)
      ids = Enum.map(results, & &1.id)

      assert future1.id in ids
      assert future2.id in ids
      assert future3.id in ids
      refute Enum.any?(results, &(&1.opponent in ["Past A", "Past B"]))

      # sorted: future1 (now+1d), future3 (now+1d+5h), future2 (now+7d)
      assert ids == [future1.id, future3.id, future2.id]
    end
  end

  describe "update" do
    test "updates allowed fields", %{group: grp, user: usr, team: team} do
      match = Factory.match(group: grp, team: team, opponent: "Old Rival", home_or_away: :home)
      location = Factory.location(group: grp)

      {:ok, updated} =
        Tennis.update_match(
          match,
          %{
            opponent: "New Rival",
            home_or_away: :away,
            location_id: location.id
          },
          tenant: grp.id,
          actor: usr
        )

      assert updated.opponent == "New Rival"
      assert updated.home_or_away == :away
      assert updated.location_id == location.id
    end

    test "returns error for blank opponent", %{group: grp, user: usr, team: team} do
      match = Factory.match(group: grp, team: team)
      assert {:error, _} = Tennis.update_match(match, %{opponent: ""}, tenant: grp.id, actor: usr)
    end
  end

  describe "destroy" do
    test "deletes the match", %{group: grp, user: usr, team: team} do
      match = Factory.match(group: grp, team: team)
      assert :ok = Tennis.destroy_match(match, tenant: grp.id, actor: usr)

      assert {:error, _} =
               Ash.get(Tennis.Match, match.id, domain: Tennis, tenant: grp.id, actor: usr)
    end
  end

  describe "list_past_matches_for_team/1" do
    test "returns only past matches sorted descending by datetime", %{
      group: grp,
      user: usr,
      team: team
    } do
      now = DateTime.utc_now()

      past1 =
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime: DateTime.add(now, -7, :day) |> DateTime.truncate(:second),
          opponent: "Past A"
        )

      past2 =
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime: DateTime.add(now, -1, :day) |> DateTime.truncate(:second),
          opponent: "Past B"
        )

      past3 =
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime:
            DateTime.add(now, -1, :day) |> DateTime.add(5, :hour) |> DateTime.truncate(:second),
          opponent: "Past C"
        )

      _future =
        Factory.match(
          group: grp,
          team: team,
          match_start_datetime: DateTime.add(now, 7, :day) |> DateTime.truncate(:second),
          opponent: "Future"
        )

      results = Tennis.list_past_matches_for_team!(team.id, tenant: grp.id, actor: usr)
      ids = Enum.map(results, & &1.id)

      assert past1.id in ids
      assert past2.id in ids
      assert past3.id in ids
      refute Enum.any?(results, &(&1.opponent == "Future"))

      # sorted desc: past3 (now-1d+5h), past2 (now-1d), past1 (now-7d)
      assert ids == [past3.id, past2.id, past1.id]
    end
  end
end
