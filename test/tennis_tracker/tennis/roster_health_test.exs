defmodule TennisTracker.Tennis.RosterHealthTest do
  use ExUnit.Case, async: true

  alias TennisTracker.Tennis.RosterHealth
  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp team_type_35 do
    %{
      id: "team-type-id",
      name: "18+ 3.5",
      ntrp_level: Decimal.new("3.5"),
      allowed_ntrp_levels: [Decimal.new("3.0"), Decimal.new("3.5")]
    }
  end

  defp team_35 do
    %{
      id: "team-id",
      name: "Team A",
      is_pseudo: false,
      team_type: team_type_35()
    }
  end

  defp season_rules(min, max, pct) do
    %{
      min_roster: min,
      max_roster: max,
      on_level_min_pct: Decimal.new(pct)
    }
  end

  defp player(name, rating) do
    %{id: "player-#{name}", name: name, ntrp_rating: rating && Decimal.new(rating)}
  end

  # ---------------------------------------------------------------------------
  # nil season_rules
  # ---------------------------------------------------------------------------

  describe "nil season_rules" do
    test "returns empty list for a valid team with no rules" do
      team = team_35()
      members = [player("Alice", "3.5"), player("Bob", "3.0")]
      assert RosterHealth.check(team, members, nil) == []
    end

    test "still returns NTRP violations when rules are nil" do
      team = team_35()
      members = [player("Alice", "4.5")]
      violations = RosterHealth.check(team, members, nil)
      assert length(violations) == 1
      assert hd(violations).type == :invalid_ntrp
    end

    test "still returns unrated caution when rules are nil" do
      team = team_35()
      members = [player("Alice", nil)]
      violations = RosterHealth.check(team, members, nil)
      assert length(violations) == 1
      assert hd(violations).type == :unrated_player
      assert hd(violations).level == :caution
    end
  end

  # ---------------------------------------------------------------------------
  # Per-player checks
  # ---------------------------------------------------------------------------

  describe "per-player NTRP check" do
    test "no violation for on-level player" do
      team = team_35()
      members = [player("Alice", "3.5")]
      assert RosterHealth.check(team, members, nil) == []
    end

    test "no violation for allowed below-level player" do
      team = team_35()
      members = [player("Alice", "3.0")]
      assert RosterHealth.check(team, members, nil) == []
    end

    test "warning for player above allowed level" do
      team = team_35()
      members = [player("Alice", "4.0")]
      violations = RosterHealth.check(team, members, nil)
      assert Enum.any?(violations, &(&1.type == :invalid_ntrp and &1.level == :warning))
    end

    test "warning for player below allowed level" do
      team = team_35()
      members = [player("Alice", "2.5")]
      violations = RosterHealth.check(team, members, nil)
      assert Enum.any?(violations, &(&1.type == :invalid_ntrp))
    end

    test "violation carries the player_id" do
      team = team_35()
      p = player("Alice", "4.5")
      [v] = RosterHealth.check(team, [p], nil)
      assert v.player_id == p.id
    end

    test "caution for unrated player" do
      team = team_35()
      members = [player("Alice", nil)]
      [v] = RosterHealth.check(team, members, nil)
      assert v.type == :unrated_player
      assert v.level == :caution
      assert v.player_id != nil
    end
  end

  # ---------------------------------------------------------------------------
  # Team-level size checks
  # ---------------------------------------------------------------------------

  describe "below minimum roster size" do
    test "warning when roster count is below min" do
      team = team_35()
      members = [player("Alice", "3.5"), player("Bob", "3.5")]
      rules = season_rules(4, 10, "0.60")
      violations = RosterHealth.check(team, members, rules)
      assert Enum.any?(violations, &(&1.type == :below_min_roster))
    end

    test "no violation when roster count equals min" do
      team = team_35()
      members = Enum.map(1..4, &player("P#{&1}", "3.5"))
      rules = season_rules(4, 10, "0.60")
      violations = RosterHealth.check(team, members, rules)
      refute Enum.any?(violations, &(&1.type == :below_min_roster))
    end

    test "no violation when roster count exceeds min" do
      team = team_35()
      members = Enum.map(1..6, &player("P#{&1}", "3.5"))
      rules = season_rules(4, 10, "0.60")
      violations = RosterHealth.check(team, members, rules)
      refute Enum.any?(violations, &(&1.type == :below_min_roster))
    end
  end

  describe "above maximum roster size" do
    test "warning when roster count exceeds max" do
      team = team_35()
      members = Enum.map(1..12, &player("P#{&1}", "3.5"))
      rules = season_rules(4, 10, "0.60")
      violations = RosterHealth.check(team, members, rules)
      assert Enum.any?(violations, &(&1.type == :above_max_roster))
    end

    test "no violation when roster count equals max" do
      team = team_35()
      members = Enum.map(1..10, &player("P#{&1}", "3.5"))
      rules = season_rules(4, 10, "0.60")
      violations = RosterHealth.check(team, members, rules)
      refute Enum.any?(violations, &(&1.type == :above_max_roster))
    end
  end

  # ---------------------------------------------------------------------------
  # On-level percentage checks
  # ---------------------------------------------------------------------------

  describe "on-level percentage check" do
    test "violation when on-level percentage is below minimum" do
      # 1 of 4 at 3.5 = 25%, minimum is 60%
      team = team_35()

      members = [
        player("A", "3.5"),
        player("B", "3.0"),
        player("C", "3.0"),
        player("D", "3.0")
      ]

      rules = season_rules(1, 20, "0.60")
      violations = RosterHealth.check(team, members, rules)
      assert Enum.any?(violations, &(&1.type == :below_on_level_pct))
    end

    test "no violation when on-level percentage meets minimum exactly" do
      # 3 of 5 at 3.5 = 60%
      team = team_35()

      members = [
        player("A", "3.5"),
        player("B", "3.5"),
        player("C", "3.5"),
        player("D", "3.0"),
        player("E", "3.0")
      ]

      rules = season_rules(1, 20, "0.60")
      violations = RosterHealth.check(team, members, rules)
      refute Enum.any?(violations, &(&1.type == :below_on_level_pct))
    end

    test "unrated players are not counted as on-level" do
      # 1 of 4 at 3.5 (nil doesn't count), 1 nil = 25% on-level
      team = team_35()

      members = [
        player("A", "3.5"),
        player("B", "3.0"),
        player("C", nil),
        player("D", "3.0")
      ]

      rules = season_rules(1, 20, "0.60")
      violations = RosterHealth.check(team, members, rules)
      assert Enum.any?(violations, &(&1.type == :below_on_level_pct))
    end

    test "no on-level check for empty roster" do
      team = team_35()
      rules = season_rules(0, 20, "0.60")
      violations = RosterHealth.check(team, [], rules)
      refute Enum.any?(violations, &(&1.type == :below_on_level_pct))
    end
  end

  # ---------------------------------------------------------------------------
  # team_violations vs player_violations
  # ---------------------------------------------------------------------------

  describe "violation scoping" do
    test "size violations have no player_id" do
      team = team_35()
      members = [player("A", "3.5")]
      rules = season_rules(4, 10, "0.60")
      violations = RosterHealth.check(team, members, rules)
      team_v = Enum.find(violations, &(&1.type == :below_min_roster))
      assert is_nil(team_v.player_id)
    end

    test "player violations have player_id" do
      team = team_35()
      p = player("Alice", "4.5")
      violations = RosterHealth.check(team, [p], nil)
      player_v = Enum.find(violations, &(&1.type == :invalid_ntrp))
      assert player_v.player_id == p.id
    end
  end
end
