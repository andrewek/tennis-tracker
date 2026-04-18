defmodule TennisTracker.Tennis.RosterHealth do
  @moduledoc """
  Computes non-blocking health violations for a team's roster.

  Returns a list of violation structs. An empty list means no violations.
  When season_rules is nil, only per-player NTRP checks run (no size/pct rules).
  """

  defmodule Violation do
    @moduledoc false

    @enforce_keys [:type, :level, :message]
    defstruct [:type, :level, :message, :player_id]

    @type t :: %__MODULE__{
            type: atom(),
            level: :warning | :caution,
            message: String.t(),
            player_id: String.t() | nil
          }
  end

  @doc """
  Checks a team's roster for violations.

  - `team` — a %TennisTracker.Tennis.Team{} with its `team_type` loaded
  - `members` — list of %TennisTracker.Tennis.Player{} on this team
  - `season_rules` — %TennisTracker.Tennis.SeasonRules{} or nil

  Returns a list of `%Violation{}` structs.
  """
  def check(team, members, season_rules) do
    allowed_levels = team.team_type.allowed_ntrp_levels
    top_level = team.team_type.ntrp_level

    player_violations =
      members
      |> Enum.flat_map(&check_player(&1, allowed_levels))

    team_violations =
      if season_rules do
        check_team_rules(members, season_rules, top_level)
      else
        []
      end

    player_violations ++ team_violations
  end

  # Per-player checks
  defp check_player(player, allowed_levels) do
    cond do
      is_nil(player.ntrp_rating) ->
        [
          %Violation{
            type: :unrated_player,
            level: :caution,
            message: "#{player.name} has no NTRP rating — counted as off-level",
            player_id: player.id
          }
        ]

      player.ntrp_rating not in allowed_levels ->
        [
          %Violation{
            type: :invalid_ntrp,
            level: :warning,
            message:
              "#{player.name} (#{player.ntrp_rating}) is not an allowed rating for this team",
            player_id: player.id
          }
        ]

      true ->
        []
    end
  end

  # Team-level size and on-level percentage checks
  defp check_team_rules(members, season_rules, top_level) do
    count = length(members)
    violations = []

    violations =
      if count < season_rules.min_roster do
        [
          %Violation{
            type: :below_min_roster,
            level: :warning,
            message: "Roster has #{count} player(s) — minimum is #{season_rules.min_roster}"
          }
          | violations
        ]
      else
        violations
      end

    violations =
      if count > season_rules.max_roster do
        [
          %Violation{
            type: :above_max_roster,
            level: :warning,
            message: "Roster has #{count} player(s) — maximum is #{season_rules.max_roster}"
          }
          | violations
        ]
      else
        violations
      end

    violations =
      if count > 0 do
        on_level_count =
          Enum.count(members, fn p ->
            not is_nil(p.ntrp_rating) and Decimal.eq?(p.ntrp_rating, top_level)
          end)

        on_level_pct = Decimal.div(on_level_count, count)
        min_pct = season_rules.on_level_min_pct

        if Decimal.compare(on_level_pct, min_pct) == :lt do
          actual_pct =
            on_level_pct |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_string()

          required_pct = min_pct |> Decimal.mult(100) |> Decimal.round(0) |> Decimal.to_string()

          [
            %Violation{
              type: :below_on_level_pct,
              level: :warning,
              message:
                "Only #{actual_pct}% of roster is on-level (#{top_level}) — minimum is #{required_pct}%"
            }
            | violations
          ]
        else
          violations
        end
      else
        violations
      end

    violations
  end
end
