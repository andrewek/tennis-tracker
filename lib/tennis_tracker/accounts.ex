defmodule TennisTracker.Accounts do
  use Ash.Domain, otp_app: :tennis_tracker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource TennisTracker.Accounts.Token
    resource TennisTracker.Accounts.User
  end
end
