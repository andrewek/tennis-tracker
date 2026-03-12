defmodule TennisTracker.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        TennisTracker.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:tennis_tracker, :token_signing_secret)
  end
end
