defmodule TennisTracker.Accounts do
  @moduledoc false

  use Ash.Domain, otp_app: :tennis_tracker, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource TennisTracker.Accounts.Token

    resource TennisTracker.Accounts.User do
      define(:update_profile, action: :update_profile)
    end
  end
end
