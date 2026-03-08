defmodule TennisTracker.Tennis do
  use Ash.Domain

  resources do
    resource(TennisTracker.Tennis.Player)
  end
end
