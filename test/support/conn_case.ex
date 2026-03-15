defmodule TennisTrackerWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TennisTrackerWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint TennisTrackerWeb.Endpoint

      use TennisTrackerWeb, :verified_routes

      alias TennisTracker.Factory

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TennisTrackerWeb.ConnCase
    end
  end

  setup tags do
    TennisTracker.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Creates a user and logs them in, returning the authenticated connection.
  """
  def log_in_user(conn, attrs \\ %{}) do
    defaults = %{
      email: "test_#{System.unique_integer()}@example.com",
      password: "Password1!",
      password_confirmation: "Password1!"
    }

    {:ok, user} =
      Ash.create(
        TennisTracker.Accounts.User,
        Map.merge(defaults, attrs),
        action: :register_with_password,
        domain: TennisTracker.Accounts,
        authorize?: false
      )

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> AshAuthentication.Plug.Helpers.store_in_session(user)
  end
end
