defmodule TennisTrackerWeb.LineupFormatterTest do
  use ExUnit.Case, async: true

  alias TennisTrackerWeb.LineupFormatter

  defp make_match(opts \\ []) do
    location = Keyword.get(opts, :location, nil)

    %{
      match_start_datetime: ~U[2026-03-29 19:00:00Z],
      timezone: "America/Chicago",
      location: location
    }
  end

  defp make_slot(id, name, sort_order, include_in_clipboard \\ true) do
    %{id: id, name: name, sort_order: sort_order, include_in_clipboard: include_in_clipboard}
  end

  defp make_assignment(player_name, slot_id) do
    %{
      team_lineup_slot_id: slot_id,
      player: %{name: player_name}
    }
  end

  # ---------------------------------------------------------------------------
  # Header format
  # ---------------------------------------------------------------------------

  describe "header" do
    test "includes formatted date and time with venue" do
      match = make_match(location: %{name: "Genesis Westroads"})
      result = LineupFormatter.format(match, [], [])
      assert result =~ "Sun, Mar 29"
      assert result =~ "2:00 PM"
      assert result =~ "Genesis Westroads"
    end

    test "includes date and time without parentheses when no location" do
      match = make_match()
      result = LineupFormatter.format(match, [], [])
      assert result =~ "Sun, Mar 29"
      assert result =~ "2:00 PM"
      refute result =~ "("
    end

    test "header format is date · time (venue)" do
      match = make_match(location: %{name: "West Courts"})
      result = LineupFormatter.format(match, [], [])
      assert result =~ "Sun, Mar 29 · 2:00 PM (West Courts)"
    end
  end

  # ---------------------------------------------------------------------------
  # Empty / no slots
  # ---------------------------------------------------------------------------

  describe "no slots" do
    test "returns header only when no slots" do
      match = make_match(location: %{name: "Court A"})
      result = LineupFormatter.format(match, [], [])
      assert result == "Sun, Mar 29 · 2:00 PM (Court A)"
    end

    test "returns header only when all slots have include_in_clipboard = false" do
      match = make_match()
      slots = [make_slot("1", "Out", 0, false)]
      result = LineupFormatter.format(match, slots, [])
      assert result == "Sun, Mar 29 · 2:00 PM"
    end
  end

  # ---------------------------------------------------------------------------
  # Slot blocks
  # ---------------------------------------------------------------------------

  describe "slot blocks" do
    test "empty slot renders --- placeholder" do
      match = make_match()
      slots = [make_slot("1", "#1 Singles", 0)]
      result = LineupFormatter.format(match, slots, [])
      assert result =~ "#1 Singles:\n---"
    end

    test "filled slot renders players alphabetically" do
      match = make_match()
      slots = [make_slot("1", "#1 Doubles", 0)]

      assignments = [
        make_assignment("Novak Djokovic", "1"),
        make_assignment("Rafael Nadal", "1")
      ]

      result = LineupFormatter.format(match, slots, assignments)
      assert result =~ "#1 Doubles:\nNovak Djokovic\nRafael Nadal"
    end

    test "slots are separated by blank line" do
      match = make_match()
      slots = [make_slot("1", "S1", 0), make_slot("2", "D1", 1)]

      result = LineupFormatter.format(match, slots, [])

      assert result =~ "S1:\n---\n\nD1:\n---"
    end

    test "slots appear in sort_order" do
      match = make_match()
      slots = [make_slot("1", "D1", 1), make_slot("2", "S1", 0)]

      result = LineupFormatter.format(match, slots, [])

      s1_pos = :binary.match(result, "S1") |> elem(0)
      d1_pos = :binary.match(result, "D1") |> elem(0)
      assert s1_pos < d1_pos
    end

    test "non-clipboard slots are excluded" do
      match = make_match()

      slots = [
        make_slot("1", "#1 Singles", 0, true),
        make_slot("2", "Out", 1, false)
      ]

      result = LineupFormatter.format(match, slots, [])

      assert result =~ "#1 Singles"
      refute result =~ "Out"
    end

    test "full example matches design spec" do
      match = make_match(location: %{name: "Genesis Westroads"})

      slots = [
        make_slot("1", "#1 Doubles", 0),
        make_slot("2", "#1 Singles", 1)
      ]

      assignments = [
        make_assignment("Rafael Nadal", "1"),
        make_assignment("Novak Djokovic", "1")
      ]

      result = LineupFormatter.format(match, slots, assignments)

      expected = """
      Sun, Mar 29 · 2:00 PM (Genesis Westroads)

      #1 Doubles:
      Novak Djokovic
      Rafael Nadal

      #1 Singles:
      ---\
      """

      assert result == String.trim_trailing(expected)
    end
  end
end
