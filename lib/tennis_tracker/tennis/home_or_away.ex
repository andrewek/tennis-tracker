defmodule TennisTracker.Tennis.HomeOrAway do
  @moduledoc false

  use Ash.Type.Enum, values: [:home, :away]
end
