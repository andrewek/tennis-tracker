defmodule TennisTracker.Tennis.ParticipationType do
  @moduledoc false

  use Ash.Type.Enum, values: [:playing, :out, :neutral]
end
