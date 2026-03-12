defmodule TennisTracker.Accounts do
  use Ash.Domain,
    otp_app: :tennis_tracker

  resources do
    resource TennisTracker.Accounts.Token
    resource TennisTracker.Accounts.User
  end
end
