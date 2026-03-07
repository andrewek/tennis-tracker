defmodule TennisTracker.Repo do
  use Ecto.Repo,
    otp_app: :tennis_tracker,
    adapter: Ecto.Adapters.Postgres
end
