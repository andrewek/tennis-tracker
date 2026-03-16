defmodule TennisTracker.Tennis.MatchTest do
  use TennisTracker.DataCase, async: true

  alias TennisTracker.Tennis

  setup do
    team = Factory.team()
    {:ok, team: team}
  end

  describe "create" do
    test "creates with valid data", %{team: team} do
      match = Factory.match(team: team, opponent: "Rival Team", home_or_away: :away)
      assert match.opponent == "Rival Team"
      assert match.home_or_away == :away
      assert match.team_id == team.id
      assert is_nil(match.location_id)
    end

    test "creates without location", %{team: team} do
      match = Factory.match(team: team)
      assert is_nil(match.location_id)
    end

    test "creates with location", %{team: team} do
      location = Factory.location()
      match = Factory.match(team: team, location: location)
      assert match.location_id == location.id
    end

    test "returns error for missing opponent", %{team: team} do
      result =
        Tennis.create_match(%{
          match_date: Date.utc_today(),
          match_time: ~T[10:00:00],
          home_or_away: :home,
          team_id: team.id
        })

      assert {:error, _} = result
    end

    test "returns error for missing team_id" do
      result =
        Tennis.create_match(%{
          match_date: Date.utc_today(),
          match_time: ~T[10:00:00],
          opponent: "Someone",
          home_or_away: :home
        })

      assert {:error, _} = result
    end
  end

  describe "list_upcoming_matches_for_team/1" do
    test "returns only future matches sorted ascending by date then time", %{team: team} do
      today = Date.utc_today()

      _past1 = Factory.match(team: team, match_date: Date.add(today, -7), match_time: ~T[10:00:00], opponent: "Past A")
      _past2 = Factory.match(team: team, match_date: Date.add(today, -1), match_time: ~T[09:00:00], opponent: "Past B")
      future1 = Factory.match(team: team, match_date: Date.add(today, 1), match_time: ~T[09:00:00], opponent: "Future A")
      future2 = Factory.match(team: team, match_date: Date.add(today, 7), match_time: ~T[10:00:00], opponent: "Future B")
      future3 = Factory.match(team: team, match_date: Date.add(today, 1), match_time: ~T[14:00:00], opponent: "Future C")

      results = Tennis.list_upcoming_matches_for_team!(team.id)
      ids = Enum.map(results, & &1.id)

      assert future1.id in ids
      assert future2.id in ids
      assert future3.id in ids
      refute Enum.any?(results, &(&1.opponent in ["Past A", "Past B"]))

      # sorted: future1 (day+1 09:00), future3 (day+1 14:00), future2 (day+7 10:00)
      assert ids == [future1.id, future3.id, future2.id]
    end
  end

  describe "list_past_matches_for_team/1" do
    test "returns only past matches sorted descending by date then time", %{team: team} do
      today = Date.utc_today()

      past1 = Factory.match(team: team, match_date: Date.add(today, -7), match_time: ~T[10:00:00], opponent: "Past A")
      past2 = Factory.match(team: team, match_date: Date.add(today, -1), match_time: ~T[09:00:00], opponent: "Past B")
      past3 = Factory.match(team: team, match_date: Date.add(today, -1), match_time: ~T[14:00:00], opponent: "Past C")
      _future = Factory.match(team: team, match_date: Date.add(today, 7), match_time: ~T[10:00:00], opponent: "Future")

      results = Tennis.list_past_matches_for_team!(team.id)
      ids = Enum.map(results, & &1.id)

      assert past1.id in ids
      assert past2.id in ids
      assert past3.id in ids
      refute Enum.any?(results, &(&1.opponent == "Future"))

      # sorted desc: past3 (day-1 14:00), past2 (day-1 09:00), past1 (day-7 10:00)
      assert ids == [past3.id, past2.id, past1.id]
    end
  end
end
