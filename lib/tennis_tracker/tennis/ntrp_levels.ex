defmodule TennisTracker.Tennis.NtrpLevels do
  @moduledoc """
  Shared NTRP level constants for Player and TeamType validation.

  Player ratings cover the full USTA range (2.5–5.0).
  Team levels cover the competitive range used in this app (3.0–4.5).
  Team levels are a strict subset of player levels.
  """

  @team_levels [
    Decimal.new("3.0"),
    Decimal.new("3.5"),
    Decimal.new("4.0"),
    Decimal.new("4.5")
  ]

  @player_levels [
    Decimal.new("2.5"),
    Decimal.new("3.0"),
    Decimal.new("3.5"),
    Decimal.new("4.0"),
    Decimal.new("4.5"),
    Decimal.new("5.0")
  ]

  @doc "Valid NTRP levels for team types (3.0–4.5)."
  def team_levels, do: @team_levels

  @doc "Valid NTRP ratings for players (2.5–5.0). A superset of team_levels/0."
  def player_levels, do: @player_levels
end
