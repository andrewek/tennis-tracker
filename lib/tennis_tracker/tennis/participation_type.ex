defmodule TennisTracker.Tennis.ParticipationType do
  use Ash.Type.Enum, values: [:playing, :out, :neutral]
end
