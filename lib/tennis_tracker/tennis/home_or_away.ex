defmodule TennisTracker.Tennis.HomeOrAway do
  use Ash.Type.Enum, values: [:home, :away]
end
