defmodule TennisTracker.Tennis do
  use Ash.Domain

  resources do
    resource TennisTracker.Tennis.Player do
      define(:list_players, action: :read)
      define(:get_player, action: :read, get_by: [:id])
      define(:create_player, action: :create)
      define(:update_player, action: :update)
      define(:destroy_player, action: :destroy)
    end
  end
end
